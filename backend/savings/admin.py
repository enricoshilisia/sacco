from django.contrib import admin

from .models import SavingsAccount, SavingsProduct, SavingsTransaction, ShareAccount, ShareContribution


@admin.register(SavingsProduct)
class SavingsProductAdmin(admin.ModelAdmin):
    list_display = ["name", "code", "product_type", "interest_rate", "minimum_balance", "is_active"]


@admin.register(ShareAccount)
class ShareAccountAdmin(admin.ModelAdmin):
    list_display = ["member", "opened_at"]

    def has_add_permission(self, request):
        return False


@admin.register(SavingsAccount)
class SavingsAccountAdmin(admin.ModelAdmin):
    list_display = ["account_number", "member", "product", "opened_at", "is_active"]
    search_fields = ["account_number"]

    def has_add_permission(self, request):
        return False


class ReadOnlyMoneyRecordAdmin(admin.ModelAdmin):
    """
    Every field here is set by a service function that also posts the
    matching journal entry (savings/services.py). Allowing admin add/edit
    would let someone create a money record with no journal entry behind
    it, or change one after the fact - both are exactly what CLAUDE.md's
    "never write to a balance directly" / "journal is append-only" rules
    exist to prevent.
    """

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(ShareContribution)
class ShareContributionAdmin(ReadOnlyMoneyRecordAdmin):
    list_display = ["share_account", "amount", "transaction_date", "created_by"]


@admin.register(SavingsTransaction)
class SavingsTransactionAdmin(ReadOnlyMoneyRecordAdmin):
    list_display = ["savings_account", "transaction_type", "amount", "transaction_date", "created_by"]
