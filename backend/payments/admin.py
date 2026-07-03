from django.contrib import admin

from .models import PaymentCollection


@admin.register(PaymentCollection)
class PaymentCollectionAdmin(admin.ModelAdmin):
    list_display = ("member", "provider", "amount", "status", "created_at", "completed_at")
    list_filter = ("provider", "status")
    search_fields = ("member__first_name", "member__last_name", "provider_reference", "provider_receipt")
    readonly_fields = [f.name for f in PaymentCollection._meta.fields]

    def has_add_permission(self, request):
        # Only ever created via payments.services.initiate_collection /
        # handle_collection_callback, so this stays an honest record of
        # what actually happened - same principle as JournalEntry.
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
