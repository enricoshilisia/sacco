"""
Charging, paying and waiving fines. Every step is a balanced journal entry
(CLAUDE.md rule 2), and the fine register is never edited to correct a
mistake - a fine is waived, which posts the reversing entry.

  Charge:  Dr 1400 Fines Receivable (member)   Cr 5200 Fine Income
  Payment: Dr 1000 Cash and Bank              Cr 1400 Fines Receivable (member)
  Waiver:  Dr 5200 Fine Income                Cr 1400 Fines Receivable (member)
"""

from datetime import date
from decimal import Decimal

from django.db import transaction
from django.db.models import F, Sum
from django.utils import timezone

from accounting.models import Account
from accounting.services import LineInput, post_journal_entry
from members.models import Member, MemberStatus

from .models import Fine, FinePayment, FineSettlement, FineStatus, OffenceType

CASH_ACCOUNT_CODE = "1000"
FINES_RECEIVABLE_CODE = "1400"
FINE_INCOME_CODE = "5200"
ZERO = Decimal("0")


def _account(code: str) -> Account:
    return Account.objects.get(code=code)


def outstanding_total(member: Member) -> Decimal:
    """What the member still owes - straight from the ledger."""
    return _account(FINES_RECEIVABLE_CODE).balance(member=member)


def member_summary(member: Member) -> dict:
    fines = Fine.objects.filter(member=member)
    charged = fines.exclude(status=FineStatus.WAIVED).aggregate(total=Sum("amount"))["total"] or ZERO
    paid = fines.aggregate(total=Sum("paid"))["total"] or ZERO
    return {
        "charged": charged,
        "paid": paid,
        "outstanding": outstanding_total(member),
        "count_outstanding": fines.filter(status=FineStatus.OUTSTANDING).count(),
    }


def charge_fine(
    *, member: Member, offence_type: OffenceType, incurred_on: date, amount: Decimal | None = None,
    meeting=None, notes: str = "", charged_by=None,
) -> Fine:
    """Records that a member owes a fine. The amount defaults to the
    offence's current amount; the fine keeps it even if the rule changes."""
    amount = amount if amount is not None else offence_type.amount
    if amount <= 0:
        raise ValueError("A fine must be more than 0.")
    if member.status == MemberStatus.EXITED:
        raise ValueError("That member has exited the SACCO.")
    if incurred_on > date.today():
        raise ValueError("A fine can't be dated in the future.")
    with transaction.atomic():
        entry = post_journal_entry(
            description=f"Fine: {offence_type.name} - {member.member_number}",
            entry_date=incurred_on,
            lines=[
                LineInput(account=_account(FINES_RECEIVABLE_CODE), debit=amount, member=member,
                          description=offence_type.name),
                LineInput(account=_account(FINE_INCOME_CODE), credit=amount, description="Fine income"),
            ],
            created_by=charged_by,
        )
        return Fine.objects.create(
            member=member, offence_type=offence_type, amount=amount, incurred_on=incurred_on, meeting=meeting,
            notes=notes[:255], journal_entry=entry, charged_by=charged_by,
        )


def record_payment(
    *, member: Member, amount: Decimal, method: str, paid_on: date, idempotency_key: str,
    reference: str = "", recorded_by=None,
) -> FinePayment:
    """Clears the member's oldest outstanding fines first. Paying more than
    is owed is refused rather than left sitting as a credit."""
    if amount <= 0:
        raise ValueError("Payment must be more than 0.")
    existing = FinePayment.objects.filter(idempotency_key=idempotency_key).first()
    if existing is not None:
        return existing  # a retry, not a second payment
    with transaction.atomic():
        member = Member.objects.select_for_update().get(pk=member.pk)
        fines = list(
            Fine.objects.select_for_update()
            .filter(member=member, status=FineStatus.OUTSTANDING, paid__lt=F("amount"))
            .order_by("incurred_on", "charged_at")
        )
        owed = sum((f.outstanding for f in fines), ZERO)
        if amount > owed:
            raise ValueError(f"That member only owes {owed} in fines.")
        entry = post_journal_entry(
            description=f"Fine payment - {member.member_number}",
            entry_date=paid_on,
            lines=[
                LineInput(account=_account(CASH_ACCOUNT_CODE), debit=amount,
                          description=f"Fine payment {reference}".strip()),
                LineInput(account=_account(FINES_RECEIVABLE_CODE), credit=amount, member=member,
                          description="Fines cleared"),
            ],
            created_by=recorded_by,
        )
        payment = FinePayment.objects.create(
            member=member, amount=amount, method=method, reference=reference, paid_on=paid_on,
            idempotency_key=idempotency_key, journal_entry=entry, recorded_by=recorded_by,
        )
        remaining = amount
        for fine in fines:
            if remaining <= 0:
                break
            portion = min(fine.outstanding, remaining)
            fine.paid += portion
            if fine.paid >= fine.amount:
                fine.status = FineStatus.PAID
            fine.save(update_fields=["paid", "status"])
            FineSettlement.objects.create(payment=payment, fine=fine, amount=portion)
            remaining -= portion
        return payment


