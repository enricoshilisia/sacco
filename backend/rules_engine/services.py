from dataclasses import dataclass, field
from datetime import date
from decimal import Decimal

from .models import LoanEligibilityPolicy


@dataclass
class EligibilityDecision:
    outcome: str  # "APPROVE" | "DENY" | "REFER"
    reasons: list[str] = field(default_factory=list)


def _months_since(d: date) -> int:
    today = date.today()
    return (today.year - d.year) * 12 + (today.month - d.month)


def evaluate_loan(loan) -> EligibilityDecision:
    """
    Declarative auto grant/deny (BUILD_PLAN.md Phase 4). Runs the
    product's active LoanEligibilityPolicy, if one exists, against this
    loan's member/application. A product with no active policy always
    REFERs - i.e. behaves exactly as it did before this app existed,
    falling back to the existing manual staff appraise/decide flow
    (loans.services.appraise_loan / decide_loan), untouched.
    """
    # Lazy import: loans imports rules_engine (to call evaluate_loan), so
    # rules_engine importing loans at module load time would be circular -
    # same convention loans.services already uses for its own cross-app
    # imports (e.g. get_available_deposits importing accounting/savings).
    from loans.models import Loan, LoanGuarantorStatus, LoanStatus
    from loans.services import get_arrears_status

    policy = LoanEligibilityPolicy.objects.filter(product=loan.product, is_active=True).first()
    if policy is None:
        return EligibilityDecision(outcome="REFER", reasons=["No active eligibility policy for this product."])

    member = loan.member
    reasons: list[str] = []
    hard_fail = False
    needs_referral = False

    if policy.require_kyc_verified:
        if member.is_kyc_verified:
            reasons.append("KYC verified.")
        else:
            hard_fail = True
            reasons.append("KYC not verified.")

    active_loans = list(Loan.objects.filter(member=member, status=LoanStatus.ACTIVE))

    if policy.require_no_active_arrears:
        overdue = [l for l in active_loans if get_arrears_status(l)["is_overdue"]]
        if overdue:
            hard_fail = True
            reasons.append(f"{len(overdue)} existing active loan(s) in arrears.")
        else:
            reasons.append("No active loans in arrears.")

    if policy.max_active_loans is not None:
        if len(active_loans) >= policy.max_active_loans:
            hard_fail = True
            reasons.append(f"Already has {len(active_loans)} active loan(s), max is {policy.max_active_loans}.")
        else:
            reasons.append(f"{len(active_loans)} active loan(s), within the limit of {policy.max_active_loans}.")

    if policy.min_membership_months:
        months = _months_since(member.date_joined)
        if months < policy.min_membership_months:
            hard_fail = True
            reasons.append(f"Member for {months} month(s), needs {policy.min_membership_months}.")
        else:
            reasons.append(f"Member for {months} month(s), meets the {policy.min_membership_months}-month minimum.")

    if loan.product.requires_guarantors and policy.min_guarantor_coverage_ratio is not None:
        pledged = sum(
            (g.pledged_amount for g in loan.guarantors.filter(status=LoanGuarantorStatus.CONSENTED)),
            Decimal("0"),
        )
        required = loan.amount_requested * policy.min_guarantor_coverage_ratio
        if pledged < required:
            hard_fail = True
            reasons.append(f"Guarantor coverage {pledged} is below the required {required}.")
        else:
            reasons.append(f"Guarantor coverage {pledged} meets the required {required}.")

    if policy.require_crb_check:
        from .crb.registry import get_active_crb_provider

        result = get_active_crb_provider().check(member=member)
        if not result.has_record:
            needs_referral = True
            reasons.append("CRB check: no record found - referred for manual review.")
        elif result.is_blacklisted or (
            policy.crb_deny_below_score is not None and result.score < policy.crb_deny_below_score
        ):
            hard_fail = True
            reasons.append(f"CRB check failed (score {result.score}, blacklisted={result.is_blacklisted}).")
        elif policy.crb_refer_below_score is not None and result.score < policy.crb_refer_below_score:
            needs_referral = True
            reasons.append(f"CRB score {result.score} is borderline - referred for manual review.")
        else:
            reasons.append(f"CRB check passed (score {result.score}).")

    if hard_fail:
        return EligibilityDecision(outcome="DENY", reasons=reasons)
    if needs_referral:
        return EligibilityDecision(outcome="REFER", reasons=reasons)
    return EligibilityDecision(outcome="APPROVE", reasons=reasons)
