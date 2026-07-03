import uuid

from django.conf import settings
from django.db import models


class InterestMethod(models.TextChoices):
    REDUCING_BALANCE = "REDUCING_BALANCE", "Reducing balance"
    FLAT = "FLAT", "Flat"


class LoanProduct(models.Model):
    """A loan product definition - term/rate/eligibility rules. The actual
    method (reducing-balance vs flat) is per-product config, never a code
    branch (CLAUDE.md: "Loan interest: support both ... method is per loan
    product config")."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100)
    code = models.SlugField(max_length=30, unique=True)

    interest_method = models.CharField(max_length=20, choices=InterestMethod.choices)
    interest_rate = models.DecimalField(
        max_digits=6, decimal_places=4, help_text="Annual rate, e.g. 0.1200 = 12%"
    )

    min_term_months = models.PositiveSmallIntegerField(default=1)
    max_term_months = models.PositiveSmallIntegerField(default=12)

    # Null falls back to TenantConfig.default_loan_multiplier - a product
    # only needs its own multiplier when it deliberately differs from the
    # tenant's default (CLAUDE.md rule 6: config, not a hardcoded number).
    max_multiple_of_deposits = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)

    requires_guarantors = models.BooleanField(default=True)
    min_guarantors = models.PositiveSmallIntegerField(default=0)

    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class LoanStatus(models.TextChoices):
    PENDING_GUARANTORS = "PENDING_GUARANTORS", "Awaiting guarantors"
    PENDING_APPRAISAL = "PENDING_APPRAISAL", "Pending appraisal"
    APPRAISED = "APPRAISED", "Appraised - awaiting decision"
    APPROVED = "APPROVED", "Approved - awaiting disbursement"
    REJECTED = "REJECTED", "Rejected"
    # DISBURSED / ACTIVE / CLOSED / DEFAULTED are added when disbursement +
    # repayment land (Phase 4 slice 2) - no point modeling states nothing
    # can reach yet.


class Loan(models.Model):
    """
    One loan application, tracked through its own lifecycle rather than as
    separate "application" and "loan" objects - there's only ever one
    record per borrow request, and its status field is the whole story.
    interest_rate/interest_method are snapshotted from the product at
    application time so a later product-rate change never silently
    reprices an existing application.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey("members.Member", on_delete=models.PROTECT, related_name="loans")
    product = models.ForeignKey(LoanProduct, on_delete=models.PROTECT, related_name="loans")

    amount_requested = models.DecimalField(max_digits=18, decimal_places=2)
    term_months = models.PositiveSmallIntegerField()
    purpose = models.CharField(max_length=255, blank=True)

    interest_method = models.CharField(max_length=20, choices=InterestMethod.choices)
    interest_rate = models.DecimalField(max_digits=6, decimal_places=4)

    status = models.CharField(max_length=20, choices=LoanStatus.choices, default=LoanStatus.PENDING_GUARANTORS)

    applied_at = models.DateTimeField(auto_now_add=True)

    appraised_at = models.DateTimeField(null=True, blank=True)
    appraised_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    appraisal_notes = models.TextField(blank=True)

    decided_at = models.DateTimeField(null=True, blank=True)
    decided_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    decision_notes = models.TextField(blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-applied_at"]

    def __str__(self):
        return f"Loan {self.amount_requested} for {self.member} ({self.status})"


class LoanGuarantorStatus(models.TextChoices):
    PENDING = "PENDING", "Pending"
    CONSENTED = "CONSENTED", "Consented"
    DECLINED = "DECLINED", "Declined"
    RELEASED = "RELEASED", "Released"


class LoanGuarantor(models.Model):
    """
    One guarantor's pledge against one specific loan - amount, not just a
    relationship. CONSENTED is the only status that locks the guarantor's
    deposits (loans/services.py:locked_pledge_total); PENDING doesn't lock
    anything since the guarantor hasn't agreed to anything yet ("Pledges
    need explicit consent" - CLAUDE.md). If the loan is rejected, any
    CONSENTED pledges on it are released automatically - see
    loans/services.py:decide_loan.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    loan = models.ForeignKey(Loan, on_delete=models.CASCADE, related_name="guarantors")
    guarantor = models.ForeignKey("members.Member", on_delete=models.PROTECT, related_name="loan_guarantees")

    pledged_amount = models.DecimalField(max_digits=18, decimal_places=2)
    status = models.CharField(max_length=20, choices=LoanGuarantorStatus.choices, default=LoanGuarantorStatus.PENDING)

    requested_at = models.DateTimeField(auto_now_add=True)
    responded_at = models.DateTimeField(null=True, blank=True)
    released_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ("loan", "guarantor")

    def __str__(self):
        return f"{self.guarantor} pledges {self.pledged_amount} for {self.loan} ({self.status})"
