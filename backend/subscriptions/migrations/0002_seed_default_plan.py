from django.db import migrations


def seed(apps, schema_editor):
    Plan = apps.get_model("subscriptions", "Plan")
    Plan.objects.get_or_create(
        slug="starter",
        defaults={
            "name": "Starter",
            "monthly_price": 0,
            "currency": "USD",
            "is_default": True,
            "is_active": True,
        },
    )


def unseed(apps, schema_editor):
    Plan = apps.get_model("subscriptions", "Plan")
    Plan.objects.filter(slug="starter").delete()


class Migration(migrations.Migration):

    dependencies = [
        ("subscriptions", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(seed, unseed),
    ]
