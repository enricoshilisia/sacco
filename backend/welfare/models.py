"""
Welfare: members support each other through emergencies (sickness, death
of a member or a family member) according to the SACCO's constitution.

How the money moves (every step posts a balanced journal entry - see
welfare.services for the exact lines):

- Each member pays a yearly welfare contribution (WelfareSettings.
  yearly_contribution, e.g. 1,000) into their own welfare balance
  (ledger 2400, member-tagged).
- The welfare manager opens a WelfareCase, choosing a WelfareCaseType
  from the constitution's rules; the type fixes how much EACH member
  contributes. A second person approves it (maker-checker).
- On approval every active member is levied that amount: taken from
  their welfare balance first, and whatever the balance can't cover
  becomes a due they owe (ledger 1300, member-tagged). Both credit the
  Welfare Fund (2500).
- A member's later welfare payment clears their oldest dues first, and
  only the remainder tops up their balance.
- The affected member receives what the case actually collected; the
  payout is made outside the system (cash/bank) and recorded here.
- At year end, unused balances go to the Welfare Fund.
"""

import uuid
from decimal import Decimal

from django.conf import settings
from django.db import models


class WelfareSettings(models.Model):
    """Per-SACCO welfare configuration (CLAUDE.md rule 6: amounts are
    config, never hardcoded). Singleton per tenant schema."""

    yearly_contribution = models.DecimalField(
        max_digits=18, decimal_places=2, default=Decimal("1000.00"),
        help_text="Expected yearly welfare contribution per member.",
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name_plural = "Welfare settings"

    @classmethod
    def get_solo(cls) -> "WelfareSettings":
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj


class WelfareCaseType(models.Model):
    """One constitution rule, e.g. "Member hospitalised - 200 per member"
    or "Death of member's parent - 300 per member"."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=150, unique=True)
    description = models.TextField(blank=True, help_text="e.g. the constitution clause this implements.")
    contribution_per_member = models.DecimalField(max_digits=18, decimal_places=2)
    beneficiary_contributes = models.BooleanField(
        default=False, help_text="Whether the affected member is also levied for their own case."
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class WelfareCaseStatus(models.TextChoices):
    PENDING_APPROVAL = "PENDING_APPROVAL", "Pending approval"
    APPROVED = "APPROVED", "Approved"
    REJECTED = "REJECTED", "Rejected"
    CLOSED = "CLOSED", "Closed"


class WelfareCase(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    case_type = models.ForeignKey(WelfareCaseType, on_delete=models.PROTECT, related_name="cases")
    beneficiary = models.ForeignKey("members.Member", on_delete=models.PROTECT, related_name="welfare_cases")
    affected_person = models.CharField(
        max_length=255, blank=True, help_text="Who is sick/deceased if not the member, e.g. 'Mary W. (daughter)'."
    )
    description = models.TextField(blank=True)
    # Snapshotted from the case type when the case is opened, so a later
    # change to the rule never changes what an existing case levies.
    contribution_per_member = models.DecimalField(max_digits=18, decimal_places=2)
    beneficiary_contributes = models.BooleanField(default=False)

    status = models.CharField(
        max_length=20, choices=WelfareCaseStatus.choices, default=WelfareCaseStatus.PENDING_APPROVAL
    )
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+")
    created_at = models.DateTimeField(auto_now_add=True)
    decided_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    decided_at = models.DateTimeField(null=True, blank=True)
    decision_notes = models.TextField(blank=True)
    levied_at = models.DateTimeField(
        null=True, blank=True, help_text="When the levy run over all members finished."
    )
    closed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.case_type.name} - {self.beneficiary}"


class WelfareContribution(models.Model):
    """One member's share of one case. `from_balance` was taken from their
    welfare balance at levy time; `owed` is the shortfall they must pay,
    of which `paid` has been settled so far."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    case = models.ForeignKey(WelfareCase, on_delete=models.PROTECT, related_name="contributions")
    member = models.ForeignKey("members.Member", on_delete=models.PROTECT, related_name="welfare_contributions")
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    from_balance = models.DecimalField(max_digits=18, decimal_places=2, default=Decimal("0"))
    owed = models.DecimalField(max_digits=18, decimal_places=2, default=Decimal("0"))
    paid = models.DecimalField(max_digits=18, decimal_places=2, default=Decimal("0"))
    journal_entry = models.OneToOneField(
        "accounting.JournalEntry", on_delete=models.PROTECT, related_name="welfare_contribution"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        # The levy run's idempotency guarantee: re-running it (a Celery
        # retry) can never levy the same member twice for one case.
        constraints = [models.UniqueConstraint(fields=["case", "member"], name="welfare_one_levy_per_member")]
        ordering = ["created_at"]

    @property
    def outstanding(self) -> Decimal:
        return self.owed - self.paid


class WelfarePaymentMethod(models.TextChoices):
    MOBILE_MONEY = "MOBILE_MONEY", "Mobile money"
    CASH = "CASH", "Cash"
    BANK = "BANK", "Bank"


class WelfarePayment(models.Model):
    """Money a member paid in, split into what cleared their dues and what
    topped up their welfare balance."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey("members.Member", on_delete=models.PROTECT, related_name="welfare_payments")
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    applied_to_dues = models.DecimalField(max_digits=18, decimal_places=2, default=Decimal("0"))
    to_balance = models.DecimalField(max_digits=18, decimal_places=2, default=Decimal("0"))
    method = models.CharField(max_length=20, choices=WelfarePaymentMethod.choices)
    reference = models.CharField(max_length=100, blank=True)
    transaction_date = models.DateField()
    journal_entry = models.OneToOneField(
        "accounting.JournalEntry", on_delete=models.PROTECT, related_name="welfare_payment"
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]


class WelfareDueSettlement(models.Model):
    """Which of a member's dues a payment cleared - the audit trail behind
    WelfareContribution.paid, and what lets each case know how much it has
    actually collected."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    payment = models.ForeignKey(WelfarePayment, on_delete=models.PROTECT, related_name="settlements")
    contribution = models.ForeignKey(WelfareContribution, on_delete=models.PROTECT, related_name="settlements")
    amount = models.DecimalField(max_digits=18, decimal_places=2)


class WelfarePayout(models.Model):
    """A benefit handed to the affected member outside the system (cash or
    bank) and recorded here. Can be several partial payouts as dues come in."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    case = models.ForeignKey(WelfareCase, on_delete=models.PROTECT, related_name="payouts")
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    method = models.CharField(max_length=20, choices=WelfarePaymentMethod.choices)
    reference = models.CharField(max_length=100, blank=True)
    paid_to = models.CharField(max_length=255, blank=True)
    paid_on = models.DateField()
    notes = models.TextField(blank=True)
    journal_entry = models.OneToOneField(
        "accounting.JournalEntry", on_delete=models.PROTECT, related_name="welfare_payout"
    )
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]


class WelfareYearClose(models.Model):
    """Year-end: unused welfare balances move to the Welfare Fund."""

    RUNNING = "RUNNING"
    DONE = "DONE"
    STATUS_CHOICES = [(RUNNING, "Running"), (DONE, "Done")]

    year = models.PositiveIntegerField(unique=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default=RUNNING)
    closed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    started_at = models.DateTimeField(auto_now_add=True)
    finished_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-year"]


class WelfareYearSweep(models.Model):
    year_close = models.ForeignKey(WelfareYearClose, on_delete=models.PROTECT, related_name="sweeps")
    member = models.ForeignKey("members.Member", on_delete=models.PROTECT, related_name="welfare_sweeps")
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    journal_entry = models.OneToOneField(
        "accounting.JournalEntry", on_delete=models.PROTECT, related_name="welfare_sweep"
    )

    class Meta:
        constraints = [models.UniqueConstraint(fields=["year_close", "member"], name="welfare_one_sweep_per_member")]
