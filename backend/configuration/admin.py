from django.contrib import admin

from .models import TenantConfig


@admin.register(TenantConfig)
class TenantConfigAdmin(admin.ModelAdmin):
    list_display = ("default_language", "default_loan_multiplier", "active_sms_provider", "active_payment_provider")
