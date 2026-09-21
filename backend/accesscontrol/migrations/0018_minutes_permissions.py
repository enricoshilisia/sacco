# Meeting documents and minutes (governance.papers): the Secretary writes
# (governance.upload_minutes, already held), the Chairperson approves; and
# committee/board papers are only for leaders and auditors.

from django.db import migrations

NEW_PERMISSIONS = [
    ("governance", "governance.approve_minutes", "Approve meeting minutes"),
    ("governance", "governance.view_confidential", "See committee and board meeting papers"),
]

GRANTS = {
    "governance.approve_minutes": ["SuperAdmin", "Chairperson", "Vice Chairperson"],
    "governance.view_confidential": [
        "SuperAdmin", "BranchManager", "Chairperson", "Vice Chairperson", "Secretary", "Assistant Secretary",
        "Treasurer", "Assistant Treasurer", "WelfareManager", "Assistant Welfare Manager", "Organizing Secretary",
        "Assistant Organizing Secretary", "Disciplinary Chair", "Disciplinary Member", "BoardMember",
        "CommitteeMember", "CreditCommittee", "Auditor",
    ],
}
# Assistants hold the same powers as the office they deputise for.
ALSO = {"Assistant Secretary": ["governance.upload_minutes", "governance.view"]}


def seed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")
    for category, code, label in NEW_PERMISSIONS:
        Permission.objects.get_or_create(code=code, defaults={"category": category, "label": label})

    def grant(role_name, code):
        role = Role.objects.filter(name=role_name).first()
        permission = Permission.objects.filter(code=code).first()
        if role is not None and permission is not None:
            RolePermission.objects.get_or_create(role=role, permission=permission)

    for code, roles in GRANTS.items():
        for role_name in roles:
            grant(role_name, code)
    for role_name, codes in ALSO.items():
        for code in codes:
            grant(role_name, code)


def unseed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Permission.objects.filter(code__in=[c for _, c, _ in NEW_PERMISSIONS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("accesscontrol", "0017_positions_admission_support"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
