# Seeds the default permission catalog and system roles into every tenant
# schema. Runs per-tenant because accesscontrol is a TENANT_APPS app.

from django.db import migrations

PERMISSIONS = [
    # category, code, label
    ("members", "members.view", "View members"),
    ("members", "members.create", "Register members"),
    ("members", "members.edit", "Edit member records"),
    ("members", "members.delete", "Delete/deactivate members"),
    ("members", "members.kyc_verify", "Verify member KYC documents"),
    ("members", "members.manage_guarantors", "Manage guarantor relationships"),

    ("savings", "savings.view", "View savings/share accounts"),
    ("savings", "savings.deposit", "Record a savings/share deposit"),
    ("savings", "savings.withdraw", "Process a savings withdrawal"),
    ("savings", "savings.approve_withdrawal", "Approve a savings withdrawal"),
    ("savings", "savings.manage_products", "Create/edit savings products"),

    ("loans", "loans.view", "View loan accounts and applications"),
    ("loans", "loans.apply", "Submit a loan application"),
    ("loans", "loans.appraise", "Appraise a loan application"),
    ("loans", "loans.approve", "Approve a loan"),
    ("loans", "loans.reject", "Reject a loan"),
    ("loans", "loans.disburse", "Disburse an approved loan"),
    ("loans", "loans.reschedule", "Reschedule a loan"),
    ("loans", "loans.manage_products", "Create/edit loan products"),
    ("loans", "loans.manage_guarantor_pledge", "Manage guarantor pledges on a loan"),

    ("accounting", "accounting.view_ledger", "View the general ledger"),
    ("accounting", "accounting.post_journal", "Post a journal entry"),
    ("accounting", "accounting.reverse_journal", "Post a reversing journal entry"),
    ("accounting", "accounting.view_trial_balance", "View trial balance"),
    ("accounting", "accounting.close_period", "Close an accounting period"),

    ("distributions", "distributions.view", "View distribution runs"),
    ("distributions", "distributions.run_dividend", "Run a dividend distribution"),
    ("distributions", "distributions.run_interest", "Run an interest/rebate distribution"),
    ("distributions", "distributions.approve_distribution", "Approve a distribution run"),

    ("investments", "investments.view", "View tenant investments"),
    ("investments", "investments.manage", "Manage tenant investments"),

    ("governance", "governance.view", "View meetings, resolutions, elections"),
    ("governance", "governance.call_meeting", "Call a meeting"),
    ("governance", "governance.manage_agenda", "Manage a meeting agenda"),
    ("governance", "governance.take_attendance", "Take meeting attendance"),
    ("governance", "governance.upload_minutes", "Upload meeting minutes"),
    ("governance", "governance.create_resolution", "Create a resolution for voting"),
    ("governance", "governance.vote", "Vote on a resolution"),
    ("governance", "governance.manage_elections", "Manage delegate/committee elections"),

    ("discussions", "discussions.view", "View the member forum"),
    ("discussions", "discussions.post", "Post to the member forum"),
    ("discussions", "discussions.moderate", "Moderate the member forum"),

    ("documents", "documents.view", "View documents/media archive"),
    ("documents", "documents.upload", "Upload documents/media"),
    ("documents", "documents.delete", "Delete documents/media"),

    ("compliance", "compliance.view", "View compliance returns"),
    ("compliance", "compliance.file_return", "File a regulatory return"),
    ("compliance", "compliance.manage_returns", "Manage compliance return configuration"),

    ("reports", "reports.view", "View reports and dashboards"),
    ("reports", "reports.export", "Export reports"),

    ("payments", "payments.initiate_collection", "Initiate a payment collection"),
    ("payments", "payments.initiate_disbursement", "Initiate a payment disbursement"),
    ("payments", "payments.view_transactions", "View payment transactions"),
    ("payments", "payments.reconcile", "Reconcile payment transactions"),

    ("notifications", "notifications.send", "Send an ad-hoc notification"),
    ("notifications", "notifications.manage_templates", "Manage notification templates"),
    ("notifications", "notifications.manage_providers", "Configure SMS/push providers"),

    ("configuration", "configuration.view", "View tenant configuration"),
    ("configuration", "configuration.edit", "Edit tenant configuration"),

    ("accesscontrol", "accesscontrol.manage_roles", "Create/edit roles"),
    ("accesscontrol", "accesscontrol.assign_roles", "Assign roles to users"),

    ("admin", "admin.manage_tenant", "Manage tenant-level settings"),
    ("admin", "admin.manage_subscription", "Manage subscription/billing"),
]

