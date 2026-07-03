import uuid

from django.db import models


class NotificationChannel(models.TextChoices):
    SMS = "SMS", "SMS"


class NotificationStatus(models.TextChoices):
    PENDING = "PENDING", "Pending"
    SENT = "SENT", "Sent"
    FAILED = "FAILED", "Failed"


class NotificationLog(models.Model):
    """
    One row per notification attempt - the delivery log BUILD_PLAN.md's
    Phase 3 calls for. Created PENDING synchronously so callers get an id
    back immediately, then moved to SENT/FAILED by the Celery task that
    actually talks to the provider (see notifications/tasks.py). Nothing
    ever edits a row after that except the task itself, so this reads as
    an honest record of what was actually attempted and what happened.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey(
        "members.Member", null=True, blank=True, on_delete=models.SET_NULL, related_name="notifications"
    )
    channel = models.CharField(max_length=10, choices=NotificationChannel.choices, default=NotificationChannel.SMS)
    event_type = models.CharField(max_length=50, help_text="e.g. 'payment_confirmation', 'kyc_verified'")
    recipient = models.CharField(max_length=20, help_text="Phone number the message was sent to")
    message = models.TextField()
    provider = models.CharField(max_length=30, blank=True)
    status = models.CharField(max_length=10, choices=NotificationStatus.choices, default=NotificationStatus.PENDING)
    provider_message_id = models.CharField(max_length=100, blank=True)
    error = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    sent_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.channel} to {self.recipient} ({self.status})"
