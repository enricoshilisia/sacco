# Adds members.edit_own - the self-service toggle for a member updating
# their own contact details (members.views.MyMemberView.patch), kept as
# its own code rather than reusing the staff-facing members.edit (which
# gates editing ANY member's full record, including KYC-sensitive fields)
# for the same reason loans.apply/loans.apply_on_behalf are two different
# codes on two different endpoints - see 0007's comment for the full
# rationale.

from django.db import migrations

PERMISSION = ("members", "members.edit_own", "Update your own contact details")
GRANTED_TO_ROLES = ["SuperAdmin", "Member"]


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
        ("accesscontrol", "0009_payments_initiate_own_collection"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
