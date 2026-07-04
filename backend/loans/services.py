import uuid
from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from dateutil.relativedelta import relativedelta
from django.db import transaction
from django.db.models import Sum
from django.utils import timezone

from configuration.models import TenantConfig

from .models import (
    DisbursementMethod,
    DisbursementStatus,
    InterestMethod,
    Loan,
    LoanDisbursement,
    LoanGuarantor,
    LoanGuarantorStatus,
    LoanRepayment,
    LoanRepaymentSchedule,
    LoanStatus,
)

# Duplicated from savings/services.py rather than imported - loans<->savings
# cross-app touchpoints in this codebase are all lazy function-local imports
# (see get_available_deposits below) specifically to avoid tangling
# app-loading order between these apps, and a bare string constant isn't
# worth reaching across that boundary for.
CASH_ACCOUNT_CODE = "1000"
SAVINGS_CONTROL_ACCOUNT_CODE = "2000"
LOANS_RECEIVABLE_ACCOUNT_CODE = "4000"
INTEREST_INCOME_ACCOUNT_CODE = "5000"

CENT = Decimal("0.01")


def _q(value: Decimal) -> Decimal:
    """The one rounding convention for money derived by calculation (as
    opposed to entered directly) anywhere in this codebase - established
    here because amortization is the first place anything needs to round a
    computed value rather than just store what a user typed."""
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def locked_pledge_total(member) -> Decimal:
    """
    How much of this member's deposits are currently locked as pledged
    security for OTHER members' loans they're guaranteeing. Only CONSENTED
    pledges lock anything - a PENDING request the guarantor hasn't
    responded to yet doesn't restrict them (CLAUDE.md: "Pledges need
    explicit consent"). This is the single source of truth both
    loans.services (a guarantor's own borrowing capacity) and
    savings.services.withdraw_savings (a guarantor's available-to-withdraw
    balance) use - CLAUDE.md: a pledge "reduces what the guarantor can
    themselves borrow/withdraw," both, not just one.
    """
    total = LoanGuarantor.objects.filter(
        guarantor=member, status=LoanGuarantorStatus.CONSENTED
    ).aggregate(total=Sum("pledged_amount"))["total"]
    return total or Decimal("0")


def get_available_deposits(member) -> Decimal:
    """Member's savings balance minus whatever of it is locked pledging
    security for someone else's loan."""
    from accounting.models import Account
    from savings.services import SAVINGS_CONTROL_ACCOUNT_CODE

    savings_control = Account.objects.get(code=SAVINGS_CONTROL_ACCOUNT_CODE)
    balance = savings_control.balance(member=member)
    return balance - locked_pledge_total(member)


def apply_for_loan(
    *, member, product, amount_requested: Decimal, term_months: int, purpose: str = "", created_by=None
) -> Loan:
    if amount_requested <= 0:
        raise ValueError("Loan amount must be positive.")
    if not (product.min_term_months <= term_months <= product.max_term_months):
        raise ValueError(
            f"Term must be between {product.min_term_months} and {product.max_term_months} months."
        )

    multiplier = product.max_multiple_of_deposits or TenantConfig.get_solo().default_loan_multiplier
    available = get_available_deposits(member)
    max_borrowable = available * multiplier
    if amount_requested > max_borrowable:
        raise ValueError(
            f"Requested amount {amount_requested} exceeds this member's borrowing limit of "
            f"{max_borrowable} ({multiplier}x available deposits of {available})."
        )

    initial_status = (
        LoanStatus.PENDING_GUARANTORS if product.requires_guarantors else LoanStatus.PENDING_APPRAISAL
    )
    loan = Loan.objects.create(
        member=member,
        product=product,
        amount_requested=amount_requested,
        term_months=term_months,
        purpose=purpose,
        interest_method=product.interest_method,
        interest_rate=product.interest_rate,
        status=initial_status,
        created_by=created_by,
    )
    if initial_status == LoanStatus.PENDING_APPRAISAL:
        loan = _attempt_auto_decision(loan)
    return loan


