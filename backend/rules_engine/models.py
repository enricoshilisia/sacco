import uuid

from django.db import models

from core.models import AuditMixin
from loans.models import LoanProduct


class LoanEligibilityPolicy(AuditMixin, models.Model):
    """
    Declarative auto grant/deny rules for one loan product (BUILD_PLAN.md
    Phase 4: "rules_engine ... declarative eligibility rules"). Absence of
    a policy for a product (or is_active=False) means that product keeps
    behaving exactly as before this app existed - manual staff
    appraise/decide only. See rules_engine.services.evaluate_loan for how
    these fields are applied.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    product = models.OneToOneField(LoanProduct, on_delete=models.CASCADE, related_name="eligibility_policy")
    is_active = models.BooleanField(default=True)

    require_kyc_verified = models.BooleanField(default=True)
    require_no_active_arrears = models.BooleanField(default=True)
    max_active_loans = models.PositiveSmallIntegerField(null=True, blank=True)
    min_membership_months = models.PositiveSmallIntegerField(default=0)
    min_guarantor_coverage_ratio = models.DecimalField(
        max_digits=5, decimal_places=2, null=True, blank=True,
        help_text="Only applies to products that require guarantors - total CONSENTED pledged "
        "amount must cover at least this ratio of amount_requested (e.g. 1.00 = 100%).",
    )

    require_crb_check = models.BooleanField(default=False)
    crb_deny_below_score = models.PositiveSmallIntegerField(
        null=True, blank=True, help_text="A CRB score below this is a hard deny."
    )
    crb_refer_below_score = models.PositiveSmallIntegerField(
        null=True, blank=True,
        help_text="A CRB score below this (but at/above the deny threshold) is referred to manual appraisal.",
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Eligibility policy for {self.product.name}"
