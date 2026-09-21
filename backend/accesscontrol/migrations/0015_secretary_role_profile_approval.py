# Member profiles are locked once approved; changes go through an approval
# queue. members.approve_changes is that approval. It goes to a new
# Secretary role (which will also run meetings - governance - in a later
# slice), plus Branch Manager and SuperAdmin. The Secretary also gets the
# member lookups they need to review a request.

from django.db import migrations

NEW_PERMISSIONS = [
    ("members", "members.approve_changes", "Approve members' profile and family-register changes"),
]

SECRETARY = (
    "Secretary",
    "Keeps the member register: verifies KYC and approves profile and family changes; runs meetings.",
)

GRANTS = {
    "Secretary": [
        "members.view", "members.kyc_verify", "members.approve_changes",
        "governance.view", "governance.call_meeting", "governance.manage_agenda",
        "governance.take_attendance", "governance.upload_minutes",
        "documents.view", "documents.upload", "welfare.view",
    ],
    "SuperAdmin": ["members.approve_changes"],
    "BranchManager": ["members.approve_changes"],
}


def seed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")

    for category, code, label in NEW_PERMISSIONS:
        Permission.objects.get_or_create(code=code, defaults={"category": category, "label": label})
    Role.objects.get_or_create(name=SECRETARY[0], defaults={"description": SECRETARY[1], "is_system": True})

    for role_name, codes in GRANTS.items():
        role = Role.objects.filter(name=role_name).first()
        if role is None:
            continue
        for code in codes:
            permission = Permission.objects.filter(code=code).first()
            if permission is not None:
                RolePermission.objects.get_or_create(role=role, permission=permission)


def unseed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    Permission.objects.filter(code__in=[c for _, c, _ in NEW_PERMISSIONS]).delete()
    Role.objects.filter(name=SECRETARY[0], memberships__isnull=True).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("accesscontrol", "0014_treasurer_finance_permissions"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
