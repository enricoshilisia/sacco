from datetime import date
from decimal import Decimal

from django.db import transaction

from accounting.models import Account
from accounting.services import LineInput, post_journal_entry

from .models import (
    SavingsAccount,
    SavingsTransaction,
    SavingsTransactionType,
    ShareAccount,
    ShareContribution,
)

CASH_ACCOUNT_CODE = "1000"
SAVINGS_CONTROL_ACCOUNT_CODE = "2000"
SHARE_CAPITAL_ACCOUNT_CODE = "3000"


class InsufficientBalance(ValueError):
    pass


def get_or_open_share_account(member) -> ShareAccount:
    account, _ = ShareAccount.objects.get_or_create(member=member)
    return account


def get_or_open_savings_account(member, product) -> SavingsAccount:
    account, created = SavingsAccount.objects.get_or_create(
        member=member,
        product=product,
        defaults={"account_number": f"{member.member_number}-{product.code}"},
    )
    return account


def contribute_shares(*, member, amount: Decimal, transaction_date: date, created_by=None, description: str = "") -> ShareContribution:
    if amount <= 0:
        raise ValueError("Contribution amount must be positive.")

    share_account = get_or_open_share_account(member)
    cash = Account.objects.get(code=CASH_ACCOUNT_CODE)
    share_capital = Account.objects.get(code=SHARE_CAPITAL_ACCOUNT_CODE)

    with transaction.atomic():
        entry = post_journal_entry(
            description=description or f"Share contribution - {member.full_name()}",
            entry_date=transaction_date,
            lines=[
                LineInput(account=cash, debit=amount, description="Share contribution received"),
                LineInput(account=share_capital, credit=amount, member=member, description="Share contribution"),
            ],
            created_by=created_by,
        )
        return ShareContribution.objects.create(
            share_account=share_account,
            amount=amount,
            transaction_date=transaction_date,
            journal_entry=entry,
            created_by=created_by,
        )


def deposit_savings(*, savings_account: SavingsAccount, amount: Decimal, transaction_date: date, created_by=None, description: str = "") -> SavingsTransaction:
    if amount <= 0:
        raise ValueError("Deposit amount must be positive.")

    cash = Account.objects.get(code=CASH_ACCOUNT_CODE)
    savings_control = Account.objects.get(code=SAVINGS_CONTROL_ACCOUNT_CODE)
    member = savings_account.member

    with transaction.atomic():
        entry = post_journal_entry(
            description=description or f"Savings deposit - {member.full_name()}",
            entry_date=transaction_date,
            lines=[
                LineInput(account=cash, debit=amount, description="Savings deposit received"),
                LineInput(account=savings_control, credit=amount, member=member, description="Savings deposit"),
            ],
            created_by=created_by,
        )
        return SavingsTransaction.objects.create(
            savings_account=savings_account,
            transaction_type=SavingsTransactionType.DEPOSIT,
            amount=amount,
            transaction_date=transaction_date,
            journal_entry=entry,
            created_by=created_by,
        )


def withdraw_savings(*, savings_account: SavingsAccount, amount: Decimal, transaction_date: date, created_by=None, description: str = "") -> SavingsTransaction:
    if amount <= 0:
        raise ValueError("Withdrawal amount must be positive.")

    cash = Account.objects.get(code=CASH_ACCOUNT_CODE)
    savings_control = Account.objects.get(code=SAVINGS_CONTROL_ACCOUNT_CODE)
    member = savings_account.member

    with transaction.atomic():
        # Lock the control account row for the duration of this transaction
        # so two concurrent withdrawals against the same member can't both
        # read a pre-withdrawal balance and both succeed. Without this,
        # checking the balance and posting the entry is two separate
        # operations with a race between them.
        savings_control = Account.objects.select_for_update().get(code=SAVINGS_CONTROL_ACCOUNT_CODE)
        current_balance = savings_control.balance(member=member)
        if amount > current_balance:
            raise InsufficientBalance(
                f"Withdrawal of {amount} exceeds available balance of {current_balance}."
            )

        entry = post_journal_entry(
            description=description or f"Savings withdrawal - {member.full_name()}",
            entry_date=transaction_date,
            lines=[
                LineInput(account=savings_control, debit=amount, member=member, description="Savings withdrawal"),
                LineInput(account=cash, credit=amount, description="Savings withdrawal paid out"),
            ],
            created_by=created_by,
        )
        return SavingsTransaction.objects.create(
            savings_account=savings_account,
            transaction_type=SavingsTransactionType.WITHDRAWAL,
            amount=amount,
            transaction_date=transaction_date,
            journal_entry=entry,
            created_by=created_by,
        )
