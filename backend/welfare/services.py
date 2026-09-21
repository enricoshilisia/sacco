from datetime import date
from decimal import Decimal

from django.db import transaction
from django.db.models import F, Q, Sum
from django.utils import timezone

from accounting.models import Account, JournalLine
from accounting.services import LineInput, post_journal_entry
from members.models import Member, MemberStatus
from notifications.services import queue_sms

from .models import (
    WelfareCase,
    WelfareCaseStatus,
    WelfareContribution,
    WelfareDueSettlement,
    WelfarePayment,
    WelfarePayout,
    WelfareSettings,
    WelfareYearClose,
    WelfareYearSweep,
)

CASH_ACCOUNT_CODE = "1000"
WELFARE_DUES_RECEIVABLE_CODE = "1300"  # what each member owes (member-tagged)
WELFARE_PREPAID_CODE = "2400"  # each member's yearly welfare balance (member-tagged)
WELFARE_FUND_CODE = "2500"  # the pooled fund payouts come from

ZERO = Decimal("0")


def _account(code: str) -> Account:
    return Account.objects.get(code=code)


def _lock_member(member: Member) -> Member:
    """Every per-member welfare money operation (levy, payment, year-end
    sweep) runs under a lock on the member row, so two of them can never
    both read the same balance and both act on it."""
    return Member.objects.select_for_update().get(pk=member.pk)


def welfare_balance(member, *, as_of=None) -> Decimal:
    """The member's unused welfare contributions - straight from the ledger."""
    return _account(WELFARE_PREPAID_CODE).balance(member=member, as_of=as_of)


def welfare_owed(member) -> Decimal:
    """What the member still owes for past cases - straight from the ledger."""
    return _account(WELFARE_DUES_RECEIVABLE_CODE).balance(member=member)


def member_summary(member) -> dict:
    today = date.today()
    paid_this_year = WelfarePayment.objects.filter(member=member, transaction_date__year=today.year).aggregate(
        total=Sum("to_balance")
    )["total"] or ZERO
    return {
        "balance": welfare_balance(member),
        "owed": welfare_owed(member),
        "yearly_contribution": WelfareSettings.get_solo().yearly_contribution,
        "paid_this_year": paid_this_year,
        "year": today.year,
    }


# --- Cases -----------------------------------------------------------------


def check_cover(case_type, beneficiary, affected_family_member=None, *, on=None) -> str:
    """
    Enforces the constitution's cover rules: a case is either for the member
    themself (if the case type covers SELF) or for someone on their APPROVED
    family register whose relationship the case type covers - and, for
    children, within the case type's age limit. Returns a label for the
    affected person; raises ValueError when they aren't covered.
    """
    from members.models import FamilyMemberStatus

    covers = case_type.covers or []
    if affected_family_member is None:
        if "SELF" not in covers:
            raise ValueError(f"'{case_type.name}' is for a family member - choose who from the member's register.")
        return ""
    person = affected_family_member
    if person.member_id != beneficiary.pk:
        raise ValueError("That person isn't on this member's family register.")
    if person.status != FamilyMemberStatus.APPROVED:
        raise ValueError(f"{person.full_name} isn't approved on the family register yet, so isn't covered.")
    if person.relationship not in covers:
        raise ValueError(f"'{case_type.name}' doesn't cover a {person.get_relationship_display().lower()}.")
    if person.relationship == "CHILD" and case_type.child_max_age is not None:
        age = person.age_on(on or date.today())
        if age is None:
            raise ValueError(f"{person.full_name} has no date of birth on record, so the child age limit can't be checked.")
        if age > case_type.child_max_age:
            raise ValueError(f"{person.full_name} is {age}; '{case_type.name}' covers children up to {case_type.child_max_age}.")
    return f"{person.full_name} ({person.get_relationship_display().lower()})"


def create_case(
    *, case_type, beneficiary, affected_family_member=None, affected_person="", description="", created_by=None,
) -> WelfareCase:
    if not case_type.is_active:
        raise ValueError("This welfare case type is no longer active.")
    if beneficiary.status == MemberStatus.EXITED:
        raise ValueError("Welfare cases can't be opened for a member who has exited.")
    if beneficiary.status == MemberStatus.DORMANT:
        raise ValueError("This member is dormant, so welfare doesn't cover them until they're reactivated.")
    from members.admission import require_verified

    require_verified(beneficiary, "be covered by welfare")
    label = check_cover(case_type, beneficiary, affected_family_member)
    return WelfareCase.objects.create(
        case_type=case_type,
        beneficiary=beneficiary,
        affected_family_member=affected_family_member,
        affected_person=label or affected_person,
        description=description,
        contribution_per_member=case_type.contribution_per_member,
        beneficiary_contributes=case_type.beneficiary_contributes,
        created_by=created_by,
    )


