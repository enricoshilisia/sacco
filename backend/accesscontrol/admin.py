from django.contrib import admin

from .models import Membership, Permission, Role, RolePermission, StaffInvite


class RolePermissionInline(admin.TabularInline):
    model = RolePermission
    extra = 1


@admin.register(Permission)
class PermissionAdmin(admin.ModelAdmin):
    list_display = ("code", "category", "label")
    search_fields = ("code", "category", "label")
    list_filter = ("category",)


@admin.register(Role)
class RoleAdmin(admin.ModelAdmin):
    list_display = ("name", "is_system", "created_at")
    inlines = [RolePermissionInline]


@admin.register(Membership)
class MembershipAdmin(admin.ModelAdmin):
    list_display = ("user", "role", "is_active", "assigned_at")
    list_filter = ("role", "is_active")


@admin.register(StaffInvite)
class StaffInviteAdmin(admin.ModelAdmin):
    list_display = ("phone_number", "first_name", "last_name", "role", "status", "created_at", "expires_at")
    list_filter = ("role",)
    search_fields = ("phone_number", "first_name", "last_name", "email")
    readonly_fields = ("token", "accepted_at")
