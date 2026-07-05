# Wires up the four distributions permission codes that were anticipated
# verbatim in 0003's PERMISSIONS list back when this app didn't exist yet -
# their category-match list comprehensions (e.g. Accountant's
# "distributions" category grant) never took effect because no Permission
# row with that category existed until now (0003's comprehension ran once,
# at apply time, over the PERMISSIONS list as it stood then). Per the
# convention established in every migration since 0006: a blanket category
# grant from an old seed migration does not retroactively pick up new
# permission codes - every grant is listed explicitly here. Also adds
# distributions.disburse, a brand new code with no anticipated slot in
# 0003 (the original design stopped at "approve"; this build added a
# cash-payout-via-mobile-money step that needs its own, tightly-held
# permission - same reasoning as loans.disburse being separate from
# loans.approve).

from django.db import migrations

PERMISSIONS = [
    ("distributions", "distributions.view", "View distribution runs"),
    ("distributions", "distributions.run_dividend", "Run a dividend distribution"),
    ("distributions", "distributions.run_interest", "Run an interest/rebate distribution"),
    ("distributions", "distributions.approve_distribution", "Approve a distribution run"),
    ("distributions", "distributions.disburse", "Pay out an approved distribution to members"),
]

GRANTED_TO_ROLES = {
    "distributions.view": ["SuperAdmin", "BranchManager", "Accountant", "Auditor", "BoardMember"],
    "distributions.run_dividend": ["SuperAdmin", "Accountant", "BranchManager"],
    "distributions.run_interest": ["SuperAdmin", "Accountant", "BranchManager"],
    "distributions.approve_distribution": ["SuperAdmin", "Accountant"],
    "distributions.disburse": ["SuperAdmin", "Accountant"],
}


def seed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")

    for category, code, label in PERMISSIONS:
        permission, _ = Permission.objects.get_or_create(code=code, defaults={"category": category, "label": label})
        for role_name in GRANTED_TO_ROLES[code]:
            role = Role.objects.filter(name=role_name).first()
            if role is not None:
                RolePermission.objects.get_or_create(role=role, permission=permission)


def unseed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Permission.objects.filter(code__in=[c for _, c, _ in PERMISSIONS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("accesscontrol", "0011_loans_manage_eligibility_policy"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
