# Phase 4 slice 2: loans need somewhere to post to. Loans Receivable is a
# member-tagged control account (mirrors 2000/3000) so a member's own
# outstanding balance can be reconciled the same way savings/shares already
# are. Interest Income is the SACCO's own earnings on loan interest - not to
# be confused with whatever Phase 5 (dividends/interest paid TO members on
# their deposits) ends up calling its own account; that's an expense/
# distribution, this is income, and the two must never share a code.

from django.db import migrations

ACCOUNTS = [
    ("4000", "Loans Receivable", "ASSET", True),
    ("5000", "Interest Income", "INCOME", False),
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
        ("accounting", "0002_seed_chart_of_accounts"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
