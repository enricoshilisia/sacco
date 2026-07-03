from django.contrib import admin

from .models import Account, JournalEntry, JournalLine


class JournalLineInline(admin.TabularInline):
    model = JournalLine
    extra = 0
    readonly_fields = ["account", "debit", "credit", "member", "description"]
    can_delete = False


@admin.register(Account)
class AccountAdmin(admin.ModelAdmin):
    list_display = ["code", "name", "account_type", "is_control_account", "is_active"]
    search_fields = ["code", "name"]


@admin.register(JournalEntry)
class JournalEntryAdmin(admin.ModelAdmin):
    list_display = ["reference", "description", "entry_date", "created_by", "created_at"]
    search_fields = ["reference", "description"]
    inlines = [JournalLineInline]
    readonly_fields = ["reference", "description", "entry_date", "reverses", "created_by", "created_at"]

    def has_delete_permission(self, request, obj=None):
        return False

    def has_change_permission(self, request, obj=None):
        return False
