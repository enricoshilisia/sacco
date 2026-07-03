# The seeded "Member" role (0003) granted savings.view, which was meant
# for STAFF viewing a member's data by id (e.g. savings.MemberStatementView)
# - a flat, role-level permission with no per-object ownership check. Since
# the default "Member" role is what self-registration grants, this let any
# self-service member view ANY other member's shares/savings statement by
# changing the id in the URL. Ordinary members now use dedicated
# self-service endpoints (members.MyMemberView, savings.MyStatementView)
# that are inherently scoped to request.user and need no permission-catalog
# check at all - so the flat grant is revoked rather than reworked.

from django.db import migrations


def revoke(apps, schema_editor):
    Role = apps.get_model("accesscontrol", "Role")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")
    role = Role.objects.filter(name="Member").first()
    if role is None:
        return
    RolePermission.objects.filter(role=role, permission__code="savings.view").delete()


def restore(apps, schema_editor):
    Role = apps.get_model("accesscontrol", "Role")
    Permission = apps.get_model("accesscontrol", "Permission")
    RolePermission = apps.get_model("accesscontrol", "RolePermission")
    role = Role.objects.filter(name="Member").first()
    permission = Permission.objects.filter(code="savings.view").first()
    if role is None or permission is None:
        return
    RolePermission.objects.get_or_create(role=role, permission=permission)


class Migration(migrations.Migration):

    dependencies = [
        ("accesscontrol", "0005_staffinvite"),
    ]

    operations = [
        migrations.RunPython(revoke, restore),
    ]
