import uuid
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from accounting.models import Account
from accounting.services import LineInput, post_journal_entry
from configuration.models import TenantConfig
from members.models import Member, MemberStatus
from notifications.services import queue_sms
from savings.models import SavingsAccount, SavingsTransactionType

from .models import (
    DistributionEntry,
    DistributionEntryStatus,
    DistributionKind,
    DistributionPayout,
    DistributionPayoutStatus,
    DistributionRun,
    DistributionRunStatus,
)

CASH_ACCOUNT_CODE = "1000"
SHARE_CAPITAL_ACCOUNT_CODE = "3000"
DIVIDENDS_PAYABLE_ACCOUNT_CODE = "2100"
INTEREST_PAYABLE_ACCOUNT_CODE = "2200"
WHT_PAYABLE_ACCOUNT_CODE = "2300"
DIVIDEND_EXPENSE_ACCOUNT_CODE = "6000"
INTEREST_EXPENSE_ACCOUNT_CODE = "6100"

TWO_DP = Decimal("0.01")


def _round(amount: Decimal) -> Decimal:
    return amount.quantize(TWO_DP, rounding=ROUND_HALF_UP)


def _savings_account_balance_as_of(savings_account: SavingsAccount, as_of: date) -> Decimal:
    """
    Sums this SPECIFIC account's own SavingsTransaction rows rather than
    reading the 2000 control account's member-tagged balance - the ledger
    only tags a line by member, not by which product/account, so a
    member's control-account balance can't be split back out per product.
    Every transaction posts to both its own SavingsTransaction row and the
    per-member ledger line, so this always reconciles.
    """
    rows = (
        savings_account.transactions.filter(transaction_date__lte=as_of)
        .values("transaction_type")
        .annotate(total=Sum("amount"))
    )
    totals = {r["transaction_type"]: r["total"] or Decimal("0") for r in rows}
    return totals.get(SavingsTransactionType.DEPOSIT, Decimal("0")) - totals.get(
        SavingsTransactionType.WITHDRAWAL, Decimal("0")
    )


def propose_dividend_run(
    *, period_start: date, period_end: date, rate: Decimal, description: str = "", created_by=None
) -> DistributionRun:
    """
    Computes every active member's share-capital balance as of period_end
    (3000 control account, per-member slice) and declares rate x balance as
    gross dividend. Nothing is posted to the ledger - see
    approve_distribution_run. WHT rate/confirmation flag are snapshotted
    from TenantConfig now so a later config change never reprices this run.
    """
    if rate <= 0:
        raise ValueError("Rate must be positive.")

    config = TenantConfig.get_solo()
    share_capital = Account.objects.get(code=SHARE_CAPITAL_ACCOUNT_CODE)

    with transaction.atomic():
        run = DistributionRun.objects.create(
            kind=DistributionKind.DIVIDEND,
            period_start=period_start,
            period_end=period_end,
            rate=rate,
            wht_rate=config.wht_dividends_rate,
            wht_rates_confirmed_by_tax_adviser=config.wht_rates_confirmed_by_tax_adviser,
            description=description,
            proposed_by=created_by,
        )
        entries = []
        for member in Member.objects.filter(status=MemberStatus.ACTIVE):
            balance = share_capital.balance(member=member, as_of=period_end)
            if balance <= 0:
                continue
            gross = _round(balance * rate)
            wht = _round(gross * config.wht_dividends_rate)
            entries.append(
                DistributionEntry(
                    run=run,
                    member=member,
                    basis_balance=balance,
                    gross_amount=gross,
                    wht_amount=wht,
                    net_amount=gross - wht,
                )
            )
        DistributionEntry.objects.bulk_create(entries)
    return run


