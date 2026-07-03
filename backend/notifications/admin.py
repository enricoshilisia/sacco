from django.contrib import admin

from .models import NotificationLog


@admin.register(NotificationLog)
class NotificationLogAdmin(admin.ModelAdmin):
    list_display = ("recipient", "event_type", "channel", "provider", "status", "created_at", "sent_at")
    list_filter = ("status", "channel", "provider")
    search_fields = ("recipient", "event_type", "message")

    def has_add_permission(self, request):
        # Only ever created via notifications.services.queue_sms, so the
        # log stays an honest record of what was actually attempted.
        return False
