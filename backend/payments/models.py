import uuid

from django.conf import settings
from django.db import models


class CollectionStatus(models.TextChoices):
    PENDING = "PENDING", "Pending"
    SUCCESS = "SUCCESS", "Success"
    FAILED = "FAILED", "Failed"
    CANCELLED = "CANCELLED", "Cancelled"


class CollectionPurpose(models.TextChoices):
    SAVINGS_DEPOSIT = "SAVINGS_DEPOSIT", "Savings deposit"
    SHARE_CONTRIBUTION = "SHARE_CONTRIBUTION", "Share contribution"


class PaymentCollection(models.Model):
    """
    One mobile-money collection attempt (M-Pesa STK push / Selcom
    checkout) that, on success, becomes a savings deposit or share
    contribution posted to the ledger (purpose decides which - CLAUDE.md:
    "share capital != deposits", never conflated even though they share
    this same collection mechanism). idempotency_key is the CLAUDE.md-
    mandated guard (rule 4) against a retried provider callback double-
    posting: the callback handler looks a collection up by
    provider_reference and is a no-op once the row is already in a
    terminal state (SUCCESS/FAILED/CANCELLED) - see
    payments/services.py:handle_collection_callback.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    idempotency_key = models.CharField(max_length=64, unique=True)

    member = models.ForeignKey("members.Member", on_delete=models.PROTECT, related_name="payment_collections")
    purpose = models.CharField(
        max_length=20, choices=CollectionPurpose.choices, default=CollectionPurpose.SAVINGS_DEPOSIT
    )
    # Only set (and only meaningful) for SAVINGS_DEPOSIT - a share
    # contribution has no savings product/account of its own.
    savings_account = models.ForeignKey(
        "savings.SavingsAccount", null=True, blank=True, on_delete=models.PROTECT, related_name="payment_collections"
    )
    savings_transaction = models.OneToOneField(
        "savings.SavingsTransaction",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="payment_collection",
    )
    share_contribution = models.OneToOneField(
        "savings.ShareContribution",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="payment_collection",
    )

    provider = models.CharField(max_length=30)
    phone_number = models.CharField(max_length=20)
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    status = models.CharField(max_length=10, choices=CollectionStatus.choices, default=CollectionStatus.PENDING)

    provider_reference = models.CharField(
        max_length=100,
        blank=True,
        db_index=True,
        help_text="e.g. Daraja CheckoutRequestID / Selcom order id - what an inbound callback correlates against.",
    )
    provider_receipt = models.CharField(max_length=100, blank=True, help_text="e.g. M-Pesa receipt number")
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
        return f"{self.provider} collection {self.amount} for {self.member} ({self.status})"
