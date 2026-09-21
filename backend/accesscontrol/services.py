"""
Admin support: giving people positions/roles and taking them away,
temporary passwords, and switching a login off and on. Every action here
is written to the audit log.
"""

from django.db import connection, transaction

from audit.services import record
from identity.models import TenantAccess, User

from .models import Membership, Role
from .permissions import user_has_permission

# Roles granted automatically elsewhere (approval of a member, a guarantor
# pledge) - never handed out from the positions screen.
AUTOMATIC_ROLES = ["Member", "Guarantor"]
# Holding any of these lets someone hand out access or take over accounts,
# so only a SuperAdmin may reset such a person's password or switch them off.
PRIVILEGED_PERMISSIONS = ["accesscontrol.assign_roles", "users.reset_password", "users.manage_access"]


def tenant_users():
    """Users with a login to this SACCO."""
    return User.objects.filter(tenant_access__tenant__schema_name=connection.schema_name).distinct()


def member_for(user):
    from members.models import Member

    return Member.objects.filter(user=user).first()


def is_super_admin(user) -> bool:
    return Membership.objects.filter(user=user, role__name="SuperAdmin", is_active=True).exists()


def _is_privileged(user) -> bool:
    return any(user_has_permission(user, code) for code in PRIVILEGED_PERMISSIONS)


def _guard_privileged_target(actor, target):
    if target.pk == actor.pk:
        raise PermissionError("You can't do this to your own account.")
    if _is_privileged(target) and not is_super_admin(actor):
        raise PermissionError("Only a SuperAdmin can do this to another administrator.")


def _last_super_admin(membership: Membership) -> bool:
    return (
        membership.role.name == "SuperAdmin"
        and membership.is_active
        and not Membership.objects.filter(role__name="SuperAdmin", is_active=True).exclude(pk=membership.pk).exists()
    )


# --- Positions / roles -------------------------------------------------------


def assert_can_hold(user, role: Role) -> None:
    """New members on probation can't hold office (members.admission)."""
    member = member_for(user)
    if member is not None and role.name not in AUTOMATIC_ROLES and not member.is_verified:
        raise ValueError(
            f"{member.full_name} is a new member on probation, so can't hold a position until verified."
        )


def assign_role(*, role: Role, user, job_title: str = "", by, request=None) -> Membership:
    if role.name in AUTOMATIC_ROLES:
        raise ValueError(f"'{role.name}' is given automatically, not assigned here.")
    if role.name == "SuperAdmin" and not is_super_admin(by):
        raise PermissionError("Only a SuperAdmin can make someone else a SuperAdmin.")
    if not TenantAccess.objects.filter(user=user, tenant__schema_name=connection.schema_name).exists():
        raise ValueError("That person has no login to this SACCO.")
    assert_can_hold(user, role)
    with transaction.atomic():
        role = Role.objects.select_for_update().get(pk=role.pk)
        existing = Membership.objects.filter(user=user, role=role).first()
        if existing is not None and existing.is_active:
            raise ValueError(f"{user.get_full_name()} already holds '{role.name}'.")
        if role.max_holders is not None:
            holders = Membership.objects.filter(role=role, is_active=True).count()
            if holders >= role.max_holders:
                raise ValueError(
                    f"'{role.name}' can have {role.max_holders} holder(s) and is full. Remove someone first."
                )
        if existing is not None:
            existing.is_active = True
            existing.job_title = job_title or existing.job_title
            existing.assigned_by = by
            existing.save(update_fields=["is_active", "job_title", "assigned_by"])
            membership = existing
        else:
            membership = Membership.objects.create(user=user, role=role, job_title=job_title, assigned_by=by)
    record(request=request, user=by, event="access.role_assigned", area="access",
           summary=f"Gave {user.get_full_name()} the position '{role.name}'", target=user,
           target_label=user.get_full_name())
    return membership


def remove_role(*, membership: Membership, by, request=None) -> Membership:
    if membership.role.name in AUTOMATIC_ROLES:
        raise ValueError(f"'{membership.role.name}' is given automatically, not removed here.")
    if not membership.is_active:
        raise ValueError("This person no longer holds that position.")
    if membership.role.name == "SuperAdmin" and not is_super_admin(by):
        raise PermissionError("Only a SuperAdmin can remove a SuperAdmin.")
    if _last_super_admin(membership):
        raise ValueError("This SACCO must always have at least one active SuperAdmin.")
    membership.is_active = False
    membership.save(update_fields=["is_active"])
    user = membership.user
    record(request=request, user=by, event="access.role_removed", area="access",
           summary=f"Removed {user.get_full_name()} from '{membership.role.name}'", target=user,
           target_label=user.get_full_name())
    return membership


def create_position(*, name: str, description: str, max_holders, copy_from: Role | None,
                    assistant_of: Role | None, by, request=None) -> Role:
    name = name.strip()
    if not name:
        raise ValueError("Give the position a name.")
    if Role.objects.filter(name__iexact=name).exists():
        raise ValueError(f"A role called '{name}' already exists.")
    if copy_from is not None and copy_from.name == "SuperAdmin":
        raise ValueError("A new position can't copy SuperAdmin's full access.")
    with transaction.atomic():
        role = Role.objects.create(
            name=name, description=description, is_position=True, max_holders=max_holders,
            assistant_of=assistant_of, sort_order=(assistant_of.sort_order + 1) if assistant_of else 95,
        )
        source = copy_from or assistant_of
        if source is not None:
            role.permissions.set(source.permissions.all())
    record(request=request, user=by, event="access.position_created", area="access",
           summary=f"Created the position '{name}'" + (f" (permissions of {source.name})" if source else ""),
           target=role, target_label=name)
    return role


# --- Passwords & logins ------------------------------------------------------


def reset_password(*, user, by, request=None) -> str:
    """Issues a temporary password (shown once to the admin to hand over).
    The person must choose their own at next sign-in, and every existing
    session of theirs is signed out (CHECK_REVOKE_TOKEN)."""
    from members.admission import generate_temporary_password

    _guard_privileged_target(by, user)
    temporary = generate_temporary_password()
    user.set_password(temporary)
    user.must_change_password = True
    user.save(update_fields=["password", "must_change_password"])
    record(request=request, user=by, event="security.password_reset", area="access",
           summary=f"Reset the password of {user.get_full_name()} ({user.phone_number})", target=user,
           target_label=user.get_full_name())
    return temporary


def set_login_enabled(*, user, enabled: bool, by, request=None) -> TenantAccess:
    _guard_privileged_target(by, user)
    access = TenantAccess.objects.filter(user=user, tenant__schema_name=connection.schema_name).first()
    if access is None:
        raise ValueError("That person has no login to this SACCO.")
    if not enabled:
        for membership in Membership.objects.filter(user=user, role__name="SuperAdmin", is_active=True):
            if _last_super_admin(membership):
                raise ValueError("This SACCO must always have at least one active SuperAdmin.")
    access.is_active = enabled
    access.save(update_fields=["is_active"])
    record(request=request, user=by, event="security.login_enabled" if enabled else "security.login_disabled",
           area="access",
           summary=f"{'Re-enabled' if enabled else 'Disabled'} the login of {user.get_full_name()} ({user.phone_number})",
           target=user, target_label=user.get_full_name())
    return access
