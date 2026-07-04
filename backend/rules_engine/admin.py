from django.contrib import admin

from .models import LoanEligibilityPolicy


@admin.register(LoanEligibilityPolicy)
class LoanEligibilityPolicyAdmin(admin.ModelAdmin):
    list_display = ("product", "is_active", "require_kyc_verified", "require_crb_check")
