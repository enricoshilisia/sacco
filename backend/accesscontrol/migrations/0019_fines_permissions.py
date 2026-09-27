# Fines (the fines app): the disciplinary committee charges them, the
# Treasurer/Teller receives payment, the Chairperson waives.

from django.db import migrations

NEW_PERMISSIONS = [
    ("fines", "fines.view", "See the fines register"),
    ("fines", "fines.charge", "Charge a fine"),
    ("fines", "fines.record_payment", "Record a fine payment"),
    ("fines", "fines.waive", "Waive a fine"),
    ("fines", "fines.manage_rules", "Set offences and their amounts"),
]

GRANTS = {
    "fines.view": ["SuperAdmin", "BranchManager", "Chairperson", "Vice Chairperson", "Secretary",
                   "Assistant Secretary", "Treasurer", "Assistant Treasurer", "Disciplinary Chair",
                   "Disciplinary Member", "Organizing Secretary", "Assistant Organizing Secretary",
                   "BoardMember", "Auditor", "Accountant", "Teller"],
    "fines.charge": ["SuperAdmin", "Disciplinary Chair", "Disciplinary Member", "Secretary", "Assistant Secretary"],
    "fines.record_payment": ["SuperAdmin", "Treasurer", "Assistant Treasurer", "Teller", "Accountant"],
    "fines.waive": ["SuperAdmin", "Chairperson", "Vice Chairperson", "Disciplinary Chair"],
    "fines.manage_rules": ["SuperAdmin", "Chairperson", "Disciplinary Chair"],
}


def seed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")
    for category, code, label in NEW_PERMISSIONS:
        Permission.objects.get_or_create(code=code, defaults={"category": category, "label": label})
    for code, roles in GRANTS.items():
        permission = Permission.objects.get(code=code)
        for name in roles:
            role = Role.objects.filter(name=name).first()
            if role is not None:
                RolePermission.objects.get_or_create(role=role, permission=permission)


def unseed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Permission.objects.filter(code__in=[c for _, c, _ in NEW_PERMISSIONS]).delete()


class Migration(migrations.Migration):

    dependencies = [("accesscontrol", "0018_minutes_permissions")]

    operations = [migrations.RunPython(seed, unseed)]
