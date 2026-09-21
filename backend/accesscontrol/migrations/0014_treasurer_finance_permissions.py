# The Treasurer manages all of the group's finances (registered SACCO):
# the ledger (view, post manual journals, reverse, close periods, chart of
# accounts), dividend/interest runs, payments and reconciliation, loan
# disbursement, withdrawal approval, and every report plus export for
# internal, external and Auditor-General audits.
#
# Deliberately NOT granted, to keep separation of duties:
# - loans.approve / loans.reject: the Credit Committee decides loans; the
#   Treasurer pays out what they approved.
# - savings.deposit / savings.withdraw: handling cash at the counter is
#   the Teller's job; the Treasurer approves withdrawals.
# Two-person rules still apply inside the Treasurer's own powers: nobody
# can approve a dividend run they proposed, or a welfare case they opened.
#
# Also: a new accounting.manage_chart permission (adding accounts such as a
# new expense line), and reports.export for the Auditor so outside auditors
# can take the working papers away.

from django.db import migrations

NEW_PERMISSIONS = [
    ("accounting", "accounting.manage_chart", "Add or deactivate accounts in the chart of accounts"),
]

TREASURER = [
    "accounting.view_ledger", "accounting.view_trial_balance", "accounting.post_journal",
    "accounting.reverse_journal", "accounting.close_period", "accounting.manage_chart",
    "distributions.view", "distributions.run_dividend", "distributions.run_interest",
    "distributions.approve_distribution", "distributions.disburse",
    "payments.view_transactions", "payments.reconcile", "payments.initiate_disbursement",
    "savings.view", "savings.approve_withdrawal",
    "loans.view", "loans.disburse",
    "members.view",
    "reports.view", "reports.export",
    "compliance.view", "compliance.file_return",
]

EXTRA_GRANTS = {
    "SuperAdmin": ["accounting.manage_chart"],
    "Accountant": ["accounting.manage_chart", "loans.view", "savings.view", "members.view"],
    "Auditor": ["reports.export"],
}


def seed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")

    for category, code, label in NEW_PERMISSIONS:
        Permission.objects.get_or_create(code=code, defaults={"category": category, "label": label})

    grants = {"Treasurer": TREASURER, **EXTRA_GRANTS}
    for role_name, codes in grants.items():
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
    RolePermission = apps.get_model("accesscontrol", "RolePermission")
    treasurer = Role.objects.filter(name="Treasurer").first()
    if treasurer is not None:
        RolePermission.objects.filter(role=treasurer, permission__code__in=TREASURER).delete()
    Permission.objects.filter(code__in=[c for _, c, _ in NEW_PERMISSIONS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("accesscontrol", "0013_welfare_permissions_and_roles"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