def propose_interest_run(
    *,
    savings_product,
    period_start: date,
    period_end: date,
    rate: Decimal | None = None,
    description: str = "",
    created_by=None,
) -> DistributionRun:
    """
    Per-account interest run for one savings product. rate defaults to the
    product's own interest_rate but can be overridden (e.g. a board-declared
    rebate that differs from the stated product rate). Balance basis is
    each SavingsAccount's own transaction history, not the ledger's
    member-only-tagged control account (see _savings_account_balance_as_of).
    """
    rate = savings_product.interest_rate if rate is None else rate
    if rate <= 0:
        raise ValueError("Rate must be positive.")

    config = TenantConfig.get_solo()

    with transaction.atomic():
        run = DistributionRun.objects.create(
            kind=DistributionKind.INTEREST,
            savings_product=savings_product,
            period_start=period_start,
            period_end=period_end,
            rate=rate,
            wht_rate=config.wht_interest_rate,
            wht_rates_confirmed_by_tax_adviser=config.wht_rates_confirmed_by_tax_adviser,
            description=description,
            proposed_by=created_by,
        )
        entries = []
        accounts = SavingsAccount.objects.filter(
            product=savings_product, is_active=True, member__status=MemberStatus.ACTIVE,
        ).select_related("member")
        for account in accounts:
            balance = _savings_account_balance_as_of(account, period_end)
            if balance <= 0:
                continue
            gross = _round(balance * rate)
            wht = _round(gross * config.wht_interest_rate)
            entries.append(
                DistributionEntry(
                    run=run,
                    member=account.member,
                    savings_account=account,
                    basis_balance=balance,
                    gross_amount=gross,
                    wht_amount=wht,
                    net_amount=gross - wht,
                )
            )
        DistributionEntry.objects.bulk_create(entries)
    return run


def reject_distribution_run(run: DistributionRun, *, reason: str, rejected_by=None) -> DistributionRun:
    if run.status != DistributionRunStatus.PENDING_APPROVAL:
        raise ValueError("Only a pending-approval run can be rejected.")
    run.status = DistributionRunStatus.REJECTED
    run.rejected_by = rejected_by
    run.rejected_at = timezone.now()
    run.rejection_reason = reason
    run.save(update_fields=["status", "rejected_by", "rejected_at", "rejection_reason"])
    return run


def approve_distribution_run(run: DistributionRun, *, approved_by=None) -> DistributionRun:
    """
    Posts every PROPOSED entry's journal entry inside one DB transaction -
    if any single member's post fails, the whole run rolls back (no
    half-posted dividend declaration). This is where the maker-checker
    separation of duties actually takes effect: distributions.run_dividend/
    run_interest only ever gets here indirectly, via a SEPARATELY
    permissioned distributions.approve_distribution call.
    """
    if run.status != DistributionRunStatus.PENDING_APPROVAL:
        raise ValueError("Only a pending-approval run can be approved.")

    expense_code = (
        DIVIDEND_EXPENSE_ACCOUNT_CODE if run.kind == DistributionKind.DIVIDEND else INTEREST_EXPENSE_ACCOUNT_CODE
    )
    payable_code = (
        DIVIDENDS_PAYABLE_ACCOUNT_CODE if run.kind == DistributionKind.DIVIDEND else INTEREST_PAYABLE_ACCOUNT_CODE
    )
    expense = Account.objects.get(code=expense_code)
    payable = Account.objects.get(code=payable_code)
    wht_payable = Account.objects.get(code=WHT_PAYABLE_ACCOUNT_CODE)

    with transaction.atomic():
        entries = list(run.entries.select_related("member"))
        if not entries:
            raise ValueError("This run has no entries to post.")

        for entry in entries:
            lines = [
                LineInput(
                    account=expense,
                    debit=entry.gross_amount,
                    description=f"{run.get_kind_display()} declared - {entry.member.member_number}",
                ),
                LineInput(
                    account=payable,
                    credit=entry.net_amount,
                    member=entry.member,
                    description=f"{run.get_kind_display()} payable",
                ),
            ]
            # Omit the WHT line entirely when wht_amount is 0 - a zero-value
            # line has neither debit nor credit set, which post_journal_entry
            # rejects as "neither" rather than treating it as a no-op line.
            if entry.wht_amount > 0:
                lines.append(
                    LineInput(
                        account=wht_payable,
                        credit=entry.wht_amount,
                        description=f"WHT withheld - {entry.member.member_number}",
                    )
                )
            entry.journal_entry = post_journal_entry(
                description=f"{run.get_kind_display()} - {entry.member.member_number}",
                entry_date=date.today(),
                lines=lines,
                created_by=approved_by,
            )
            entry.status = DistributionEntryStatus.POSTED
            entry.save(update_fields=["journal_entry", "status"])

        run.status = DistributionRunStatus.APPROVED
        run.approved_by = approved_by
        run.approved_at = timezone.now()
        run.save(update_fields=["status", "approved_by", "approved_at"])

    for entry in entries:
        transaction.on_commit(
            lambda entry=entry: queue_sms(
                member=entry.member,
                event_type="distribution_declared",
                recipient=entry.member.phone_number,
                message=(
                    f"{run.get_kind_display()} declared: {entry.net_amount} "
                    f"(after {entry.wht_amount} WHT) will be paid to your mobile money."
                ),
            )
        )
    return run


