# Attaches a real eligibility policy to the "Emergency Loan" demo product,
# so the auto grant/deny path (loans.services._attempt_auto_decision) is
# actually exercised by the existing application flow, not just callable
# in isolation. "Development Loan" (guarantor-required) intentionally gets
# no policy - it keeps behaving exactly as before this app existed.
#
# max_active_loans is deliberately left null (no limit): this project's
# e2e tests don't clean up test data between runs, so a count-based rule
# here would eventually flip outcomes across repeated runs for reasons
# unrelated to a member's actual standing.

from django.db import migrations

POLICY_DEFAULTS = {
    "is_active": True,
    "require_kyc_verified": True,
    "require_no_active_arrears": True,
    "max_active_loans": None,
    "min_membership_months": 0,
    "min_guarantor_coverage_ratio": None,
    "require_crb_check": True,
    "crb_deny_below_score": 500,
    "crb_refer_below_score": 650,
}


def seed(apps, schema_editor):
    LoanProduct = apps.get_model("loans", "LoanProduct")
    LoanEligibilityPolicy = apps.get_model("rules_engine", "LoanEligibilityPolicy")
    product = LoanProduct.objects.filter(code="emergency").first()
    if product is not None:
        LoanEligibilityPolicy.objects.get_or_create(product=product, defaults=POLICY_DEFAULTS)


def unseed(apps, schema_editor):
    LoanEligibilityPolicy = apps.get_model("rules_engine", "LoanEligibilityPolicy")
    LoanEligibilityPolicy.objects.filter(product__code="emergency").delete()


class Migration(migrations.Migration):

    dependencies = [
        ("rules_engine", "0001_initial"),
        ("loans", "0002_seed_default_products"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
