# Adds payments.initiate_own_collection - the self-service toggle for a
# member funding their own share contribution/savings deposit via mobile
# money (payments.views.MyInitiateCollectionView), kept as its own code
# rather than reusing payments.initiate_collection (which gates the
# staff-on-behalf endpoint, InitiateCollectionView, taking an arbitrary
# member_id) for the same reason loans.apply and loans.apply_on_behalf
# are two different codes on two different endpoints - see 0007's
# comment for the full rationale (also the origin of the cross-member
# data leak fixed in 0006, which this pattern exists to avoid repeating).

from django.db import migrations

PERMISSION = ("payments", "payments.initiate_own_collection", "Fund your own share/savings account via mobile money")
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
        ("accesscontrol", "0008_loans_repay"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
