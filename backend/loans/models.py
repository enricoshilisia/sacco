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
    # Phase 4 slice 2:
    DISBURSED = "DISBURSED", "Disbursement pending confirmation"
    ACTIVE = "ACTIVE", "Active - being repaid"
    CLOSED = "CLOSED", "Closed - fully repaid"
    DEFAULTED = "DEFAULTED", "Defaulted"


class DisbursementMethod(models.TextChoices):
    SAVINGS_CREDIT = "SAVINGS_CREDIT", "Credited to savings account"
    MOBILE_MONEY = "MOBILE_MONEY", "Mobile money"


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
    # Set by loans.services._attempt_auto_decision when appraised_by/
    # decided_by are None because the rules engine decided this, not a person.
    is_auto_decision = models.BooleanField(default=False)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    disbursed_at = models.DateTimeField(null=True, blank=True)
    disbursement_method = models.CharField(max_length=20, choices=DisbursementMethod.choices, blank=True)

    closed_at = models.DateTimeField(null=True, blank=True)

    defaulted_at = models.DateTimeField(null=True, blank=True)
    default_notes = models.TextField(blank=True)

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


class LoanRepaymentSchedule(models.Model):
    """
    One amortization installment. Generated once, in full, at the moment a
    loan goes ACTIVE (loans/services.py:generate_amortization_schedule) -
    never regenerated or edited afterwards; principal_paid/interest_paid
    are the only fields a repayment ever touches (loans/services.py:
    record_loan_repayment), and even those only move forward, never down.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    loan = models.ForeignKey(Loan, on_delete=models.CASCADE, related_name="schedule")
    installment_number = models.PositiveSmallIntegerField()
    due_date = models.DateField()

    principal_due = models.DecimalField(max_digits=18, decimal_places=2)
    interest_due = models.DecimalField(max_digits=18, decimal_places=2)
    principal_paid = models.DecimalField(max_digits=18, decimal_places=2, default=0)
    interest_paid = models.DecimalField(max_digits=18, decimal_places=2, default=0)

    class Meta:
        unique_together = ("loan", "installment_number")
        ordering = ["loan", "installment_number"]

    @property
    def total_due(self):
        return self.principal_due + self.interest_due

    @property
    def is_paid(self):
        return self.principal_paid >= self.principal_due and self.interest_paid >= self.interest_due

    def __str__(self):
        return f"{self.loan} installment {self.installment_number} due {self.due_date}"


class LoanRepayment(models.Model):
    """A repayment against a loan's schedule. Every row here has exactly one
    balanced JournalEntry behind it - see loans/services.py:record_loan_repayment."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    loan = models.ForeignKey(Loan, on_delete=models.PROTECT, related_name="repayments")
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    transaction_date = models.DateField()
    journal_entry = models.OneToOneField(
        "accounting.JournalEntry", on_delete=models.PROTECT, related_name="loan_repayment"
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    description = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ["-transaction_date", "-created_at"]

    def __str__(self):
        return f"Repayment {self.amount} on {self.loan}"


class DisbursementStatus(models.TextChoices):
    PENDING = "PENDING", "Pending"
    SUCCESS = "SUCCESS", "Success"
    FAILED = "FAILED", "Failed"


class LoanDisbursement(models.Model):
    """
    One mobile-money disbursement attempt (mirrors payments.PaymentCollection,
    same idempotency-key + provider-callback shape, just money moving the
    other direction). Only ever created by
    loans/services.py:initiate_loan_disbursement_mobile_money; only ever
    resolved by loans/services.py:handle_loan_disbursement_callback, which
    is idempotent against a redelivered callback the same way
    payments.services.handle_collection_callback is (CLAUDE.md rule 4).
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    loan = models.ForeignKey(Loan, on_delete=models.PROTECT, related_name="disbursements")
    idempotency_key = models.CharField(max_length=64, unique=True)

    provider = models.CharField(max_length=30)
    phone_number = models.CharField(max_length=20)
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    status = models.CharField(max_length=10, choices=DisbursementStatus.choices, default=DisbursementStatus.PENDING)

    provider_reference = models.CharField(max_length=100, blank=True, db_index=True)
    failure_reason = models.TextField(blank=True)
    raw_callback = models.JSONField(null=True, blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.provider} disbursement {self.amount} for {self.loan} ({self.status})"
