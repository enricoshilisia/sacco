# Minimal chart of accounts needed for Phase 2 (share contributions +
# savings deposits/withdrawals). Later phases add their own accounts via
# their own seed migrations (e.g. Loans Receivable in Phase 4, Interest
# Income in Phase 5) rather than everything being front-loaded here.

from django.db import migrations

ACCOUNTS = [
    ("1000", "Cash and Bank", "ASSET", False),
    ("2000", "Member Savings Control", "LIABILITY", True),
    ("3000", "Member Share Capital", "EQUITY", True),
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
        ("accounting", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
