import uuid

from django.conf import settings
from django.db import models


class AuditAction(models.TextChoices):
    LOGIN = "LOGIN", "Signed in"
    LOGIN_FAILED = "LOGIN_FAILED", "Failed sign-in"
    VIEW = "VIEW", "Viewed"
    CREATE = "CREATE", "Created / submitted"
    UPDATE = "UPDATE", "Changed"
    DELETE = "DELETE", "Deleted"
    EVENT = "EVENT", "Security event"


class AuditEvent(models.Model):
    """
    One thing someone did or looked at in this SACCO: who, what, when, from
    where and on which device. Written by audit.middleware for every API
    request, plus explicit events (sign-ins, password resets, role changes)
    via audit.services.record. Append-only: rows can't be changed or
    deleted through the app (CLAUDE.md rule 3 applies to the audit trail
    as much as to the journal).
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    at = models.DateTimeField(auto_now_add=True, db_index=True)

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    actor = models.CharField(max_length=200, blank=True, help_text="Name and phone at the time.")

    action = models.CharField(max_length=15, choices=AuditAction.choices, db_index=True)
    event = models.CharField(max_length=60, blank=True, db_index=True, help_text="e.g. password.reset")
    area = models.CharField(max_length=40, blank=True, db_index=True, help_text="e.g. members, loans")
    summary = models.CharField(max_length=300)
    method = models.CharField(max_length=10, blank=True)
    path = models.CharField(max_length=300, blank=True)
    status_code = models.PositiveSmallIntegerField(null=True, blank=True)
    target_type = models.CharField(max_length=60, blank=True)
    target_id = models.CharField(max_length=64, blank=True)
    target_label = models.CharField(max_length=200, blank=True)

    ip_address = models.GenericIPAddressField(null=True, blank=True)
    location = models.CharField(max_length=200, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    device = models.CharField(max_length=200, blank=True)
    user_agent = models.CharField(max_length=300, blank=True)
    duration_ms = models.PositiveIntegerField(null=True, blank=True)

    class Meta:
        ordering = ["-at"]
        indexes = [models.Index(fields=["user", "-at"])]

    def save(self, *args, **kwargs):
        if not self._state.adding:
            raise ValueError("Audit events are append-only.")
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise ValueError("Audit events are append-only.")
