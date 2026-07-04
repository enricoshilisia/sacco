# Adds loans.manage_eligibility_policy - gates the new rules_engine
# LoanEligibilityPolicyView (staff configuring per-product auto grant/deny
# rules). Explicit GRANTED_TO_ROLES rather than relying on BranchManager's
# blanket "loans" category grant: that grant was a one-time list
# comprehension baked into 0003's seed migration over the PERMISSIONS list
# as it existed then - a new "loans"-category code added later doesn't
# automatically reach BranchManager, so it's listed here explicitly (same
# reasoning as every migration since 0006).

from django.db import migrations

PERMISSION = ("loans", "loans.manage_eligibility_policy", "Configure loan-product eligibility policies")
GRANTED_TO_ROLES = ["SuperAdmin", "BranchManager"]


def seed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")

    category, code, label = PERMISSION
    permission, _ = Permission.objects.get_or_create(code=code, defaults={"category": category, "label": label})

    for role_name in GRANTED_TO_ROLES:
        role = Role.objects.filter(name=role_name).first()
        if role is not None:
            RolePermission.objects.get_or_create(role=role, permission=permission)


def unseed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Permission.objects.filter(code=PERMISSION[1]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("accesscontrol", "0010_members_edit_own"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
