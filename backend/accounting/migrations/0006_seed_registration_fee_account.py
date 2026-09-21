# New members pay a one-off, non-refundable registration fee. It is SACCO
# income (members.admission.record_registration_fee), not member money.

from django.db import migrations

ACCOUNTS = [
    ("5100", "Registration Fee Income", "INCOME", False),
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
        ("accounting", "0005_seed_welfare_accounts"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
