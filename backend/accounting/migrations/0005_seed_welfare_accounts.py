# Welfare (see welfare/models.py for the full money flow). 1300 and 2400
# are member-tagged control accounts: 1300 is what each member owes for
# welfare cases their balance didn't cover; 2400 is each member's unused
# yearly welfare contributions (money the SACCO holds for them). 2500 is
# the pooled Welfare Fund that levies credit and payouts debit - not
# sub-ledgered per member.

from django.db import migrations

ACCOUNTS = [
    ("1300", "Welfare Dues Receivable", "ASSET", True),
    ("2400", "Welfare Contributions Prepaid", "LIABILITY", True),
    ("2500", "Welfare Fund", "LIABILITY", False),
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
        ("accounting", "0004_seed_distribution_accounts"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
