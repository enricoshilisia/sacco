# Members whose KYC was already verified before the approval workflow
# existed count as approved profiles - they shouldn't be sent back to
# "not yet submitted" just because the workflow is new.

from django.db import migrations


def forwards(apps, schema_editor):
    Member = apps.get_model("members", "Member")
    Member.objects.filter(is_kyc_verified=True).update(profile_status="APPROVED")


class Migration(migrations.Migration):

    dependencies = [
        ("members", "0004_member_county_member_employer_member_marital_status_and_more"),
    ]

    operations = [
        migrations.RunPython(forwards, migrations.RunPython.noop),
    ]
