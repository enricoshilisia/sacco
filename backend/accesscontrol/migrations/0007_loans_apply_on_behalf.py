# Adds loans.apply_on_behalf - a distinct permission for STAFF submitting a
# loan application for a member (e.g. an in-branch LoanOfficer helping a
# member who isn't digitally-savvy), separate from loans.apply (which the
# self-service member-facing endpoint already used, seeded in 0003).
# Keeping these as two different codes on two different endpoints - rather
# than one permission gating both a self-service endpoint (ownership-scoped
# by construction, no member_id parameter at all) and a staff endpoint (any
# member_id) - is deliberate: that exact "one flat permission covers both a
# self-service and a look-up-by-id endpoint" shape is what caused the
# cross-member data leak fixed in accesscontrol/migrations/0006.
#
# Also revokes loans.view from "Member" for the same reason: loans.view now
# gates the staff-facing "any loan by id" endpoints (loans.views.LoanListView
# / LoanDetailView's staff branch). Self-service members see their own loans
# and guarantee requests through dedicated ownership-scoped endpoints
# (loans.views.MyLoansListView / MyGuaranteeRequestsView / LoanDetailView's
# owner-or-guarantor branch) that need no permission-catalog check at all -
# same principle as accesscontrol/migrations/0006.
#
# Note that granting a role a NEW permission code requires an explicit
# RolePermission row, even for SuperAdmin - "__all__" in the 0003 seed was
# only ever a snapshot of the permissions that existed at that moment, not
# a dynamic "has every permission that will ever exist" rule (confirmed by
# reading accesscontrol/permissions.py:user_has_permission, which does a
# flat role__permissions__code lookup with no SuperAdmin special-case).

from django.db import migrations

PERMISSION = ("loans", "loans.apply_on_behalf", "Submit a loan application on a member's behalf")
GRANTED_TO_ROLES = ["SuperAdmin", "BranchManager", "LoanOfficer"]


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

    member_role = Role.objects.filter(name="Member").first()
    if member_role is not None:
        RolePermission.objects.filter(role=member_role, permission__code="loans.view").delete()


def unseed(apps, schema_editor):
    Permission = apps.get_model("accesscontrol", "Permission")
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")

    member_role = Role.objects.filter(name="Member").first()
    loans_view = Permission.objects.filter(code="loans.view").first()
    if member_role is not None and loans_view is not None:
        RolePermission.objects.get_or_create(role=member_role, permission=loans_view)

    Permission.objects.filter(code=PERMISSION[1]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("accesscontrol", "0006_member_role_drop_savings_view"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
