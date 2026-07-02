import uuid

from django.conf import settings
from django.db import models


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