# role_name -> (description, permission codes or "__all__")
ROLES = {
    "SuperAdmin": ("Full access within this SACCO.", "__all__"),
    "BranchManager": (
        "Day-to-day operational management of a branch.",
        [c for cat, c, _ in PERMISSIONS if cat in (
            "members", "savings", "loans", "reports", "documents", "governance",
        )] + ["payments.view_transactions", "distributions.view", "compliance.view"],
    ),
    "Teller": (
        "Front-office cash/savings transactions.",
        ["members.view", "savings.view", "savings.deposit", "savings.withdraw",
         "payments.initiate_collection", "reports.view"],
    ),
    "LoanOfficer": (
        "Manages loan applications through appraisal.",
        ["members.view", "loans.view", "loans.apply", "loans.appraise",
         "loans.manage_guarantor_pledge", "members.manage_guarantors", "reports.view"],
    ),
    "CreditCommittee": (
        "Approves or rejects appraised loans.",
        ["loans.view", "loans.approve", "loans.reject", "reports.view"],
    ),
    "Accountant": (
        "Owns the ledger and financial close.",
        [c for cat, c, _ in PERMISSIONS if cat in ("accounting", "distributions", "reports")]
        + ["payments.view_transactions", "payments.reconcile", "compliance.file_return"],
    ),
    "Auditor": (
        "Read-only oversight across financial and compliance records.",
        ["accounting.view_ledger", "accounting.view_trial_balance", "reports.view",
         "compliance.view", "loans.view", "savings.view", "members.view",
         "distributions.view", "payments.view_transactions"],
    ),
    "BoardMember": (
        "Governance oversight: meetings, resolutions, elections.",
        [c for cat, c, _ in PERMISSIONS if cat == "governance"]
        + ["reports.view", "distributions.view", "compliance.view"],
    ),
    "CommitteeMember": (
        "Serves on a SACCO committee (credit, supervisory, etc.).",
        ["governance.view", "governance.vote", "reports.view"],
    ),
    "Member": (
        "Ordinary SACCO member self-service access.",
        ["savings.view", "loans.view", "loans.apply", "discussions.view",
         "discussions.post", "documents.view", "governance.view", "governance.vote"],
    ),
    "Guarantor": (
        "A member who has pledged deposits as loan security for another member.",
        ["savings.view", "loans.view"],
    ),
}


def seed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")

    code_to_permission = {}
    for category, code, label in PERMISSIONS:
        perm, _ = Permission.objects.get_or_create(
            code=code, defaults={"category": category, "label": label}
        )
        code_to_permission[code] = perm

    for name, (description, codes) in ROLES.items():
        role, _ = Role.objects.get_or_create(
            name=name, defaults={"description": description, "is_system": True}
        )
        wanted_codes = list(code_to_permission.keys()) if codes == "__all__" else codes
        for code in wanted_codes:
            RolePermission.objects.get_or_create(role=role, permission=code_to_permission[code])


def unseed(apps, schema_editor):
    Role = apps.get_model("accesscontrol", "Role")
    Permission = apps.get_model("accesscontrol", "Permission")
    Role.objects.filter(is_system=True, name__in=ROLES.keys()).delete()
    Permission.objects.filter(code__in=[c for _, c, _ in PERMISSIONS]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("accesscontrol", "0002_initial"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