def add_guarantor(*, loan: Loan, guarantor, pledged_amount: Decimal) -> LoanGuarantor:
    if loan.status != LoanStatus.PENDING_GUARANTORS:
        raise ValueError("Guarantors can only be added while this loan is awaiting guarantors.")
    if guarantor.id == loan.member_id:
        raise ValueError("A member cannot guarantee their own loan.")
    if pledged_amount <= 0:
        raise ValueError("Pledged amount must be positive.")
    if loan.guarantors.filter(guarantor=guarantor).exists():
        raise ValueError("This member has already been asked to guarantee this loan.")
    return LoanGuarantor.objects.create(loan=loan, guarantor=guarantor, pledged_amount=pledged_amount)


def respond_to_guarantee(*, loan_guarantor: LoanGuarantor, accept: bool) -> LoanGuarantor:
    if loan_guarantor.status != LoanGuarantorStatus.PENDING:
        raise ValueError("This guarantee request has already been responded to.")

    if accept:
        available = get_available_deposits(loan_guarantor.guarantor)
        if loan_guarantor.pledged_amount > available:
            raise ValueError(
                f"Insufficient available deposits to pledge this amount (available: {available})."
            )
        loan_guarantor.status = LoanGuarantorStatus.CONSENTED
    else:
        loan_guarantor.status = LoanGuarantorStatus.DECLINED

    loan_guarantor.responded_at = timezone.now()
    loan_guarantor.save(update_fields=["status", "responded_at"])
    return loan_guarantor


def submit_for_appraisal(*, loan: Loan) -> Loan:
    if loan.status != LoanStatus.PENDING_GUARANTORS:
        raise ValueError("This loan isn't awaiting guarantors.")
    consented = loan.guarantors.filter(status=LoanGuarantorStatus.CONSENTED).count()
    if consented < loan.product.min_guarantors:
        raise ValueError(
            f"At least {loan.product.min_guarantors} consenting guarantor(s) are required (have {consented})."
        )
    loan.status = LoanStatus.PENDING_APPRAISAL
    loan.save(update_fields=["status"])
    return _attempt_auto_decision(loan)


def appraise_loan(*, loan: Loan, appraised_by, notes: str = "") -> Loan:
    if loan.status != LoanStatus.PENDING_APPRAISAL:
        raise ValueError("This loan isn't pending appraisal.")
    loan.status = LoanStatus.APPRAISED
    loan.appraised_at = timezone.now()
    loan.appraised_by = appraised_by
    loan.appraisal_notes = notes
    loan.save(update_fields=["status", "appraised_at", "appraised_by", "appraisal_notes"])
    return loan


def decide_loan(*, loan: Loan, approve: bool, decided_by, notes: str = "") -> Loan:
    if loan.status != LoanStatus.APPRAISED:
        raise ValueError("This loan isn't ready for a decision (must be appraised first).")

    if approve:
        loan.status = LoanStatus.APPROVED
    else:
        loan.status = LoanStatus.REJECTED
        # The loan will never disburse now - free up any deposits its
        # guarantors had locked as security.
        loan.guarantors.filter(status=LoanGuarantorStatus.CONSENTED).update(
            status=LoanGuarantorStatus.RELEASED, released_at=timezone.now()
        )

    loan.decided_at = timezone.now()
    loan.decided_by = decided_by
    loan.decision_notes = notes
    loan.save(update_fields=["status", "decided_at", "decided_by", "decision_notes"])
    return loan


def _attempt_auto_decision(loan: Loan) -> Loan:
    """
    Called the moment a loan reaches PENDING_APPRAISAL (from apply_for_loan
    for no-guarantor products, or from submit_for_appraisal once guarantor
    consent completes). If the product has an active LoanEligibilityPolicy
    (rules_engine app - BUILD_PLAN.md Phase 4's "rules engine
    approves/denies") that can confidently decide, this reuses
    appraise_loan/decide_loan exactly as a human would (appraised_by/
    decided_by=None marks "the system decided this"), landing at APPROVED
    or REJECTED immediately. A REFER outcome (no policy configured, or the
    engine can't confidently decide) leaves the loan untouched at
    PENDING_APPRAISAL for the existing manual appraise->decide flow.
    """
    from rules_engine.services import evaluate_loan

    decision = evaluate_loan(loan)
    if decision.outcome == "REFER":
        return loan

    notes = "Automated decision (Rules Engine): " + "; ".join(decision.reasons)
    loan = appraise_loan(loan=loan, appraised_by=None, notes=notes)
    loan = decide_loan(loan=loan, approve=(decision.outcome == "APPROVE"), decided_by=None, notes=notes)
    loan.is_auto_decision = True
    loan.save(update_fields=["is_auto_decision"])
    return loan


