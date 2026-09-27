"""
Fines (discipline): a member breaks a rule in the constitution - misses a
meeting without apology, arrives late - and owes a fine. A fine is charged
first (the member owes it) and paid later, which is why it goes through the
ledger twice: charging it raises a receivable against SACCO income, and
paying it clears the receivable.
"""

import uuid
from decimal import Decimal

from django.conf import settings
from django.db import models


class OffenceType(models.Model):
    """A rule and what breaking it costs - per SACCO config, never hardcoded
    (CLAUDE.md rule 6). Changing the amount never changes fines already
    charged: each fine keeps the amount it was charged at."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=120, unique=True)
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    description = models.TextField(blank=True)
    # Marks the two offences the meeting register can propose automatically.
    from_attendance = models.CharField(
        max_length=10, blank=True,
        choices=[("ABSENT", "Absent without apology"), ("LATE", "Late")],
        help_text="If set, the register can propose this fine for that mark.",
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return f"{self.name} ({self.amount})"


class FineStatus(models.TextChoices):
    OUTSTANDING = "OUTSTANDING", "Owed"
    PAID = "PAID", "Paid"
    WAIVED = "WAIVED", "Waived"


class Fine(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey("members.Member", on_delete=models.PROTECT, related_name="fines")
    offence_type = models.ForeignKey(OffenceType, on_delete=models.PROTECT, related_name="fines")
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    paid = models.DecimalField(max_digits=18, decimal_places=2, default=0)
    status = models.CharField(max_length=12, choices=FineStatus.choices, default=FineStatus.OUTSTANDING)

    incurred_on = models.DateField(help_text="The day the rule was broken (e.g. the meeting date).")
    meeting = models.ForeignKey(
        "governance.Meeting", null=True, blank=True, on_delete=models.SET_NULL, related_name="fines"
    )
    notes = models.CharField(max_length=255, blank=True)

    journal_entry = models.OneToOneField("accounting.JournalEntry", on_delete=models.PROTECT, related_name="+")
    charged_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    charged_at = models.DateTimeField(auto_now_add=True)

    waived_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    waived_at = models.DateTimeField(null=True, blank=True)
    waived_reason = models.CharField(max_length=255, blank=True)
    waiver_entry = models.OneToOneField(
        "accounting.JournalEntry", null=True, blank=True, on_delete=models.PROTECT, related_name="+"
    )

    class Meta:
        ordering = ["incurred_on", "charged_at"]
        indexes = [models.Index(fields=["member", "status"])]

    def __str__(self):
        return f"{self.member.member_number} {self.offence_type.name} {self.amount}"

    @property
    def outstanding(self) -> Decimal:
        if self.status == FineStatus.WAIVED:
            return Decimal("0")
        return self.amount - self.paid


class FinePaymentMethod(models.TextChoices):
    CASH = "CASH", "Cash"
    BANK = "BANK", "Bank"
    MOBILE_MONEY = "MOBILE_MONEY", "Mobile money"


class FinePayment(models.Model):
    """Money received against a member's fines - oldest fine first.
    idempotency_key stops a retried request or provider callback posting it
    twice (CLAUDE.md rule 4)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey("members.Member", on_delete=models.PROTECT, related_name="fine_payments")
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    method = models.CharField(max_length=15, choices=FinePaymentMethod.choices)
    reference = models.CharField(max_length=100, blank=True)
    paid_on = models.DateField()
    idempotency_key = models.CharField(max_length=64, unique=True)
    journal_entry = models.OneToOneField("accounting.JournalEntry", on_delete=models.PROTECT, related_name="+")
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-paid_on", "-created_at"]


class FineSettlement(models.Model):
    """How much of one payment went to one fine."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    payment = models.ForeignKey(FinePayment, on_delete=models.CASCADE, related_name="settlements")
    fine = models.ForeignKey(Fine, on_delete=models.PROTECT, related_name="settlements")
    amount = models.DecimalField(max_digits=18, decimal_places=2)

    class Meta:
        ordering = ["id"]
