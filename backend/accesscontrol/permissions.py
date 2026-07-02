from rest_framework.permissions import BasePermission

from .models import Membership


def user_has_permission(user, code: str) -> bool:
    """Does this user hold an active Membership whose Role grants `code` in the current schema?"""
    return Membership.objects.filter(
        user=user, is_active=True, role__permissions__code=code
    ).exists()


def require_permission(code: str):
    """
    DRF permission class factory, e.g.:
        permission_classes = [IsAuthenticated, require_permission("members.create")]
    Checked against the RBAC catalog seeded in
    accesscontrol/migrations/0003_seed_default_permissions_and_roles.py.
    """

    class _RequiresPermission(BasePermission):
        message = f"You don't have the '{code}' permission for this SACCO."

        def has_permission(self, request, view):
            return bool(request.user and request.user.is_authenticated) and user_has_permission(
                request.user, code
            )

    _RequiresPermission.__name__ = f"Requires_{code.replace('.', '_')}"
    return _RequiresPermission
