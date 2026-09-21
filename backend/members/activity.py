"""
Member activity rules: members who stop contributing or stop coming to
meetings are archived (status DORMANT) - with a warning first and the
Secretary's confirmation.

Two rules, both set per SACCO in MemberActivitySettings:
  1. Contributions: N consecutive completed months with no deposit into a
     savings product of type "mandatory monthly" (at least the configured
     minimum, if any). Months before the member joined don't count.
  2. Meetings: N consecutive general meetings (register closed) marked
     "absent without apology". Present, late or an apology breaks the streak.

A monthly check (Celery beat, or "run check now") SMS-warns members one
step before a limit and lists members who reached it as InactivityFlags for
the Secretary to confirm or dismiss. A dormant member keeps their money and
can still log in and pay, but can't borrow or guarantee, and isn't levied
for - or covered by - welfare. They're reactivated automatically when they
contribute to mandatory savings again or attend a meeting (note_activity),
or manually by the Secretary.
"""

from datetime import date
from decimal import Decimal

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from .models import InactivityFlag, Member, MemberActivitySettings, MemberStatus, MemberStatusChange

ZERO = Decimal("0")


def _month_start(d: date) -> date:
    return d.replace(day=1)


def _previous_month(d: date) -> date:
    return (d.replace(day=1) - timezone.timedelta(days=1)).replace(day=1)


def contributed_months(member: Member, *, settings=None) -> set[tuple[int, int]]:
    """(year, month) pairs in which the member's mandatory monthly savings
    deposits reached the minimum monthly contribution."""
    from savings.models import SavingsProductType, SavingsTransaction, SavingsTransactionType

    settings = settings or MemberActivitySettings.get_solo()
    deposits = (
        SavingsTransaction.objects.filter(
            savings_account__member=member,
            savings_account__product__product_type=SavingsProductType.MANDATORY_MONTHLY,
            transaction_type=SavingsTransactionType.DEPOSIT,
        )
        .values("transaction_date__year", "transaction_date__month")
        .annotate(total=Sum("amount"))
    )
    return {
        (row["transaction_date__year"], row["transaction_date__month"])
        for row in deposits
        if row["total"] >= settings.min_monthly_contribution
    }


def missed_contribution_months(member: Member, *, today: date | None = None, settings=None) -> int:
    """Consecutive completed months, most recent first, with no qualifying
    mandatory-savings deposit. The current (incomplete) month never counts."""
    today = today or date.today()
    joined = _month_start(member.date_joined)
    paid = contributed_months(member, settings=settings)
    missed = 0
    month = _previous_month(today)
    # Cap the look-back: the streak only matters up to the archive limit.
    while month >= joined and missed < 120:
        if (month.year, month.month) in paid:
            break
        missed += 1
        month = _previous_month(month)
    return missed


def missed_meetings(member: Member) -> int:
    """Consecutive most-recent closed general meetings the member missed
    without apology. Meetings before they joined don't count."""
    from governance.models import AttendanceStatus, Meeting, MeetingStatus

    meetings = Meeting.objects.filter(
        status=MeetingStatus.HELD, counts_for_attendance=True, scheduled_at__date__gte=member.date_joined
    ).order_by("-scheduled_at")[:50]
    statuses = dict(member.meeting_attendance.filter(meeting__in=meetings).values_list("meeting_id", "status"))
    streak = 0
    for meeting in meetings:
        if statuses.get(meeting.id) != AttendanceStatus.ABSENT:
            break
        streak += 1
    return streak


def evaluate_member(member: Member, *, settings=None, today=None) -> dict:
    settings = settings or MemberActivitySettings.get_solo()
    result = {"months": 0, "meetings": 0, "reasons": [], "warn": []}
    if settings.contribution_rule_enabled:
        months = missed_contribution_months(member, today=today, settings=settings)
        result["months"] = months
        if months >= settings.inactive_after_months:
            result["reasons"].append(InactivityFlag.CONTRIBUTIONS)
        elif months >= settings.warn_after_months:
            result["warn"].append(InactivityFlag.CONTRIBUTIONS)
    if settings.meeting_rule_enabled:
        meetings = missed_meetings(member)
        result["meetings"] = meetings
        if meetings >= settings.inactive_after_meetings:
            result["reasons"].append(InactivityFlag.MEETINGS)
        elif meetings >= settings.warn_after_meetings:
            result["warn"].append(InactivityFlag.MEETINGS)
    return result


