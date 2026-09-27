# The Treasurer runs the group's money day to day, so she records members'
# monthly contributions at the counter (savings.deposit) and can send a
# member an M-Pesa request. Her assistant does the same work.

from django.db import migrations

GRANTS = {
    "Treasurer": ["savings.deposit", "payments.initiate_collection"],
    "Assistant Treasurer": ["savings.deposit", "payments.initiate_collection", "savings.view",
                            "savings.approve_withdrawal"],
}


def seed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")
    for role_name, codes in GRANTS.items():
        role = Role.objects.filter(name=role_name).first()
        if role is None:
            continue
        for code in codes:
            permission = Permission.objects.filter(code=code).first()
            if permission is not None:
                RolePermission.objects.get_or_create(role=role, permission=permission)


class Migration(migrations.Migration):

    dependencies = [("accesscontrol", "0019_fines_permissions")]

    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
