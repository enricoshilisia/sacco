from django.contrib import admin

from .models import Membership, Permission, Role, RolePermission


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
