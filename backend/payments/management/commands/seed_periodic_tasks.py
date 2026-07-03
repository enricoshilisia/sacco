from django.core.management.base import BaseCommand
from django_celery_beat.models import IntervalSchedule, PeriodicTask


class Command(BaseCommand):
    """
    Registers the payments reconciliation job with Celery Beat. Run once
    per environment (idempotent - safe to re-run). Not a migration: this
    schedule is a single global row (django_celery_beat lives in the
    public schema), not per-tenant data, and the task body itself already
    loops every tenant internally - see payments/tasks.py:
    reconcile_pending_collections.
    """

    help = "Registers the periodic payments-reconciliation Celery Beat task."

    def handle(self, *args, **options):
        schedule, _ = IntervalSchedule.objects.get_or_create(every=15, period=IntervalSchedule.MINUTES)
        task, created = PeriodicTask.objects.get_or_create(
            name="Reconcile pending payment collections",
            defaults={
                "interval": schedule,
                "task": "payments.tasks.reconcile_pending_collections",
            },
        )
        if not created:
            task.interval = schedule
            task.task = "payments.tasks.reconcile_pending_collections"
            task.enabled = True
            task.save()
        self.stdout.write(self.style.SUCCESS(f"Periodic task '{task.name}' is registered (every 15 minutes)."))
