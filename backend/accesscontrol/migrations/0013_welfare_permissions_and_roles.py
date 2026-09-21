# Welfare: new permission codes plus two new system roles.
#
# - WelfareManager opens cases, records counter payments and payouts, and
#   looks up members for that (welfare-scoped search, not members.view).
# - Treasurer approves cases (the second person - opening and approving
#   are deliberately separate permissions, and welfare.services.
#   approve_case also refuses the case's own creator) and closes the year.
# - The constitution's rules (case types and amounts) are held by
#   SuperAdmin and BoardMember, not the manager who opens cases.
#
# Same convention as 0012: every grant is listed explicitly; old category
# grants never pick up new codes.

from django.db import migrations

PERMISSIONS = [
    ("welfare", "welfare.view", "View welfare cases and member welfare balances"),
    ("welfare", "welfare.manage_rules", "Edit welfare rules (case types and amounts)"),
    ("welfare", "welfare.create_case", "Open a welfare case"),
    ("welfare", "welfare.approve_case", "Approve or reject a welfare case"),
    ("welfare", "welfare.record_payment", "Record a member's welfare payment at the counter"),
    ("welfare", "welfare.record_payout", "Record a welfare payout and close cases"),
    ("welfare", "welfare.close_year", "Close the welfare year"),
]

NEW_ROLES = {
    "WelfareManager": "Runs the welfare fund day to day: opens cases, records payments and payouts.",
    "Treasurer": "Approves welfare cases and closes the welfare year.",
}

GRANTED_TO_ROLES = {
    "welfare.view": ["SuperAdmin", "WelfareManager", "Treasurer", "BoardMember", "Auditor", "Accountant"],
    "welfare.manage_rules": ["SuperAdmin", "BoardMember"],
    "welfare.create_case": ["SuperAdmin", "WelfareManager"],
    "welfare.approve_case": ["SuperAdmin", "Treasurer", "BoardMember"],
    "welfare.record_payment": ["SuperAdmin", "WelfareManager", "Treasurer", "Teller"],
    "welfare.record_payout": ["SuperAdmin", "WelfareManager"],
    "welfare.close_year": ["SuperAdmin", "Treasurer"],
}


def seed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")

    for name, description in NEW_ROLES.items():
        Role.objects.get_or_create(name=name, defaults={"description": description, "is_system": True})

    for category, code, label in PERMISSIONS:
        permission, _ = Permission.objects.get_or_create(code=code, defaults={"category": category, "label": label})
        for role_name in GRANTED_TO_ROLES[code]:
            role = Role.objects.filter(name=role_name).first()
            if role is not None:
                RolePermission.objects.get_or_create(role=role, permission=permission)


def unseed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    Permission.objects.filter(code__in=[c for _, c, _ in PERMISSIONS]).delete()
    Role.objects.filter(name__in=NEW_ROLES, memberships__isnull=True).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("accesscontrol", "0012_distributions_permissions"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