def generate_amortization_schedule(
    *, principal: Decimal, annual_rate: Decimal, term_months: int, interest_method: str, start_date: date
) -> list[dict]:
    """
    Pure function, no DB writes - `_generate_and_save_schedule` below turns
    the result into LoanRepaymentSchedule rows. Both methods use a
    rounding-residual correction on the final installment (principal always;
    interest too for FLAT) so the schedule always sums to exactly
    `principal` - Decimal division is exact to the context's precision but
    not necessarily to the cent, and CLAUDE.md demands correctness, not
    "close enough." This is the "reducing-balance math" landmine
    BUILD_PLAN.md calls out for this phase.

    FLAT: equal principal + equal (flat) interest every period.
    REDUCING_BALANCE: standard amortized-payment formula (level installment,
    each period split between interest on the declining balance and
    principal) - installment = P*r/(1-(1+r)^-n), which Decimal computes
    correctly for a negative integer exponent (term_months is always a
    small positive int, so -term_months is always a valid integer power).
    """
    rows = []

    if interest_method == InterestMethod.FLAT:
        total_interest = _q(principal * annual_rate * term_months / Decimal(12))
        monthly_principal = _q(principal / term_months)
        monthly_interest = _q(total_interest / term_months)
        principal_allocated = Decimal("0")
        interest_allocated = Decimal("0")
        for n in range(1, term_months + 1):
            if n < term_months:
                principal_due = monthly_principal
                interest_due = monthly_interest
            else:
                principal_due = principal - principal_allocated
                interest_due = total_interest - interest_allocated
            principal_allocated += principal_due
            interest_allocated += interest_due
            rows.append(
                {
                    "installment_number": n,
                    "due_date": start_date + relativedelta(months=n),
                    "principal_due": principal_due,
                    "interest_due": interest_due,
                }
            )
        return rows

    # REDUCING_BALANCE
    monthly_rate = annual_rate / Decimal(12)
    if monthly_rate == 0:
        installment = _q(principal / term_months)
    else:
        installment = _q(principal * monthly_rate / (1 - (1 + monthly_rate) ** -term_months))
    balance = principal
    for n in range(1, term_months + 1):
        interest_due = _q(balance * monthly_rate)
        if n < term_months:
            principal_due = installment - interest_due
        else:
            # Absorb whatever's left, cent-exact, rather than trust the
            # formula's own output for the last period - this is the step
            # that guarantees the loan always amortizes to exactly zero.
            principal_due = balance
        balance -= principal_due
        rows.append(
            {
                "installment_number": n,
                "due_date": start_date + relativedelta(months=n),
                "principal_due": principal_due,
                "interest_due": interest_due,
            }
        )
    return rows


def _generate_and_save_schedule(loan: Loan, *, start_date: date) -> None:
    rows = generate_amortization_schedule(
        principal=loan.amount_requested,
        annual_rate=loan.interest_rate,
        term_months=loan.term_months,
        interest_method=loan.interest_method,
        start_date=start_date,
    )
    LoanRepaymentSchedule.objects.bulk_create(LoanRepaymentSchedule(loan=loan, **row) for row in rows)


