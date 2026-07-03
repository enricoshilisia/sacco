from django.db import connection
from django.utils import timezone

from .models import NotificationLog, NotificationStatus
from .providers.registry import get_active_sms_provider


def queue_sms(*, member=None, event_type: str, recipient: str, message: str) -> NotificationLog:
    """
    Creates the PENDING log row synchronously (so callers get an id back
    immediately) and hands the actual send off to Celery - CLAUDE.md:
    "Money math runs in Celery, is retryable, and is logged." The same
    applies to the notifications that confirm that money math: delivery is
    async, retryable, and always logged, success or failure.
    """
    log = NotificationLog.objects.create(
        member=member,
        event_type=event_type,
        recipient=recipient,
        message=message,
    )
    from .tasks import send_notification_task

    send_notification_task.delay(str(log.id), connection.schema_name)
    return log


def send_now(log: NotificationLog) -> NotificationLog:
    """The actual send - called from the Celery task, inside schema_context."""
    provider = get_active_sms_provider()
    result = provider.send_sms(phone_number=log.recipient, message=log.message)
    log.provider = provider.code
    if result.success:
        log.status = NotificationStatus.SENT
        log.provider_message_id = result.provider_message_id
        log.sent_at = timezone.now()
    else:
        log.status = NotificationStatus.FAILED
        log.error = result.error
    log.save(update_fields=["provider", "status", "provider_message_id", "error", "sent_at"])
    return log
