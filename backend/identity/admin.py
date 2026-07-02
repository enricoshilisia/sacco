from django.contrib import admin

from .models import PushDeviceToken, TenantAccess, User, WebAuthnCredential


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("phone_number", "email", "first_name", "last_name", "preferred_language", "is_active", "is_staff")
    search_fields = ("phone_number", "email", "first_name", "last_name")


@admin.register(TenantAccess)
class TenantAccessAdmin(admin.ModelAdmin):
    list_display = ("user", "tenant", "is_active", "joined_at")
    list_filter = ("tenant", "is_active")


@admin.register(WebAuthnCredential)
class WebAuthnCredentialAdmin(admin.ModelAdmin):
    list_display = ("user", "device_name", "sign_count", "created_at", "last_used_at")


@admin.register(PushDeviceToken)
class PushDeviceTokenAdmin(admin.ModelAdmin):
    list_display = ("user", "platform", "is_active", "updated_at")
    list_filter = ("platform", "is_active")