def disburse_to_savings(*, loan: Loan, product, created_by=None) -> Loan:
    """
    Path A - the primary, synchronous disbursement: credit the loan amount
    straight into one of the member's own savings accounts (opened on
    first use, same as a manual deposit - savings.services.
    get_or_open_savings_account). No payment provider involved; the member
    withdraws through the already-built savings withdrawal flow if they
    want cash/mobile money out. `product` is explicit, not auto-selected -
    matches how every other deposit-shaped action in this codebase already
    requires the caller to name a product rather than guessing a "default"
    one (see payments.serializers.InitiateCollectionInputSerializer).
    """
    if loan.status != LoanStatus.APPROVED:
        raise ValueError("Only an approved loan can be disbursed.")

    from accounting.models import Account
    from accounting.services import LineInput, post_journal_entry
    from savings.services import get_or_open_savings_account

    loans_receivable = Account.objects.get(code=LOANS_RECEIVABLE_ACCOUNT_CODE)
    savings_control = Account.objects.get(code=SAVINGS_CONTROL_ACCOUNT_CODE)
    savings_account = get_or_open_savings_account(loan.member, product)
    amount = loan.amount_requested

    with transaction.atomic():
        post_journal_entry(
            description=f"Loan disbursement - {loan.product.name} - {loan.member.member_number}",
            entry_date=date.today(),
            lines=[
                LineInput(account=loans_receivable, debit=amount, member=loan.member, description="Loan disbursed"),
                LineInput(
                    account=savings_control,
                    credit=amount,
                    member=loan.member,
                    description=f"Loan disbursement credited to {savings_account.product.name}",
                ),
            ],
            created_by=created_by,
        )
        now = timezone.now()
        loan.status = LoanStatus.ACTIVE
        loan.disbursed_at = now
        loan.disbursement_method = DisbursementMethod.SAVINGS_CREDIT
        loan.save(update_fields=["status", "disbursed_at", "disbursement_method"])
        _generate_and_save_schedule(loan, start_date=now.date())

    return loan


def initiate_loan_disbursement_mobile_money(
    *, loan: Loan, phone_number: str, idempotency_key: str | None = None, created_by=None
) -> LoanDisbursement:
    """
    Path B - mirrors payments.services.initiate_collection's idempotency-
    key short-circuit exactly (CLAUDE.md rule 4: "every collection/
    disbursement carries an idempotency key"). Moves the loan to the
    transient DISBURSED status; handle_loan_disbursement_callback below is
    the only thing that ever moves it out of that state. Only the Mock
    provider actually completes this end to end today - a real provider's
    B2C disbursement staying NotImplementedError is the same posture this
    codebase already takes with Selcom outside its primary market.
    """
    if loan.status != LoanStatus.APPROVED:
        raise ValueError("Only an approved loan can be disbursed.")

    from payments.providers.registry import get_active_payment_provider

    idempotency_key = idempotency_key or f"loandisb-{uuid.uuid4().hex}"
    existing = LoanDisbursement.objects.filter(idempotency_key=idempotency_key).first()
    if existing is not None:
        return existing

    provider = get_active_payment_provider()
    disbursement = LoanDisbursement.objects.create(
        idempotency_key=idempotency_key,
        loan=loan,
        provider=provider.code,
        phone_number=phone_number,
        amount=loan.amount_requested,
        created_by=created_by,
    )
    result = provider.initiate_disbursement(
        phone_number=phone_number, amount=loan.amount_requested, reference=str(disbursement.id)
    )
    if result.success:
        disbursement.provider_reference = result.provider_reference
        disbursement.save(update_fields=["provider_reference"])
        loan.status = LoanStatus.DISBURSED
        loan.save(update_fields=["status"])
    else:
        disbursement.status = DisbursementStatus.FAILED
        disbursement.failure_reason = result.error
        disbursement.completed_at = timezone.now()
        disbursement.save(update_fields=["status", "failure_reason", "completed_at"])
    return disbursement


