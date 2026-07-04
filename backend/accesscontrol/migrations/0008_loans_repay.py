# Adds loans.repay - Phase 4 slice 2. Granting a role a NEW permission
# code requires an explicit RolePermission row, even for SuperAdmin -
# "__all__" in the 0003 seed was only ever a snapshot of what existed at
# that moment (confirmed by accesscontrol.permissions.user_has_permission,
# a flat role__permissions__code lookup with no SuperAdmin special-case),
# same lesson already documented in 0007.
#
# Granted to whoever already holds savings.deposit (Teller explicitly,
# BranchManager via its category grant, SuperAdmin via its original
# __all__ snapshot) - a walk-in loan repayment is the same front-office
# cash-handling shape as a walk-in savings deposit, so the same roles that
# can take one can take the other.

from django.db import migrations

PERMISSION = ("loans", "loans.repay", "Record a loan repayment")
GRANTED_TO_ROLES = ["SuperAdmin", "BranchManager", "Teller"]


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
        ("accesscontrol", "0007_loans_apply_on_behalf"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