def waive_fine(*, fine: Fine, by, reason: str) -> Fine:
    """Cancels what is still owed on a fine, with a reversing entry. Nobody
    waives a fine they charged themselves."""
    if not reason.strip():
        raise ValueError("Give a reason for waiving the fine.")
    with transaction.atomic():
        fine = Fine.objects.select_for_update().select_related("member", "offence_type").get(pk=fine.pk)
        if fine.status == FineStatus.WAIVED:
            raise ValueError("This fine was already waived.")
        if fine.charged_by_id is not None and fine.charged_by_id == getattr(by, "pk", None):
            raise ValueError("You charged this fine, so someone else must waive it.")
        remaining = fine.outstanding
        if remaining <= 0:
            raise ValueError("This fine is already fully paid.")
        entry = post_journal_entry(
            description=f"Fine waived: {fine.offence_type.name} - {fine.member.member_number}",
            entry_date=date.today(),
            lines=[
                LineInput(account=_account(FINE_INCOME_CODE), debit=remaining, description="Fine waived"),
                LineInput(account=_account(FINES_RECEIVABLE_CODE), credit=remaining, member=fine.member,
                          description=f"Waived: {reason.strip()[:80]}"),
            ],
            created_by=by,
        )
        fine.status = FineStatus.WAIVED
        fine.waived_by = by
        fine.waived_at = timezone.now()
        fine.waived_reason = reason.strip()[:255]
        fine.waiver_entry = entry
        fine.save(update_fields=["status", "waived_by", "waived_at", "waived_reason", "waiver_entry"])
        return fine


def charge_many(*, offence_type: OffenceType, entries: list[dict], incurred_on: date, meeting=None,
                notes: str = "", charged_by=None) -> list[Fine]:
    """One sitting of the disciplinary committee: several members, each with
    their own amount. All or nothing - if one line is wrong, nothing is
    charged, so the register never ends up half posted."""
    if not entries:
        raise ValueError("Choose at least one member.")
    with transaction.atomic():
        fines = []
        for entry in entries:
            member = entry["member"] if isinstance(entry["member"], Member) else Member.objects.get(pk=entry["member"])
            amount = entry.get("amount")
            fines.append(charge_fine(
                member=member, offence_type=offence_type,
                amount=Decimal(str(amount)) if amount not in (None, "") else None,
                incurred_on=incurred_on, meeting=meeting, notes=entry.get("notes") or notes, charged_by=charged_by,
            ))
        return fines


# --- From the meeting register ------------------------------------------------


def proposals_from_meeting(meeting) -> list[dict]:
    """Who the register says should be fined, and for what - the committee
    confirms before anything is charged."""
    from governance.models import AttendanceStatus

    by_mark = {
        o.from_attendance: o
        for o in OffenceType.objects.filter(is_active=True).exclude(from_attendance="")
    }
    already = set(Fine.objects.filter(meeting=meeting).values_list("member_id", "offence_type_id"))
    rows = []
    for record in meeting.attendance.select_related("member"):
        mark = {AttendanceStatus.ABSENT: "ABSENT", AttendanceStatus.LATE: "LATE"}.get(record.status)
        offence = by_mark.get(mark) if mark else None
        if offence is None:
            continue
        rows.append({
            "member": record.member,
            "offence_type": offence,
            "amount": offence.amount,
            "already_charged": (record.member_id, offence.pk) in already,
        })
    return rows


def charge_from_meeting(*, meeting, member_ids: list[str], charged_by=None) -> int:
    """Charges the proposed fines for the members the committee confirmed."""
    charged = 0
    for row in proposals_from_meeting(meeting):
        if row["already_charged"] or str(row["member"].pk) not in {str(m) for m in member_ids}:
            continue
        charge_fine(
            member=row["member"], offence_type=row["offence_type"],
            incurred_on=meeting.scheduled_at.date(), meeting=meeting,
            notes=f"From the register of {meeting.title}"[:255], charged_by=charged_by,
        )
        charged += 1
    return charged
