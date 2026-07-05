from django.contrib import admin

from .models import DistributionEntry, DistributionPayout, DistributionRun


class DistributionEntryInline(admin.TabularInline):
    model = DistributionEntry
    extra = 0
    fields = ("member", "basis_balance", "gross_amount", "wht_amount", "net_amount", "status")
    readonly_fields = fields
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(DistributionRun)
class DistributionRunAdmin(admin.ModelAdmin):
    list_display = ("kind", "savings_product", "period_start", "period_end", "rate", "status", "proposed_at")
    list_filter = ("kind", "status")
    inlines = [DistributionEntryInline]
    readonly_fields = [f.name for f in DistributionRun._meta.fields]

    def has_add_permission(self, request):
        # Only ever created via distributions.services.propose_dividend_run/
        # propose_interest_run, same principle as loans/accounting admin -
        # a hand-edited row would bypass the maker-checker state machine.
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


class ReadOnlyMoneyRecordAdmin(admin.ModelAdmin):
    """Every field here is set by a service function that also posts the
    matching journal entry - same principle as loans/admin.py's
    ReadOnlyMoneyRecordAdmin."""

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(DistributionPayout)
class DistributionPayoutAdmin(ReadOnlyMoneyRecordAdmin):
    list_display = ("entry", "provider", "amount", "status", "created_at")
    list_filter = ("status", "provider")
