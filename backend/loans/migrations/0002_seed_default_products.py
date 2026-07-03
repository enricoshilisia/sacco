# Two starter loan products covering both interest methods and both
# guarantor-requirement paths - rates left at 0 as an explicit placeholder,
# not an invented figure (same pattern as savings' 0002 seed migration and
# configuration.TenantConfig's WHT-rate placeholders): a SACCO configures
# the real numbers later, we don't guess at them.

from django.db import migrations

PRODUCTS = [
    {
        "code": "development",
        "name": "Development Loan",
        "interest_method": "REDUCING_BALANCE",
        "interest_rate": 0,
        "min_term_months": 1,
        "max_term_months": 36,
        "requires_guarantors": True,
        "min_guarantors": 2,
    },
    {
        "code": "emergency",
        "name": "Emergency Loan",
        "interest_method": "FLAT",
        "interest_rate": 0,
        "min_term_months": 1,
        "max_term_months": 6,
        "requires_guarantors": False,
        "min_guarantors": 0,
    },
]


def seed(apps, schema_editor):
    LoanProduct = apps.get_model("loans", "LoanProduct")
    for product in PRODUCTS:
        code = product.pop("code")
        LoanProduct.objects.get_or_create(code=code, defaults=product)
        product["code"] = code


def unseed(apps, schema_editor):
    LoanProduct = apps.get_model("loans", "LoanProduct")
    LoanProduct.objects.filter(code__in=[p["code"] for p in PRODUCTS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("loans", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