def approve_case(case: WelfareCase, *, approved_by, notes: str = "") -> WelfareCase:
    """Maker-checker: the person who opened the case can't approve it -
    approval is what charges every member, so it takes two people."""
    with transaction.atomic():
        case = WelfareCase.objects.select_for_update().get(pk=case.pk)
        if case.status != WelfareCaseStatus.PENDING_APPROVAL:
            raise ValueError("Only a case pending approval can be approved.")
        if approved_by is not None and case.created_by_id == approved_by.pk:
            raise ValueError("The person who opened a case can't also approve it.")
        case.status = WelfareCaseStatus.APPROVED
        case.decided_by = approved_by
        case.decided_at = timezone.now()
        case.decision_notes = notes
        case.save(update_fields=["status", "decided_by", "decided_at", "decision_notes"])
    return case


def reject_case(case: WelfareCase, *, rejected_by, notes: str) -> WelfareCase:
    with transaction.atomic():
        case = WelfareCase.objects.select_for_update().get(pk=case.pk)
        if case.status != WelfareCaseStatus.PENDING_APPROVAL:
            raise ValueError("Only a case pending approval can be rejected.")
        case.status = WelfareCaseStatus.REJECTED
        case.decided_by = rejected_by
        case.decided_at = timezone.now()
        case.decision_notes = notes
        case.save(update_fields=["status", "decided_by", "decided_at", "decision_notes"])
    return case


def close_case(case: WelfareCase) -> WelfareCase:
    """Stops further payouts. Members' outstanding dues for the case stay
    owed and still go into the Welfare Fund when paid."""
    with transaction.atomic():
        case = WelfareCase.objects.select_for_update().get(pk=case.pk)
        if case.status != WelfareCaseStatus.APPROVED:
            raise ValueError("Only an approved case can be closed.")
        case.status = WelfareCaseStatus.CLOSED
        case.closed_at = timezone.now()
        case.save(update_fields=["status", "closed_at"])
    return case


def levy_members(case: WelfareCase) -> int:
    """
    Charges every active member their share of an approved case. Runs in
    Celery (welfare.tasks.levy_welfare_case_task - CLAUDE.md rule 7).
    Idempotent: a member already levied for this case is skipped (and the
    WelfareContribution unique constraint backs that up), so a retried or
    re-run task never charges anyone twice. Each member is its own
    transaction - one member's failure doesn't undo everyone else's levy.
    Returns how many members were levied by this call.
    """
    case = WelfareCase.objects.select_related("case_type", "beneficiary").get(pk=case.pk)  # never trust a stale status
    if case.status not in (WelfareCaseStatus.APPROVED, WelfareCaseStatus.CLOSED):
        raise ValueError("Only an approved case can be levied.")

    members = Member.objects.filter(status=MemberStatus.ACTIVE).exclude(
        welfare_contributions__case=case
    )
    if not case.beneficiary_contributes:
        members = members.exclude(pk=case.beneficiary_id)

    levied = 0
    for member in members.order_by("member_number"):
        if _levy_member(case, member):
            levied += 1

    if case.levied_at is None:
        case.levied_at = timezone.now()
        case.save(update_fields=["levied_at"])
    return levied


