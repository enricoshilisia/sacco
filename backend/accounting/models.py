import uuid

from django.conf import settings
from django.db import models


class AccountType(models.TextChoices):
    ASSET = "ASSET", "Asset"
    LIABILITY = "LIABILITY", "Liability"
    EQUITY = "EQUITY", "Equity"
    INCOME = "INCOME", "Income"
    EXPENSE = "EXPENSE", "Expense"


# Which side of a debit/credit pair increases an account's balance.
# Assets and expenses grow on the debit side; liabilities, equity, and
# income grow on the credit side. Needed to turn a raw sum(debits)/
# sum(credits) into a signed balance that means what a bookkeeper expects.
DEBIT_NORMAL_TYPES = {AccountType.ASSET, AccountType.EXPENSE}


class Account(models.Model):
    """
    One node in the chart of accounts. Balances are never stored here -
    they're always the sum of this account's JournalLines (CLAUDE.md rule:
    "A balance is the sum of its journal lines"). See `balance()`.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    code = models.CharField(max_length=20, unique=True)
    name = models.CharField(max_length=255)
    account_type = models.CharField(max_length=20, choices=AccountType.choices)
    is_control_account = models.BooleanField(
        default=False,
        help_text="A control account's balance must equal the sum of its member sub-ledger balances.",
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["code"]

    def __str__(self):
        return f"{self.code} - {self.name}"

    def balance(self, *, member=None, as_of=None):
        """
        Signed balance in this account's normal-balance direction. Pass
        `member` to get one member's slice of a control account (for
        reconciling a member statement against the control total).
        """
        qs = self.lines.all()
        if member is not None:
            qs = qs.filter(member=member)
        if as_of is not None:
            qs = qs.filter(journal_entry__entry_date__lte=as_of)

        totals = qs.aggregate(
            total_debit=models.Sum("debit"),
            total_credit=models.Sum("credit"),
        )
        debit = totals["total_debit"] or 0
        credit = totals["total_credit"] or 0

        if self.account_type in DEBIT_NORMAL_TYPES:
            return debit - credit
        return credit - debit


class JournalSequence(models.Model):
    """Singleton counter for JournalEntry.reference (JE-000001, ...). See
    accounting/services.py:post_journal_entry for the atomic claim pattern -
    same approach as members.generate_member_number()."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    next_number = models.PositiveIntegerField(default=1)

    @classmethod
    def get_solo(cls):
        obj = cls.objects.first()
        if obj is None:
            obj = cls.objects.create()
        return obj


class JournalEntry(models.Model):
    """
    Append-only. No update/delete path is exposed anywhere in the app -
    corrections are reversing entries (accounting/services.py:reverse_journal_entry),
    never edits. This is an audit requirement, not a preference (CLAUDE.md).
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reference = models.CharField(max_length=30, unique=True)
    description = models.CharField(max_length=255)
    entry_date = models.DateField()

    reverses = models.OneToOneField(
        "self", null=True, blank=True, on_delete=models.PROTECT, related_name="reversed_by"
    )

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-entry_date", "-created_at"]
        verbose_name_plural = "Journal entries"

    def __str__(self):
        return f"{self.reference} - {self.description}"


class JournalLine(models.Model):
    """One debit or credit leg of a JournalEntry. Exactly one of debit/credit is non-zero."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    journal_entry = models.ForeignKey(JournalEntry, on_delete=models.CASCADE, related_name="lines")
    account = models.ForeignKey(Account, on_delete=models.PROTECT, related_name="lines")

    debit = models.DecimalField(max_digits=18, decimal_places=2, default=0)
    credit = models.DecimalField(max_digits=18, decimal_places=2, default=0)

    # Set when this line belongs to an individual member's sub-ledger
    # within a control account (e.g. one member's savings deposit line
    # within the shared "Member Savings Control" account).
    member = models.ForeignKey(
        "members.Member", null=True, blank=True, on_delete=models.PROTECT, related_name="journal_lines"
    )
    description = models.CharField(max_length=255, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["account", "member"]),
        ]

    def __str__(self):
        amount = self.debit or self.credit
        side = "Dr" if self.debit else "Cr"
        return f"{side} {self.account.code} {amount}"