def handle_loan_disbursement_callback(
    *, provider_code: str, provider_reference: str, success: bool, failure_reason: str = "", raw_payload=None
) -> LoanDisbursement | None:
    """
    Mirrors payments.services.handle_collection_callback exactly - the one
    place a disbursement provider callback (real webhook or the mock's
    simulated one) is allowed to move a LoanDisbursement out of PENDING.
    Idempotent by construction: callbacks WILL be delivered more than once
    (CLAUDE.md rule 4), so once a disbursement is already terminal this is
    a no-op that returns it unchanged rather than posting to the ledger a
    second time. select_for_update() closes the race where two deliveries
    of the same callback arrive concurrently.
    """
    from accounting.models import Account
    from accounting.services import LineInput, post_journal_entry

    with transaction.atomic():
        disbursement = (
            LoanDisbursement.objects.select_for_update()
            .filter(provider_reference=provider_reference, provider=provider_code)
            .first()
        )
        if disbursement is None:
            return None
        if disbursement.status != DisbursementStatus.PENDING:
            return disbursement

        disbursement.raw_callback = raw_payload
        disbursement.completed_at = timezone.now()

        if not success:
            disbursement.status = DisbursementStatus.FAILED
            disbursement.failure_reason = failure_reason
            disbursement.save(update_fields=["status", "failure_reason", "raw_callback", "completed_at"])
            loan = disbursement.loan
            loan.status = LoanStatus.APPROVED
            loan.save(update_fields=["status"])
            return disbursement

        loan = disbursement.loan
        loans_receivable = Account.objects.get(code=LOANS_RECEIVABLE_ACCOUNT_CODE)
        cash = Account.objects.get(code=CASH_ACCOUNT_CODE)
        post_journal_entry(
            description=f"Loan disbursement (mobile money) - {loan.product.name} - {loan.member.member_number}",
            entry_date=date.today(),
            lines=[
                LineInput(account=loans_receivable, debit=disbursement.amount, member=loan.member, description="Loan disbursed"),
                LineInput(account=cash, credit=disbursement.amount, description="Loan disbursed via mobile money"),
            ],
            created_by=disbursement.created_by,
        )
        now = timezone.now()
        loan.status = LoanStatus.ACTIVE
        loan.disbursed_at = now
        loan.disbursement_method = DisbursementMethod.MOBILE_MONEY
        loan.save(update_fields=["status", "disbursed_at", "disbursement_method"])
        _generate_and_save_schedule(loan, start_date=now.date())

        disbursement.status = DisbursementStatus.SUCCESS
        disbursement.save(update_fields=["status", "raw_callback", "completed_at"])

    return disbursement


def record_loan_repayment(
    *, loan: Loan, amount: Decimal, transaction_date: date, created_by=None, description: str = ""
) -> LoanRepayment:
    """
    Allocates the payment across the schedule oldest-installment-first,
    interest before principal within each installment (standard loan-
    servicing waterfall), posts one balanced journal entry, and closes the
    loan - releasing any CONSENTED guarantor pledges on it, the exact same
    release this codebase already does when a loan is rejected
    (decide_loan) - the moment every installment is fully paid. Rejects
    outright rather than allow overpayment/a credit balance, same posture
    as savings.services.withdraw_savings's InsufficientBalance.
    """
    if loan.status != LoanStatus.ACTIVE:
        raise ValueError("Only an active loan can receive a repayment.")
    if amount <= 0:
        raise ValueError("Repayment amount must be positive.")

    from accounting.models import Account
    from accounting.services import LineInput, post_journal_entry

    with transaction.atomic():
        schedule = list(
            LoanRepaymentSchedule.objects.select_for_update().filter(loan=loan).order_by("installment_number")
        )
        remaining = sum(
            (row.total_due - row.principal_paid - row.interest_paid for row in schedule), Decimal("0")
        )
        if amount > remaining:
            raise ValueError(f"Repayment of {amount} exceeds the remaining balance of {remaining}.")

        left = amount
        principal_portion = Decimal("0")
        interest_portion = Decimal("0")
        rows_to_update = []
        for row in schedule:
            if left <= 0:
                break
            changed = False
            interest_gap = row.interest_due - row.interest_paid
            if interest_gap > 0:
                pay = min(left, interest_gap)
                row.interest_paid += pay
                interest_portion += pay
                left -= pay
                changed = True
            principal_gap = row.principal_due - row.principal_paid
            if left > 0 and principal_gap > 0:
                pay = min(left, principal_gap)
                row.principal_paid += pay
                principal_portion += pay
                left -= pay
                changed = True
            if changed:
                rows_to_update.append(row)

        LoanRepaymentSchedule.objects.bulk_update(rows_to_update, ["principal_paid", "interest_paid"])

        lines = [
            LineInput(
                account=Account.objects.get(code=CASH_ACCOUNT_CODE), debit=amount, description="Loan repayment received"
            )
        ]
        if principal_portion > 0:
            lines.append(
                LineInput(
                    account=Account.objects.get(code=LOANS_RECEIVABLE_ACCOUNT_CODE),
                    credit=principal_portion,
                    member=loan.member,
                    description="Loan repayment - principal",
                )
            )
        if interest_portion > 0:
            lines.append(
                LineInput(
                    account=Account.objects.get(code=INTEREST_INCOME_ACCOUNT_CODE),
                    credit=interest_portion,
                    description="Loan repayment - interest",
                )
            )

        entry = post_journal_entry(
            description=description or f"Loan repayment - {loan.member.full_name()}",
            entry_date=transaction_date,
            lines=lines,
            created_by=created_by,
        )
        repayment = LoanRepayment.objects.create(
            loan=loan,
            amount=amount,
            transaction_date=transaction_date,
            journal_entry=entry,
            created_by=created_by,
            description=description,
        )

        if all(row.is_paid for row in schedule):
            now = timezone.now()
            loan.status = LoanStatus.CLOSED
            loan.closed_at = now
            loan.save(update_fields=["status", "closed_at"])
            loan.guarantors.filter(status=LoanGuarantorStatus.CONSENTED).update(
                status=LoanGuarantorStatus.RELEASED, released_at=now
            )

    return repayment