def _levy_member(case: WelfareCase, member: Member) -> bool:
    amount = case.contribution_per_member
    with transaction.atomic():
        member = _lock_member(member)
        if WelfareContribution.objects.filter(case=case, member=member).exists():
            return False

        balance = welfare_balance(member)
        from_balance = min(max(balance, ZERO), amount)
        owed = amount - from_balance

        lines = []
        if from_balance > 0:
            lines.append(LineInput(
                account=_account(WELFARE_PREPAID_CODE), debit=from_balance, member=member,
                description="Taken from yearly welfare balance",
            ))
        if owed > 0:
            lines.append(LineInput(
                account=_account(WELFARE_DUES_RECEIVABLE_CODE), debit=owed, member=member,
                description="Welfare contribution owed",
            ))
        lines.append(LineInput(
            account=_account(WELFARE_FUND_CODE), credit=amount, member=member,
            description=f"Welfare levy - {case.case_type.name}",
        ))
        entry = post_journal_entry(
            description=f"Welfare levy: {case.case_type.name} for {case.beneficiary.member_number} - {member.member_number}",
            entry_date=date.today(),
            lines=lines,
        )
        WelfareContribution.objects.create(
            case=case, member=member, amount=amount, from_balance=from_balance, owed=owed, journal_entry=entry
        )

        if owed > 0:
            message = (
                f"Welfare: {case.case_type.name} for {case.beneficiary.full_name}. "
                f"Your contribution is {amount}"
                + (f"; {from_balance} was taken from your welfare balance" if from_balance > 0 else "")
                + f". Please pay the remaining {owed}."
            )
        else:
            message = (
                f"Welfare: {case.case_type.name} for {case.beneficiary.full_name}. "
                f"{amount} was taken from your welfare balance."
            )
        transaction.on_commit(
            lambda: queue_sms(member=member, event_type="welfare_levy", recipient=member.phone_number, message=message)
        )
    return True


def case_collected(case: WelfareCase) -> Decimal:
    """What a case has actually collected: amounts taken from balances at
    levy time plus dues members have since paid."""
    totals = case.contributions.aggregate(from_balance=Sum("from_balance"), paid=Sum("paid"))
    return (totals["from_balance"] or ZERO) + (totals["paid"] or ZERO)


def case_paid_out(case: WelfareCase) -> Decimal:
    return case.payouts.aggregate(total=Sum("amount"))["total"] or ZERO


def record_payout(
    *, case: WelfareCase, amount: Decimal, method: str, paid_on: date,
    reference: str = "", paid_to: str = "", notes: str = "", recorded_by=None,
) -> WelfarePayout:
    """Records a benefit already handed over (cash/bank). Capped at what
    the case has collected and not yet paid out, so the fund can never pay
    a case more than its members contributed to it."""
    if amount <= 0:
        raise ValueError("Payout amount must be positive.")
    with transaction.atomic():
        case = WelfareCase.objects.select_for_update().get(pk=case.pk)
        if case.status != WelfareCaseStatus.APPROVED:
            raise ValueError("Payouts can only be recorded on an approved, open case.")
        available = case_collected(case) - case_paid_out(case)
        if amount > available:
            raise ValueError(f"Only {available} has been collected for this case and not yet paid out.")
        entry = post_journal_entry(
            description=f"Welfare payout: {case.case_type.name} - {case.beneficiary.member_number}",
            entry_date=paid_on,
            lines=[
                LineInput(account=_account(WELFARE_FUND_CODE), debit=amount, member=case.beneficiary,
                          description="Welfare benefit paid"),
                LineInput(account=_account(CASH_ACCOUNT_CODE), credit=amount,
                          description=f"Welfare payout {reference}".strip()),
            ],
            created_by=recorded_by,
        )
        return WelfarePayout.objects.create(
            case=case, amount=amount, method=method, reference=reference, paid_to=paid_to,
            paid_on=paid_on, notes=notes, journal_entry=entry, recorded_by=recorded_by,
        )


# --- Member payments ---------------------------------------------------------


def record_payment(
    *, member, amount: Decimal, method: str, transaction_date: date, reference: str = "", created_by=None,
) -> WelfarePayment:
    """
    A member paying into welfare - at the counter, or via a confirmed
    mobile-money collection (payments.services.handle_collection_callback).
    Clears their oldest outstanding dues first; only the remainder tops up
    their yearly welfare balance.
    """
    if amount <= 0:
        raise ValueError("Payment amount must be positive.")
    with transaction.atomic():
        member = _lock_member(member)
        outstanding = list(
            WelfareContribution.objects.select_for_update()
            .filter(member=member, owed__gt=F("paid"))
            .order_by("created_at")
        )

        remaining = amount
        allocations = []
        for contribution in outstanding:
            if remaining <= 0:
                break
            portion = min(contribution.outstanding, remaining)
            allocations.append((contribution, portion))
            remaining -= portion
        applied = amount - remaining

        lines = [LineInput(account=_account(CASH_ACCOUNT_CODE), debit=amount, member=member,
                           description=f"Welfare payment {reference}".strip())]
        if applied > 0:
            lines.append(LineInput(account=_account(WELFARE_DUES_RECEIVABLE_CODE), credit=applied, member=member,
                                   description="Welfare dues cleared"))
        if remaining > 0:
            lines.append(LineInput(account=_account(WELFARE_PREPAID_CODE), credit=remaining, member=member,
                                   description="Yearly welfare contribution"))
        entry = post_journal_entry(
            description=f"Welfare payment - {member.member_number}",
            entry_date=transaction_date,
            lines=lines,
            created_by=created_by,
        )
        payment = WelfarePayment.objects.create(
            member=member, amount=amount, applied_to_dues=applied, to_balance=remaining, method=method,
            reference=reference, transaction_date=transaction_date, journal_entry=entry, created_by=created_by,
        )
        for contribution, portion in allocations:
            WelfareDueSettlement.objects.create(payment=payment, contribution=contribution, amount=portion)
            contribution.paid += portion
            contribution.save(update_fields=["paid"])
    return payment


