from celery import shared_task
from django_tenants.utils import schema_context


@shared_task(bind=True, max_retries=3, default_retry_delay=30)
def send_notification_task(self, log_id: str, tenant_schema: str):
    """
    Runs in a Celery worker, outside any request cycle - django-tenants'
    per-request schema resolution never applies here, so every tenant-aware
    task must take the schema explicitly and enter it itself. Callers
    (notifications.services.queue_sms) always pass connection.schema_name
    from within their own request/task context.
    """
    with schema_context(tenant_schema):
        from .models import NotificationLog
        from .services import send_now

        log = NotificationLog.objects.get(id=log_id)
        send_now(log)
