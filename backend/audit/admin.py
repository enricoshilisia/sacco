from django.contrib import admin

from .models import AuditEvent


@admin.register(AuditEvent)
class AuditEventAdmin(admin.ModelAdmin):
    list_display = ("at", "actor", "action", "summary", "ip_address", "location", "device")
    list_filter = ("action", "area")
    search_fields = ("actor", "summary", "ip_address", "location", "device")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