# --- Year end ----------------------------------------------------------------


def start_year_close(*, year: int, closed_by=None) -> WelfareYearClose:
    if year >= date.today().year:
        raise ValueError("A year can only be closed after it has ended.")
    if WelfareYearClose.objects.filter(year__gt=year).exists():
        raise ValueError("A later year is already closed; years must be closed in order.")
    year_close, _ = WelfareYearClose.objects.get_or_create(year=year, defaults={"closed_by": closed_by})
    if year_close.status == WelfareYearClose.DONE:
        raise ValueError(f"{year} has already been closed.")
    return year_close


def run_year_close(year_close: WelfareYearClose) -> int:
    """
    Moves each member's unused welfare money from that year into the
    Welfare Fund. Runs in Celery (welfare.tasks.close_welfare_year_task);
    idempotent per member (WelfareYearSweep unique constraint), so a retry
    picks up where it stopped. Returns how many members were swept.
    """
    prepaid = _account(WELFARE_PREPAID_CODE)
    member_ids = (
        JournalLine.objects.filter(account=prepaid, member__isnull=False)
        .values_list("member_id", flat=True)
        .distinct()
    )
    swept = 0
    for member in Member.objects.filter(pk__in=member_ids).order_by("member_number"):
        if _sweep_member(year_close, member):
            swept += 1
    year_close.status = WelfareYearClose.DONE
    year_close.finished_at = timezone.now()
    year_close.save(update_fields=["status", "finished_at"])
    return swept


def _sweep_member(year_close: WelfareYearClose, member: Member) -> bool:
    year_end = date(year_close.year, 12, 31)
    prepaid = _account(WELFARE_PREPAID_CODE)
    with transaction.atomic():
        member = _lock_member(member)
        if WelfareYearSweep.objects.filter(year_close=year_close, member=member).exists():
            return False
        leftover = welfare_balance(member, as_of=year_end)
        # If the close runs after new-year cases were already levied, those
        # levies consumed last year's leftover first (oldest money first),
        # so only what's still left of it is swept - new-year payments stay.
        used_since = JournalLine.objects.filter(
            account=prepaid, member=member, journal_entry__entry_date__gt=year_end
        ).aggregate(total=Sum("debit"))["total"] or ZERO
        amount = min(max(leftover - used_since, ZERO), max(welfare_balance(member), ZERO))
        if amount <= 0:
            return False
        entry = post_journal_entry(
            description=f"Welfare year-end {year_close.year}: unused balance to Welfare Fund - {member.member_number}",
            entry_date=year_end,
            lines=[
                LineInput(account=prepaid, debit=amount, member=member, description="Unused yearly welfare balance"),
                LineInput(account=_account(WELFARE_FUND_CODE), credit=amount, member=member,
                          description=f"Year-end {year_close.year}"),
            ],
            created_by=year_close.closed_by,
        )
        WelfareYearSweep.objects.create(year_close=year_close, member=member, amount=amount, journal_entry=entry)
    return True


def search_members(query: str, limit: int = 20):
    query = query.strip()
    qs = Member.objects.exclude(status=MemberStatus.EXITED)
    if query:
        qs = qs.filter(
            Q(member_number__icontains=query) | Q(first_name__icontains=query)
            | Q(last_name__icontains=query) | Q(phone_number__icontains=query)
        )
    return qs.order_by("member_number")[:limit]
