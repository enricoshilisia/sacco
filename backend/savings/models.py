import uuid

from django.conf import settings
from django.db import models


class SavingsProductType(models.TextChoices):
    MANDATORY_MONTHLY = "MANDATORY_MONTHLY", "Mandatory monthly"
    VOLUNTARY = "VOLUNTARY", "Voluntary"
    FIXED_TERM = "FIXED_TERM", "Fixed/term"
    GOAL = "GOAL", "Goal"
    JUNIOR = "JUNIOR", "Junior"


class SavingsProduct(models.Model):
    """
    A savings product definition - withdrawable, interest-bearing, and the
    basis for the loan multiplier (Phase 4). Deliberately a separate
    concept from share capital (see ShareAccount): CLAUDE.md calls
    conflating the two "the single most common way naive SACCO systems
    become incorrect."
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100)
    code = models.SlugField(max_length=30, unique=True)
    product_type = models.CharField(max_length=20, choices=SavingsProductType.choices)
    interest_rate = models.DecimalField(
        max_digits=6, decimal_places=4, default=0, help_text="Annual rate, e.g. 0.0500 = 5%"
    )
    minimum_balance = models.DecimalField(max_digits=18, decimal_places=2, default=0)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class ShareAccount(models.Model):
    """
    One per member. Share capital is non-withdrawable (except on member
    exit, not yet built - Phase 4/exit-process territory), earns dividends
    declared at AGM (Phase 5), and is NOT loan security - deposits are
    (see SavingsAccount). Balance is never stored here; it's the sum of
    this member's lines on the Member Share Capital control account.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.OneToOneField("members.Member", on_delete=models.PROTECT, related_name="share_account")
    opened_at = models.DateField(auto_now_add=True)

    def __str__(self):
        return f"Share account for {self.member}"


class SavingsAccount(models.Model):
    """One per member per product - a member can hold several (e.g. mandatory + a goal account)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey("members.Member", on_delete=models.PROTECT, related_name="savings_accounts")
    product = models.ForeignKey(SavingsProduct, on_delete=models.PROTECT, related_name="accounts")
    account_number = models.CharField(max_length=30, unique=True)
    opened_at = models.DateField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        unique_together = ("member", "product")

    def __str__(self):
        return f"{self.account_number} ({self.product.name}) - {self.member}"


class ShareContribution(models.Model):
    """A share-capital contribution. Every row here has exactly one balanced
    JournalEntry behind it (Dr Cash, Cr Member Share Capital) - see
    savings/services.py:contribute_shares."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    share_account = models.ForeignKey(ShareAccount, on_delete=models.PROTECT, related_name="contributions")
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    transaction_date = models.DateField()
    journal_entry = models.OneToOneField(
        "accounting.JournalEntry", on_delete=models.PROTECT, related_name="share_contribution"
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.amount} shares for {self.share_account.member}"


class SavingsTransactionType(models.TextChoices):
    DEPOSIT = "DEPOSIT", "Deposit"
    WITHDRAWAL = "WITHDRAWAL", "Withdrawal"


class SavingsTransaction(models.Model):
    """A deposit or withdrawal against a SavingsAccount. Every row here has
    exactly one balanced JournalEntry behind it - see
    savings/services.py:deposit_savings / withdraw_savings."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    savings_account = models.ForeignKey(SavingsAccount, on_delete=models.PROTECT, related_name="transactions")
    transaction_type = models.CharField(max_length=20, choices=SavingsTransactionType.choices)
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    transaction_date = models.DateField()
    journal_entry = models.OneToOneField(
        "accounting.JournalEntry", on_delete=models.PROTECT, related_name="savings_transaction"
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.transaction_type} {self.amount} on {self.savings_account}"