def mark_loan_defaulted(*, loan: Loan, notes: str, created_by=None) -> Loan:
    """
    Manual staff action only - no automatic threshold exists to trigger
    this (no arrears-bucket/grace-period config anywhere in TenantConfig
    yet), and a real write-off posting (bad-debt expense, provisioning
    policy) is a deliberate non-goal of this slice: inventing one without
    guidance on provisioning policy would be guessing at exactly the kind
    of thing CLAUDE.md says to ask about rather than assume.
    """
    if loan.status != LoanStatus.ACTIVE:
        raise ValueError("Only an active loan can be marked defaulted.")
    loan.status = LoanStatus.DEFAULTED
    loan.defaulted_at = timezone.now()
    loan.default_notes = notes
    loan.save(update_fields=["status", "defaulted_at", "default_notes"])
    return loan


def get_arrears_status(loan: Loan) -> dict:
    """
    Read-only, computed fresh every call - no stored/cached field, no
    scheduled job (nothing here needs Celery: nothing is mutated). Phase
    4's own "done when" only asks for arrears to be tracked and visible on
    a loan, not reported on - a dashboard/report across every loan is
    Phase 7's territory per BUILD_PLAN.md's own phase boundaries.
    """
    if loan.status != LoanStatus.ACTIVE:
        return {"is_overdue": False, "days_overdue": 0, "bucket": "N/A", "amount_overdue": Decimal("0")}

    today = date.today()
    overdue_rows = [row for row in loan.schedule.all() if row.due_date < today and not row.is_paid]
    if not overdue_rows:
        return {"is_overdue": False, "days_overdue": 0, "bucket": "CURRENT", "amount_overdue": Decimal("0")}

    earliest_due = min(row.due_date for row in overdue_rows)
    days_overdue = (today - earliest_due).days
    amount_overdue = sum(
        (row.total_due - row.principal_paid - row.interest_paid for row in overdue_rows), Decimal("0")
    )
    if days_overdue <= 30:
        bucket = "1-30"
    elif days_overdue <= 60:
        bucket = "31-60"
    elif days_overdue <= 90:
        bucket = "61-90"
    else:
        bucket = "90+"
    return {"is_overdue": True, "days_overdue": days_overdue, "bucket": bucket, "amount_overdue": amount_overdue}
