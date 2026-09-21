# Offices (positions) with assistants, member admission, and admin support.
#
# - Every elected office gets an assistant office with the same permissions,
#   one holder each: two people per office, so one can check the other.
# - New offices: Chairperson (+ Vice), Organizing Secretary, Disciplinary
#   Committee (chair + members), IT Administrator (support).
# - members.register (Secretary) / members.approve_admission (Chairperson):
#   the two signatures on a new member.
# - users.* and audit.view: password resets, disabling logins, audit log.

from django.db import migrations

NEW_PERMISSIONS = [
    ("members", "members.register", "Register new member applications"),
    ("members", "members.approve_admission", "Approve or reject new member applications"),
    ("members", "members.record_fee", "Record registration fees received"),
    ("users", "users.view", "View user accounts and their access"),
    ("users", "users.reset_password", "Reset a user's password to a temporary one"),
    ("users", "users.manage_access", "Disable or re-enable a user's login"),
    ("audit", "audit.view", "View the audit log"),
]

REPORTS_READ = ["reports.view", "accounting.view_ledger", "accounting.view_trial_balance",
                "loans.view", "savings.view", "distributions.view", "payments.view_transactions"]
MEETINGS = ["governance.view", "governance.call_meeting", "governance.manage_agenda",
            "governance.take_attendance", "governance.upload_minutes", "governance.create_resolution"]

# name: (description, sort, max_holders, assistant_of, permissions or ("copy", role))
POSITIONS = {
    "Chairperson": ("Leads the SACCO: approves new members and welfare cases, chairs meetings, sees all reports.",
                    10, 1, None,
                    ["members.view", "members.approve_admission", "welfare.view", "welfare.approve_case",
                     "documents.view"] + MEETINGS + REPORTS_READ),
    "Vice Chairperson": ("Deputises for the Chairperson with the same powers.", 11, 1, "Chairperson",
                         ("copy", "Chairperson")),
    "Secretary": (None, 20, 1, None, None),
    "Assistant Secretary": ("Deputises for the Secretary with the same powers.", 21, 1, "Secretary",
                            ("copy", "Secretary")),
    "Treasurer": (None, 30, 1, None, None),
    "Assistant Treasurer": ("Deputises for the Treasurer with the same powers.", 31, 1, "Treasurer",
                            ("copy", "Treasurer")),
    "WelfareManager": (None, 40, 1, None, None),
    "Assistant Welfare Manager": ("Deputises for the Welfare Manager with the same powers.", 41, 1,
                                  "WelfareManager", ("copy", "WelfareManager")),
    "Organizing Secretary": ("Organises meetings and events: schedules meetings, agendas and the register.",
                             50, 1, None, ["members.view"] + MEETINGS),
    "Assistant Organizing Secretary": ("Deputises for the Organizing Secretary.", 51, 1, "Organizing Secretary",
                                       ("copy", "Organizing Secretary")),
    "Disciplinary Chair": ("Leads the disciplinary committee (cases, hearings, fines).", 60, 1, None,
                           ["members.view", "governance.view", "governance.take_attendance", "reports.view"]),
    "Disciplinary Member": ("Sits on the disciplinary committee.", 61, 4, "Disciplinary Chair",
                            ["members.view", "governance.view", "reports.view"]),
    "IT Administrator": ("Support: resets passwords, manages logins, reads the audit log.", 70, 2, None,
                         ["members.view", "users.view", "users.reset_password", "users.manage_access",
                          "audit.view"]),
    "CreditCommittee": (None, 80, None, None, None),
    "BoardMember": (None, 90, None, None, None),
}

EXTRA_GRANTS = {
    "Secretary": ["members.register"],
    "Treasurer": ["members.record_fee"],
    "Teller": ["members.record_fee"],
    "BranchManager": ["members.register", "members.record_fee", "users.view"],
    "Auditor": ["audit.view", "users.view"],
}


def seed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")

    for category, code, label in NEW_PERMISSIONS:
        Permission.objects.get_or_create(code=code, defaults={"category": category, "label": label})

    def grant(role, codes):
        for code in codes:
            permission = Permission.objects.filter(code=code).first()
            if permission is not None:
                RolePermission.objects.get_or_create(role=role, permission=permission)

    # Existing roles first (Secretary must have members.register before its
    # assistant copies it).
    for name, codes in EXTRA_GRANTS.items():
        role = Role.objects.filter(name=name).first()
        if role is not None:
            grant(role, codes)

    for name, (description, sort, max_holders, assistant_of, perms) in POSITIONS.items():
        role = Role.objects.filter(name=name).first()
        if role is None:
            if description is None:
                continue  # an existing role this SACCO doesn't have
            role = Role.objects.create(name=name, description=description, is_system=True)
        role.is_position = True
        role.sort_order = sort
        role.max_holders = max_holders
        role.assistant_of = Role.objects.filter(name=assistant_of).first() if assistant_of else None
        role.save()
        if isinstance(perms, tuple):
            source = Role.objects.get(name=perms[1])
            grant(role, source.permissions.values_list("code", flat=True))
        elif perms:
            grant(role, perms)

    super_admin = Role.objects.filter(name="SuperAdmin").first()
    if super_admin is not None:
        grant(super_admin, [code for _, code, _ in NEW_PERMISSIONS])


def unseed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    new_roles = [n for n, v in POSITIONS.items() if v[0] is not None]
    Role.objects.filter(name__in=new_roles, memberships__isnull=True).delete()
    Permission.objects.filter(code__in=[c for _, c, _ in NEW_PERMISSIONS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("accesscontrol", "0016_role_positions"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
