from django.contrib import admin

from .models import Loan, LoanGuarantor, LoanProduct


@admin.register(LoanProduct)
class LoanProductAdmin(admin.ModelAdmin):
    list_display = ("name", "code", "interest_method", "interest_rate", "is_active")


class LoanGuarantorInline(admin.TabularInline):
    model = LoanGuarantor
    extra = 0
    fields = ("guarantor", "pledged_amount", "status", "requested_at", "responded_at", "released_at")
    readonly_fields = fields
    can_delete = False

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(Loan)
class LoanAdmin(admin.ModelAdmin):
    list_display = ("member", "product", "amount_requested", "status", "applied_at")
    list_filter = ("status", "product")
    search_fields = ("member__first_name", "member__last_name", "member__member_number")
    inlines = [LoanGuarantorInline]
    readonly_fields = [f.name for f in Loan._meta.fields]

    def has_add_permission(self, request):
        # Only ever created via loans.services.apply_for_loan, so the state
        # machine (status transitions, guarantor pledge locking) is never
        # bypassed by a hand-edited row - same principle as JournalEntry.
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