def run_activity_check(*, today=None, send_warnings=True) -> dict:
    """The monthly check over every active member. Idempotent: an existing
    pending flag isn't duplicated, and a member is warned at most once per
    streak length (last_warning_key)."""
    from notifications.services import queue_sms

    settings = MemberActivitySettings.get_solo()
    flagged = warned = 0
    for member in Member.objects.filter(status=MemberStatus.ACTIVE).order_by("member_number"):
        r = evaluate_member(member, settings=settings, today=today)
        for reason in r["reasons"]:
            detail = (
                f"{r['months']} months in a row without a mandatory monthly contribution"
                if reason == InactivityFlag.CONTRIBUTIONS
                else f"{r['meetings']} meetings in a row missed without apology"
            )
            _, created = InactivityFlag.objects.get_or_create(
                member=member, reason=reason, status=InactivityFlag.PENDING, defaults={"detail": detail}
            )
            flagged += int(created)
        if send_warnings and r["warn"] and member.phone_number:
            key = f"m{r['months']}-g{r['meetings']}"
            if member.last_warning_key != key:
                parts = []
                if InactivityFlag.CONTRIBUTIONS in r["warn"]:
                    parts.append(f"no monthly contribution for {r['months']} months")
                if InactivityFlag.MEETINGS in r["warn"]:
                    parts.append(f"{r['meetings']} meetings missed without apology")
                message = (
                    "Inuka West: your membership is at risk of being made dormant (" + "; ".join(parts) +
                    "). Please contribute or attend the next meeting to stay active."
                )
                queue_sms(member=member, event_type="inactivity_warning", recipient=member.phone_number, message=message)
                member.last_warning_key = key
                member.save(update_fields=["last_warning_key"])
                warned += 1
    return {"flagged": flagged, "warned": warned}


def _change_status(member: Member, new_status: str, *, reason: str, by=None) -> None:
    MemberStatusChange.objects.create(
        member=member, from_status=member.status, to_status=new_status, reason=reason, changed_by=by
    )
    member.status = new_status
    member.last_warning_key = ""
    member.save(update_fields=["status", "last_warning_key"])


def confirm_flag(flag: InactivityFlag, *, confirmed_by, notes: str = "") -> InactivityFlag:
    with transaction.atomic():
        flag = InactivityFlag.objects.select_for_update(of=("self",)).select_related("member").get(pk=flag.pk)
        if flag.status != InactivityFlag.PENDING:
            raise ValueError("This flag has already been decided.")
        member = flag.member
        if member.user_id and confirmed_by is not None and member.user_id == confirmed_by.pk:
            raise ValueError("You can't archive yourself.")
        if member.status == MemberStatus.ACTIVE:
            _change_status(member, MemberStatus.DORMANT, reason=f"Inactive: {flag.detail}", by=confirmed_by)
        # Any other pending flag for the same member is settled by this decision.
        InactivityFlag.objects.filter(member=member, status=InactivityFlag.PENDING).update(
            status=InactivityFlag.CONFIRMED, decided_by=confirmed_by, decided_at=timezone.now(), notes=notes
        )
        flag.refresh_from_db()
    return flag


def dismiss_flag(flag: InactivityFlag, *, dismissed_by, notes: str) -> InactivityFlag:
    if flag.status != InactivityFlag.PENDING:
        raise ValueError("This flag has already been decided.")
    flag.status = InactivityFlag.DISMISSED
    flag.decided_by = dismissed_by
    flag.decided_at = timezone.now()
    flag.notes = notes
    flag.save(update_fields=["status", "decided_by", "decided_at", "notes"])
    return flag


def reactivate(member: Member, *, by=None, reason: str = "Reactivated by the Secretary") -> None:
    if member.status != MemberStatus.DORMANT:
        raise ValueError("Only a dormant member can be reactivated.")
    _change_status(member, MemberStatus.ACTIVE, reason=reason, by=by)


def note_activity(member: Member, *, reason: str, by=None) -> bool:
    """Called when a member contributes to mandatory savings or attends a
    meeting. A member archived for inactivity comes back automatically; any
    pending flag for them lapses. Members who exited are never touched."""
    member = Member.objects.get(pk=member.pk)
    InactivityFlag.objects.filter(member=member, status=InactivityFlag.PENDING).update(
        status=InactivityFlag.DISMISSED, decided_at=timezone.now(), notes=f"Became active again: {reason}"
    )
    if member.status == MemberStatus.DORMANT:
        _change_status(member, MemberStatus.ACTIVE, reason=f"Reactivated automatically: {reason}", by=by)
        return True
    return False
