from django.contrib import admin

from .models import WelfareCase, WelfareCaseType, WelfareSettings


@admin.register(WelfareCaseType)
class WelfareCaseTypeAdmin(admin.ModelAdmin):
    list_display = ["name", "contribution_per_member", "beneficiary_contributes", "is_active"]


@admin.register(WelfareCase)
class WelfareCaseAdmin(admin.ModelAdmin):
    # Read-only: every money-moving change must go through welfare.services
    # so it posts to the ledger.
    list_display = ["case_type", "beneficiary", "status", "contribution_per_member", "created_at"]
    readonly_fields = [f.name for f in WelfareCase._meta.fields]

    def has_add_permission(self, request):
        return False


admin.site.register(WelfareSettings)
