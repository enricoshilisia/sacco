import uuid

from django.conf import settings
from django.db import models


class DistributionKind(models.TextChoices):
    DIVIDEND = "DIVIDEND", "Dividend (on share capital)"
    INTEREST = "INTEREST", "Interest/rebate (on savings deposits)"


class DistributionRunStatus(models.TextChoices):
    PENDING_APPROVAL = "PENDING_APPROVAL", "Pending approval"
    APPROVED = "APPROVED", "Approved - posted to ledger"
    REJECTED = "REJECTED", "Rejected"


class DistributionRun(models.Model):
    """
    One declared distribution event - a dividend run against share capital
    (kind=DIVIDEND, savings_product=None) or an interest/rebate run against
    one savings product (kind=INTEREST). PENDING_APPROVAL means entries are
    computed but NOT posted to the ledger - see distributions/services.py:
    propose_dividend_run / propose_interest_run. APPROVED means every entry
    has been posted inside one all-or-nothing transaction - see
    approve_distribution_run - and is then immutable; corrections are
    reversing entries against individual DistributionEntry.journal_entry
    rows, never edits here (CLAUDE.md: journal is append-only).

    Maker-checker by design: distributions.run_dividend/run_interest (the
    "maker", proposes) is a distinct permission from distributions.
    approve_distribution (the "checker", posts to the ledger) - same
    separation of duties as loans.appraise vs loans.approve/reject.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    kind = models.CharField(max_length=20, choices=DistributionKind.choices)

    savings_product = models.ForeignKey(
        "savings.SavingsProduct",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="distribution_runs",
        help_text="Required for an INTEREST run (rate applies to this product's accounts). Always null for DIVIDEND.",
    )

    period_start = models.DateField()
    period_end = models.DateField(
        help_text="MVP simplification: the declared rate is applied directly to each "
        "member's/account's balance AS OF this date - no average-daily-balance "
        "calculation, no prorating by period length. Flagged here the same way "
        "WHT rates are flagged for a tax adviser to confirm."
    )

    rate = models.DecimalField(
        max_digits=6,
        decimal_places=4,
        help_text="e.g. 0.0500 = 5%. Snapshotted at proposal time (board-declared for "
        "dividends, defaults to the product's own interest_rate for interest runs) so "
        "a later rate change never reprices an already-proposed/approved run.",
    )

    wht_rate = models.DecimalField(
        max_digits=5,
        decimal_places=4,
        default=0,
        help_text="Snapshotted from TenantConfig.wht_dividends_rate / wht_interest_rate at "
        "proposal time - never re-read at approval time.",
    )
    wht_rates_confirmed_by_tax_adviser = models.BooleanField(
        default=False,
        help_text="Snapshot of TenantConfig.wht_rates_confirmed_by_tax_adviser at proposal "
        "time - flags this specific run for tax-adviser review, same posture as the config field.",
    )

    status = models.CharField(
        max_length=20, choices=DistributionRunStatus.choices, default=DistributionRunStatus.PENDING_APPROVAL
    )
    description = models.CharField(max_length=255, blank=True)

    proposed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    proposed_at = models.DateTimeField(auto_now_add=True)

    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    approved_at = models.DateTimeField(null=True, blank=True)

    rejected_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    rejected_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ["-proposed_at"]

    def __str__(self):
        return f"{self.get_kind_display()} run {self.period_start}..{self.period_end} ({self.status})"


class DistributionEntryStatus(models.TextChoices):
    PROPOSED = "PROPOSED", "Proposed"
    POSTED = "POSTED", "Posted"
    PAID = "PAID", "Paid"


class DistributionEntry(models.Model):
    """
    One member's line within a DistributionRun. gross/wht/net_amount are
    computed once at proposal time (rate x basis_balance, then
    TenantConfig's WHT rate snapshotted on the run) and never recalculated -
    a later TenantConfig change must not reprice an already-declared entry.
    journal_entry is null until the run is approved (see
    approve_distribution_run) - mirrors ShareContribution/SavingsTransaction/
    LoanRepayment's "one money record = one JournalEntry" shape exactly,
    just posted in a batch rather than one-by-one at creation time.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    run = models.ForeignKey(DistributionRun, on_delete=models.PROTECT, related_name="entries")
    member = models.ForeignKey("members.Member", on_delete=models.PROTECT, related_name="distribution_entries")

    savings_account = models.ForeignKey(
        "savings.SavingsAccount",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="distribution_entries",
        help_text="Set for INTEREST entries - the specific SavingsAccount the balance was computed against.",
    )

    basis_balance = models.DecimalField(
        max_digits=18,
        decimal_places=2,
        help_text="Member's share-capital or savings-account balance as of period_end that the rate was applied to.",
    )
    gross_amount = models.DecimalField(max_digits=18, decimal_places=2)
    wht_amount = models.DecimalField(max_digits=18, decimal_places=2, default=0)
    net_amount = models.DecimalField(max_digits=18, decimal_places=2)

    status = models.CharField(
        max_length=20, choices=DistributionEntryStatus.choices, default=DistributionEntryStatus.PROPOSED
    )

    journal_entry = models.OneToOneField(
        "accounting.JournalEntry", null=True, blank=True, on_delete=models.PROTECT, related_name="distribution_entry"
    )

    class Meta:
        unique_together = ("run", "member")
        ordering = ["run", "member"]

    def __str__(self):
        return f"{self.member} - {self.net_amount} ({self.run})"


class DistributionPayoutStatus(models.TextChoices):
    PENDING = "PENDING", "Pending"
    SUCCESS = "SUCCESS", "Success"
    FAILED = "FAILED", "Failed"


class DistributionPayout(models.Model):
    """
    One mobile-money payout attempt for one DistributionEntry's net_amount -
    field-for-field mirror of loans.LoanDisbursement (same idempotency-key +
    provider-callback shape, same PENDING/SUCCESS/FAILED terminal states). A
    FK, not OneToOne, to DistributionEntry: a failed attempt can be retried
    under a fresh idempotency_key while the failed row stays for audit,
    exactly like a loan can have more than one LoanDisbursement row. Only
    ever created by distributions/services.py:initiate_distribution_payout;
    only ever resolved by handle_distribution_payout_callback, idempotent
    against a redelivered callback (CLAUDE.md rule 4).
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    entry = models.ForeignKey(DistributionEntry, on_delete=models.PROTECT, related_name="payouts")
    idempotency_key = models.CharField(max_length=64, unique=True)

    provider = models.CharField(max_length=30)
    phone_number = models.CharField(max_length=20)
    amount = models.DecimalField(max_digits=18, decimal_places=2)
    status = models.CharField(
        max_length=10, choices=DistributionPayoutStatus.choices, default=DistributionPayoutStatus.PENDING
    )

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
        return f"{self.provider} payout {self.amount} for {self.entry} ({self.status})"
