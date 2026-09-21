import logging

from celery import shared_task
from django.utils import timezone
from django_tenants.utils import get_tenant_model, schema_context

logger = logging.getLogger(__name__)


@shared_task
def run_activity_check_all_tenants():
    """Monthly inactivity check for every SACCO (scheduled in settings.CELERY_BEAT_SCHEDULE).
    Each SACCO is independent: one failing doesn't stop the others."""
    for tenant in get_tenant_model().objects.exclude(schema_name="public"):
        try:
            with schema_context(tenant.schema_name):
                from members.activity import run_activity_check
                from members.models import MemberActivitySettings

                result = run_activity_check()
                settings = MemberActivitySettings.get_solo()
                settings.last_run_at = timezone.now()
                settings.save(update_fields=["last_run_at"])
                logger.info("Activity check for %s: %s", tenant.schema_name, result)
        except Exception:
            logger.exception("Activity check failed for %s", tenant.schema_name)
