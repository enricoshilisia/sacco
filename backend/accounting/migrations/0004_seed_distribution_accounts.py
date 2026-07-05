# Phase 5: distributions needs somewhere to post dividend/interest
# declarations and their withholding tax to. 6000/6100 are the SACCO's own
# cost of paying members - deliberately NOT 5000 (Interest Income), which
# is the SACCO's earnings FROM loan interest (see 0003's own warning
# comment - the two must never share a code). 2100/2200 are member-tagged
# control accounts (what's owed to each specific member until a mobile-
# money payout clears them against cash) - same shape as 2000/3000/4000.
# 2300 is deliberately NOT a control account: WHT withheld is owed in
# aggregate to the tax authority, not sub-ledgered per member. Remitting
# it to KRA/TRA is out of scope for this phase - only the liability is
# tracked here, same "flagged for a tax adviser" posture as
# TenantConfig.wht_*_rate.

from django.db import migrations

ACCOUNTS = [
    ("2100", "Dividends Payable", "LIABILITY", True),
    ("2200", "Interest Payable", "LIABILITY", True),
    ("2300", "WHT Payable", "LIABILITY", False),
    ("6000", "Dividend Expense", "EXPENSE", False),
    ("6100", "Interest Expense on Deposits", "EXPENSE", False),
]


def seed(apps, schema_editor):
    Account = apps.get_model("accounting", "Account")
    for code, name, account_type, is_control in ACCOUNTS:
        Account.objects.get_or_create(
            code=code,
            defaults={"name": name, "account_type": account_type, "is_control_account": is_control},
        )


def unseed(apps, schema_editor):
    Account = apps.get_model("accounting", "Account")
    Account.objects.filter(code__in=[a[0] for a in ACCOUNTS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("accounting", "0003_seed_loan_accounts"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
