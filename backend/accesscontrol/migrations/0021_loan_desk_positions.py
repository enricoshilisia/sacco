# Who runs the loan desk in a chama: the Loans Officer writes the loan and
# appraises it, the Credit Committee approves, and the Chairperson (with
# the Loans Officer) sets the rules - how much a member may borrow, over
# how long, and the standard rate.

from django.db import migrations

GRANTS = {
    "LoanOfficer": ["loans.manage_products", "members.view", "savings.view", "fines.view"],
    "CreditCommittee": ["loans.view", "loans.approve", "loans.reject", "members.view", "savings.view",
                        "loans.manage_eligibility_policy"],
    "Chairperson": ["loans.manage_products", "loans.view", "loans.manage_eligibility_policy"],
    "Treasurer": ["loans.view"],
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
    # The Loans Officer is an office like any other: one holder, with an
    # assistant who can stand in.
    officer = Role.objects.filter(name="LoanOfficer").first()
    if officer is not None:
        officer.is_position = True
        officer.max_holders = 1
        officer.sort_order = 55
        officer.save()


class Migration(migrations.Migration):

    dependencies = [("accesscontrol", "0020_treasurer_records_contributions")]

    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
