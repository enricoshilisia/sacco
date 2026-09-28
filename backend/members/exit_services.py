"""
Leaving the group, and discipline that stops short of it.

Resigning: a member gives notice (three months in Inuka West), the
committee approves, and the refund is paid only once the notice has run -
a percentage of their savings (90% here), less anything they still owe in
fines or welfare. What the group keeps is income to the group.

Suspension: a fixed number of days during which the member can look but
not take part - and it lifts itself when the time is up.
"""

from datetime import date, timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.db import transaction
from django.utils import timezone

from accounting.models import Account
from accounting.services import LineInput, post_journal_entry
from notifications.services import queue_sms

from .models import Member, MembershipSettings, MemberStatus, MemberStatusChange, Resignation, ResignationStatus

CASH = "1000"
SAVINGS_CAPITAL = "3000"
SAVINGS_DEPOSITS = "2000"
RETAINED_ON_EXIT = "5300"
FINES_RECEIVABLE = "1400"
WELFARE_DUES = "1300"
ZERO = Decimal("0")


def _account(code: str) -> Account:
    return Account.objects.get(code=code)


def _change_status(member: Member, new_status: str, *, reason: str, by=None) -> None:
    MemberStatusChange.objects.create(
        member=member, from_status=member.status, to_status=new_status, reason=reason, changed_by=by
    )
    member.status = new_status
    member.save(update_fields=["status"])


def _add_months(start: date, months: int) -> date:
    month = start.month - 1 + months
    year = start.year + month // 12
    month = month % 12 + 1
    day = min(start.day, [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28,
                          31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1])
    return date(year, month, day)


# --- What a member holds and owes ----------------------------------------------


def member_savings(member: Member, *, as_of: date | None = None) -> Decimal:
    """Everything the member has put in, wherever this SACCO holds it."""
    return (_account(SAVINGS_CAPITAL).balance(member=member, as_of=as_of)
            + _account(SAVINGS_DEPOSITS).balance(member=member, as_of=as_of))


def member_debts(member: Member) -> Decimal:
    return _account(FINES_RECEIVABLE).balance(member=member) + _account(WELFARE_DUES).balance(member=member)


def exit_quote(member: Member) -> dict:
    """What leaving would mean today, before anyone commits to it."""
    settings = MembershipSettings.get_solo()
    savings = member_savings(member)
    percent = settings.exit_refund_percent
    refundable = (savings * percent / Decimal("100")).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    debts = member_debts(member) if settings.exit_deducts_debts else ZERO
    return {
        "savings": savings,
        "refund_percent": percent,
        "refundable": refundable,
        "debts": debts,
        "payable": max(refundable - debts, ZERO),
        "retained": savings - refundable,
        "notice_months": settings.notice_months,
    }


# --- Resigning -------------------------------------------------------------------


def give_notice(*, member: Member, reason: str = "", on: date | None = None, by=None) -> Resignation:
    if member.status == MemberStatus.EXITED:
        raise ValueError("That member has already left.")
    if member.resignations.filter(status__in=[ResignationStatus.NOTICE, ResignationStatus.APPROVED]).exists():
        raise ValueError("This member has already given notice.")
    settings = MembershipSettings.get_solo()
    on = on or date.today()
    resignation = Resignation.objects.create(
        member=member, reason=reason.strip(), notice_given_on=on,
        leaving_on=_add_months(on, settings.notice_months), requested_by=by,
    )
    transaction.on_commit(lambda: queue_sms(
        member=member, event_type="resignation_notice", recipient=member.phone_number,
        message=(f"Your notice to leave has been received. Your last day is "
                 f"{resignation.leaving_on:%d %b %Y}, and any refund is paid after that."),
    ) if member.phone_number else None)
    return resignation


def decide_notice(*, resignation: Resignation, approve: bool, by, notes: str = "") -> Resignation:
    """The committee's decision on a notice. Nobody decides their own."""
    with transaction.atomic():
        resignation = Resignation.objects.select_for_update().select_related("member").get(pk=resignation.pk)
        if resignation.status != ResignationStatus.NOTICE:
            raise ValueError("This notice has already been decided.")
        if resignation.requested_by_id is not None and resignation.requested_by_id == getattr(by, "pk", None):
            raise ValueError("You gave this notice, so someone else must decide it.")
        resignation.status = ResignationStatus.APPROVED if approve else ResignationStatus.REJECTED
        resignation.decided_by = by
        resignation.decided_at = timezone.now()
        resignation.decision_notes = notes.strip()
        resignation.save(update_fields=["status", "decided_by", "decided_at", "decision_notes"])
        if approve:
            _change_status(resignation.member, MemberStatus.NOTICE,
                           reason=f"Serving notice until {resignation.leaving_on}", by=by)
        return resignation


def cancel_notice(*, resignation: Resignation, by, reason: str = "") -> Resignation:
    """A member who changes their mind before the notice runs out."""
    with transaction.atomic():
        resignation = Resignation.objects.select_for_update().select_related("member").get(pk=resignation.pk)
        if resignation.status not in (ResignationStatus.NOTICE, ResignationStatus.APPROVED):
            raise ValueError("Only a notice still running can be cancelled.")
        resignation.status = ResignationStatus.CANCELLED
        resignation.decision_notes = reason.strip()
        resignation.decided_by = by
        resignation.decided_at = timezone.now()
        resignation.save(update_fields=["status", "decision_notes", "decided_by", "decided_at"])
        if resignation.member.status == MemberStatus.NOTICE:
            _change_status(resignation.member, MemberStatus.ACTIVE, reason="Notice cancelled", by=by)
        return resignation


