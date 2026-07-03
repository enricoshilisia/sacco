from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Any

from django.db import transaction

from .models import Account, JournalEntry, JournalLine, JournalSequence


@dataclass
class LineInput:
    account: Account
    debit: Decimal = Decimal("0")
    credit: Decimal = Decimal("0")
    member: Any = None
    description: str = ""


class UnbalancedJournalEntry(ValueError):
    pass


def _next_reference() -> str:
    with transaction.atomic():
        seq = JournalSequence.objects.select_for_update().first()
        if seq is None:
            seq = JournalSequence.objects.create()
        number = seq.next_number
        seq.next_number = number + 1
        seq.save(update_fields=["next_number"])
    return f"JE-{number:06d}"


def post_journal_entry(
    *,
    description: str,
    entry_date: date,
    lines: list[LineInput],
    created_by=None,
) -> JournalEntry:
    """
    The only sanctioned way to write to the ledger (CLAUDE.md: "never write
    to an account balance directly"). Validates the entry balances before
    anything is written, then creates the JournalEntry and all JournalLines
    atomically. Journal entries are immutable once posted - there is no
    update/delete path anywhere in this app; see reverse_journal_entry for
    corrections.
    """
    if len(lines) < 2:
        raise UnbalancedJournalEntry("A journal entry needs at least two lines.")

    total_debit = Decimal("0")
    total_credit = Decimal("0")
    for line in lines:
        if line.debit < 0 or line.credit < 0:
            raise UnbalancedJournalEntry("Debit/credit amounts cannot be negative.")
        if bool(line.debit) == bool(line.credit):
            raise UnbalancedJournalEntry(
                "Each line must have exactly one of debit or credit set, not both or neither."
            )
        total_debit += line.debit
        total_credit += line.credit

    if total_debit != total_credit:
        raise UnbalancedJournalEntry(
            f"Entry does not balance: total debits {total_debit} != total credits {total_credit}"
        )

    with transaction.atomic():
        entry = JournalEntry.objects.create(
            reference=_next_reference(),
            description=description,
            entry_date=entry_date,
            created_by=created_by,
        )
        JournalLine.objects.bulk_create(
            JournalLine(
                journal_entry=entry,
                account=line.account,
                debit=line.debit,
                credit=line.credit,
                member=line.member,
                description=line.description,
            )
            for line in lines
        )
    return entry


def reverse_journal_entry(entry: JournalEntry, *, reason: str, created_by=None) -> JournalEntry:
    """
    Corrections are reversing entries, never edits to what was posted
    (CLAUDE.md: journal is append-only). Swaps debit/credit on every line
    of the original and posts that as a brand new entry.
    """
    if hasattr(entry, "reversed_by"):
        raise UnbalancedJournalEntry(f"{entry.reference} has already been reversed.")

    lines = [
        LineInput(
            account=line.account,
            debit=line.credit,
            credit=line.debit,
            member=line.member,
            description=f"Reversal: {line.description}" if line.description else "Reversal",
        )
        for line in entry.lines.all()
    ]

    with transaction.atomic():
        reversal = post_journal_entry(
            description=f"Reversal of {entry.reference}: {reason}",
            entry_date=date.today(),
            lines=lines,
            created_by=created_by,
        )
        reversal.reverses = entry
        reversal.save(update_fields=["reverses"])
    return reversal


def get_trial_balance() -> list[dict]:
    """Every active account's signed balance. Sum of all balances should
    always be zero by construction (every entry balances), but we don't
    assert that here - see accounting.views.TrialBalanceView, which
    surfaces it as an explicit reconciliation check rather than a silent
    assumption."""
    rows = []
    for account in Account.objects.filter(is_active=True):
        rows.append(
            {
                "account": account,
                "balance": account.balance(),
            }
        )
    return rows
