from decimal import Decimal

from django.db.models import Sum
from django.utils import timezone

from configuration.models import TenantConfig

from .models import Loan, LoanGuarantor, LoanGuarantorStatus, LoanStatus


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
    return Loan.objects.create(
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
    return loan


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