def pay_refund(*, resignation: Resignation, by, method: str = "CASH", reference: str = "",
               on: date | None = None) -> Resignation:
    """Pays the leaver out and closes their membership. Only after the
    notice period, and never twice."""
    on = on or date.today()
    with transaction.atomic():
        resignation = Resignation.objects.select_for_update().select_related("member").get(pk=resignation.pk)
        if resignation.status != ResignationStatus.APPROVED:
            raise ValueError("The notice must be approved first.")
        if on < resignation.leaving_on:
            raise ValueError(f"The notice runs until {resignation.leaving_on}. No refund before then.")
        if resignation.requested_by_id is not None and resignation.requested_by_id == getattr(by, "pk", None):
            raise ValueError("You gave this notice, so someone else must pay it out.")
        member = Member.objects.select_for_update().get(pk=resignation.member_id)
        quote = exit_quote(member)
        if quote["savings"] <= 0 and quote["debts"] <= 0:
            raise ValueError("This member has nothing to settle.")

        lines = [LineInput(account=_account(SAVINGS_CAPITAL), debit=quote["savings"], member=member,
                           description="Savings returned on exit")] if quote["savings"] else []
        if quote["retained"] > 0:
            lines.append(LineInput(account=_account(RETAINED_ON_EXIT), credit=quote["retained"],
                                   description=f"{100 - quote['refund_percent']}% retained on exit"))
        # Anything they owe is cleared out of what they would have been paid.
        if quote["debts"] > 0:
            fines = _account(FINES_RECEIVABLE).balance(member=member)
            welfare = _account(WELFARE_DUES).balance(member=member)
            if fines > 0:
                lines.append(LineInput(account=_account(FINES_RECEIVABLE), credit=fines, member=member,
                                       description="Fines settled from the refund"))
            if welfare > 0:
                lines.append(LineInput(account=_account(WELFARE_DUES), credit=welfare, member=member,
                                       description="Welfare dues settled from the refund"))
        if quote["payable"] > 0:
            lines.append(LineInput(account=_account(CASH), credit=quote["payable"],
                                   description=f"Refund to {member.full_name} {reference}".strip()))

        entry = post_journal_entry(
            description=f"Member exit - {member.member_number}", entry_date=on, lines=lines, created_by=by,
        )
        resignation.status = ResignationStatus.PAID
        resignation.savings_at_exit = quote["savings"]
        resignation.refund_percent = quote["refund_percent"]
        resignation.debts_deducted = quote["debts"]
        resignation.refund_paid = quote["payable"]
        resignation.retained_by_group = quote["retained"]
        resignation.paid_on = on
        resignation.paid_by = by
        resignation.journal_entry = entry
        resignation.save()
        _change_status(member, MemberStatus.EXITED, reason="Resigned and refunded", by=by)
        if member.user_id:
            from identity.models import TenantAccess

            TenantAccess.objects.filter(user=member.user).update(is_active=False)
        # Mark any fine still open as settled by the exit.
        from fines.models import Fine, FineStatus

        Fine.objects.filter(member=member, status=FineStatus.OUTSTANDING).update(status=FineStatus.PAID)
        return resignation


def due_for_refund(as_of: date | None = None):
    """Approved notices whose time has run - the Treasurer's list."""
    return Resignation.objects.filter(
        status=ResignationStatus.APPROVED, leaving_on__lte=as_of or date.today()
    ).select_related("member")


# --- Suspension --------------------------------------------------------------------


def suspend(*, member: Member, days: int, reason: str, by=None) -> Member:
    """Out of the group's business for a fixed time (the constitution's
    90 days for defamation, for instance) - they can still see their own
    records and pay what they owe."""
    if days <= 0:
        raise ValueError("A suspension needs a number of days.")
    if not reason.strip():
        raise ValueError("Give the reason for the suspension.")
    if member.status == MemberStatus.EXITED:
        raise ValueError("That member has left the group.")
    member.suspended_until = date.today() + timedelta(days=days)
    member.suspension_reason = reason.strip()[:255]
    member.save(update_fields=["suspended_until", "suspension_reason"])
    _change_status(member, MemberStatus.SUSPENDED, reason=f"Suspended {days} days: {reason.strip()}"[:255], by=by)
    if member.phone_number:
        transaction.on_commit(lambda: queue_sms(
            member=member, event_type="member_suspended", recipient=member.phone_number,
            message=(f"You have been suspended until {member.suspended_until:%d %b %Y}: "
                     f"{member.suspension_reason}"),
        ))
    return member


def lift_suspension(*, member: Member, by=None, reason: str = "Suspension served") -> Member:
    if member.status != MemberStatus.SUSPENDED:
        raise ValueError("That member isn't suspended.")
    member.suspended_until = None
    member.suspension_reason = ""
    member.save(update_fields=["suspended_until", "suspension_reason"])
    _change_status(member, MemberStatus.ACTIVE, reason=reason, by=by)
    return member


def lift_expired_suspensions(today: date | None = None) -> int:
    """Suspensions end by themselves; the monthly check tidies up."""
    today = today or date.today()
    expired = Member.objects.filter(status=MemberStatus.SUSPENDED, suspended_until__lt=today)
    count = 0
    for member in expired:
        lift_suspension(member=member, reason="Suspension served")
        count += 1
    return count
