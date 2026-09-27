# Fines are charged first and paid later (fines/models.py): 1400 is what each
# member owes (member-tagged), 5200 is the SACCO's income from fines.

from django.db import migrations

ACCOUNTS = [
    ("1400", "Fines Receivable", "ASSET", True),
    ("5200", "Fine Income", "INCOME", False),
]


def seed(apps, schema_editor):
    Account = apps.get_model("accounting", "Account")
    for code, name, account_type, is_control in ACCOUNTS:
        Account.objects.get_or_create(
            code=code, defaults={"name": name, "account_type": account_type, "is_control_account": is_control}
        )


def unseed(apps, schema_editor):
    Account = apps.get_model("accounting", "Account")
    Account.objects.filter(code__in=[a[0] for a in ACCOUNTS]).delete()


class Migration(migrations.Migration):

    dependencies = [("accounting", "0006_seed_registration_fee_account")]

    operations = [migrations.RunPython(seed, unseed)]
