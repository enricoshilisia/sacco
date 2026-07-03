# Default savings products from BUILD_PLAN.md's explicit list. Rates/minimums
# are left at 0 - a placeholder, not an invented figure - same pattern as
# configuration.TenantConfig's WHT-rate placeholders: a SACCO configures the
# real numbers later, we don't guess at them.

from django.db import migrations

PRODUCTS = [
    ("mandatory-monthly", "Mandatory Monthly Savings", "MANDATORY_MONTHLY"),
    ("voluntary", "Voluntary Savings", "VOLUNTARY"),
    ("fixed-term", "Fixed/Term Savings", "FIXED_TERM"),
    ("goal", "Goal Savings", "GOAL"),
    ("junior", "Junior Savings", "JUNIOR"),
]


def seed(apps, schema_editor):
    SavingsProduct = apps.get_model("savings", "SavingsProduct")
    for code, name, product_type in PRODUCTS:
        SavingsProduct.objects.get_or_create(
            code=code,
            defaults={"name": name, "product_type": product_type},
        )


def unseed(apps, schema_editor):
    SavingsProduct = apps.get_model("savings", "SavingsProduct")
    SavingsProduct.objects.filter(code__in=[p[0] for p in PRODUCTS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("savings", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
