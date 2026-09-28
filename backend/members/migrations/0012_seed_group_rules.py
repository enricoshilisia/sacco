# The offences in Inuka West's rules and regulations, and the rules that
# go with them: 90 days to full membership, three months' notice to leave
# with 90% refunded, and how much warning an apology needs.

from decimal import Decimal

from django.db import migrations

OFFENCES = [
    ("Absent without apology", "100", "ABSENT", "Missing a general meeting without sending an apology."),
    ("Late to meeting", "100", "LATE", "Arriving after the meeting has started."),
    ("Missing three consecutive meetings", "500", "",
     "Three general meetings in a row missed."),
    ("Discussing group matters outside the group", "1000", "",
     "Group business must stay in the group."),
    ("Inflammatory or defamatory language", "2000", "",
     "Also carries a 90-day suspension."),
    ("Attending a meeting drunk", "500", "", "No member may attend a meeting drunk."),
]


def seed(apps, schema_editor):
    OffenceType = apps.get_model("fines", "OffenceType")
    for name, amount, mark, description in OFFENCES:
        offence, created = OffenceType.objects.get_or_create(
            name=name, defaults={"amount": Decimal(amount), "from_attendance": mark, "description": description},
        )
        if not created and not offence.description:
            offence.description = description
            offence.save(update_fields=["description"])


class Migration(migrations.Migration):

    dependencies = [
        ("members", "0011_meeting_and_apology_rules"),
        ("fines", "0001_initial"),
    ]

    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]