def initiate_distribution_payout(
    *, entry: DistributionEntry, phone_number: str, idempotency_key: str | None = None, created_by=None
) -> DistributionPayout:
    """
    Mirrors loans.services.initiate_loan_disbursement_mobile_money exactly -
    same idempotency-key short-circuit, same provider call shape, just
    kind="distribution" so MockPaymentProvider schedules the distribution
    callback task rather than the loan one.
    """
    if entry.status != DistributionEntryStatus.POSTED:
        raise ValueError("Only a posted distribution entry can be paid out.")

    from payments.providers.registry import get_active_payment_provider

    idempotency_key = idempotency_key or f"distpayout-{uuid.uuid4().hex}"
    existing = DistributionPayout.objects.filter(idempotency_key=idempotency_key).first()
    if existing is not None:
        return existing

    provider = get_active_payment_provider()
    payout = DistributionPayout.objects.create(
        idempotency_key=idempotency_key,
        entry=entry,
        provider=provider.code,
        phone_number=phone_number,
        amount=entry.net_amount,
        created_by=created_by,
    )
    result = provider.initiate_disbursement(
        phone_number=phone_number, amount=entry.net_amount, reference=str(payout.id), kind="distribution",
    )
    if result.success:
        payout.provider_reference = result.provider_reference
        payout.save(update_fields=["provider_reference"])
    else:
        payout.status = DistributionPayoutStatus.FAILED
        payout.failure_reason = result.error
        payout.completed_at = timezone.now()
        payout.save(update_fields=["status", "failure_reason", "completed_at"])
    return payout


def handle_distribution_payout_callback(
    *, provider_code: str, provider_reference: str, success: bool, failure_reason: str = "", raw_payload=None
) -> DistributionPayout | None:
    """
    Mirrors loans.services.handle_loan_disbursement_callback exactly. On
    success this is the step that actually clears the ledger: the
    Dividends/Interest Payable liability booked at approval time is debited
    away against Cash credited - without this posting, the books would
    still show the SACCO owing the money after it has actually been paid
    out via mobile money. Idempotent against a redelivered callback
    (CLAUDE.md rule 4): once terminal, this is a no-op.
    """
    with transaction.atomic():
        payout = (
            DistributionPayout.objects.select_for_update()
            .filter(provider_reference=provider_reference, provider=provider_code)
            .first()
        )
        if payout is None:
            return None
        if payout.status != DistributionPayoutStatus.PENDING:
            return payout

        payout.raw_callback = raw_payload
        payout.completed_at = timezone.now()

        if not success:
            payout.status = DistributionPayoutStatus.FAILED
            payout.failure_reason = failure_reason
            payout.save(update_fields=["status", "failure_reason", "raw_callback", "completed_at"])
            return payout

        entry = payout.entry
        payable_code = (
            DIVIDENDS_PAYABLE_ACCOUNT_CODE
            if entry.run.kind == DistributionKind.DIVIDEND
            else INTEREST_PAYABLE_ACCOUNT_CODE
        )
        payable = Account.objects.get(code=payable_code)
        cash = Account.objects.get(code=CASH_ACCOUNT_CODE)
        post_journal_entry(
            description=f"{entry.run.get_kind_display()} payout (mobile money) - {entry.member.member_number}",
            entry_date=date.today(),
            lines=[
                LineInput(
                    account=payable, debit=payout.amount, member=entry.member, description="Distribution paid out"
                ),
                LineInput(account=cash, credit=payout.amount, description="Distribution paid out via mobile money"),
            ],
            created_by=payout.created_by,
        )

        payout.status = DistributionPayoutStatus.SUCCESS
        payout.save(update_fields=["status", "raw_callback", "completed_at"])
        entry.status = DistributionEntryStatus.PAID
        entry.save(update_fields=["status"])

    transaction.on_commit(
        lambda: queue_sms(
            member=payout.entry.member,
            event_type="distribution_paid",
            recipient=payout.phone_number,
            message=f"Paid: {payout.amount} to your mobile money. Ref {payout.provider_reference}.",
        )
    )
    return payout
