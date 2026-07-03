import secrets
import uuid
from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone


class Permission(models.Model):
    """
    A single, fine-grained capability, e.g. "loans.approve" or
    "savings.withdraw". Custom (not Django's contrib.auth Permission) because
    RBAC here needs to be tenant-schema-scoped, business-domain-shaped, and
    independent of Django's model-level permission machinery.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    code = models.CharField(max_length=100, unique=True)  # "loans.approve"
    category = models.CharField(max_length=50)  # "loans"
    label = models.CharField(max_length=255)
    description = models.TextField(blank=True)

    class Meta:
        ordering = ["category", "code"]

    def __str__(self):
        return self.code


class Role(models.Model):
    """
    A named bundle of permissions, scoped to this tenant's schema. System
    roles ship as sane defaults (Teller, LoanOfficer, BoardMember, ...);
    SACCOs can also define their own custom roles and committees.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    is_system = models.BooleanField(
        default=False, help_text="Seeded default role; cannot be deleted from the UI."
    )
    permissions = models.ManyToManyField(Permission, through="RolePermission", related_name="roles")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class RolePermission(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    role = models.ForeignKey(Role, on_delete=models.CASCADE)
    permission = models.ForeignKey(Permission, on_delete=models.CASCADE)

    class Meta:
        unique_together = ("role", "permission")


class Membership(models.Model):
    """
    A user's role assignment within this tenant. One user can hold multiple
    roles at once (e.g. an ordinary Member who is also a BoardMember), so
    this is deliberately not a one-row-per-user table.

    `user` is a FK into the shared public schema (identity.User); django-tenants
    supports cross-schema FKs from a tenant table into a public one.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="memberships")
    role = models.ForeignKey(Role, on_delete=models.PROTECT, related_name="memberships")

    # Free-text display title (e.g. "General Manager", "Treasurer") -
    # distinct from `role`, which drives RBAC permissions.
    job_title = models.CharField(max_length=100, blank=True)

    is_active = models.BooleanField(default=True)
    assigned_at = models.DateTimeField(auto_now_add=True)
    assigned_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )

    class Meta:
        unique_together = ("user", "role")

    def __str__(self):
        return f"{self.user} as {self.role}"


def _generate_invite_token():
    return secrets.token_urlsafe(32)


def _default_invite_expiry():
    return timezone.now() + timedelta(days=7)


class StaffInvite(models.Model):
    """
    A pending invitation for someone to join this SACCO's staff/governance
    roster under a specific role. No User/Membership row exists until the
    invite is accepted (accesscontrol/views.py:StaffInviteAcceptView) - that
    keeps "actually has access" and "merely invited" from being conflated.

    The token stands in for the SMS/email delivery Phase 3 (notifications)
    will add; until then an admin copies the setup link and shares it
    out of band.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    token = models.CharField(max_length=64, unique=True, default=_generate_invite_token, editable=False)

    phone_number = models.CharField(max_length=20)
    email = models.EmailField(blank=True, null=True)
    first_name = models.CharField(max_length=150)
    last_name = models.CharField(max_length=150)
    job_title = models.CharField(max_length=100, blank=True)
    role = models.ForeignKey(Role, on_delete=models.PROTECT, related_name="invites")

    invited_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(default=_default_invite_expiry)
    accepted_at = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Invite for {self.phone_number} as {self.role.name}"

    @property
    def status(self) -> str:
        if self.accepted_at:
            return "accepted"
        if self.revoked_at:
            return "revoked"
        if self.expires_at <= timezone.now():
            return "expired"
        return "pending"
