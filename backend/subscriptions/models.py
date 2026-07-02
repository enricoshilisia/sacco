import uuid
from datetime import timedelta

from django.db import models
from django.utils import timezone

TRIAL_PERIOD_DAYS = 30


class Plan(models.Model):
    """
    A billable plan a SACCO subscribes to. Pricing is a placeholder until
    Phase 7 (Subscriptions/billing) wires up real invoicing through the
    `payments` app - do not treat `monthly_price` as final without
    confirming with whoever owns pricing.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(unique=True)
    monthly_price = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    currency = models.CharField(max_length=3, default="USD")
    is_default = models.BooleanField(
        default=False, help_text="Assigned automatically to new signups."
    )
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class Subscription(models.Model):
    """
    One per tenant (public schema - a SACCO's billing status shouldn't
    require switching into its own schema to check). Starts in TRIALING on
    signup; nothing currently flips it to ACTIVE automatically since real
    billing collection is Phase 3 (payments) + Phase 7 (subscriptions)
    work - for now that's a manual step (Django admin) once payment is
    arranged out of band.
    """

    TRIALING = "trialing"
    ACTIVE = "active"
    PAST_DUE = "past_due"
    SUSPENDED = "suspended"
    CANCELED = "canceled"
    STATUS_CHOICES = [
        (TRIALING, "Trialing"),
        (ACTIVE, "Active"),
        (PAST_DUE, "Past due"),
        (SUSPENDED, "Suspended"),
        (CANCELED, "Canceled"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant = models.OneToOneField(
        "tenants.Tenant", on_delete=models.CASCADE, related_name="subscription"
    )
    plan = models.ForeignKey(Plan, null=True, blank=True, on_delete=models.SET_NULL)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=TRIALING)
    trial_ends_at = models.DateTimeField()
    current_period_end = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @staticmethod
    def default_trial_end():
        return timezone.now() + timedelta(days=TRIAL_PERIOD_DAYS)

    @property
    def is_usable(self) -> bool:
        """Whether this SACCO should currently be able to log in and use the platform."""
        if self.status == self.ACTIVE:
            return True
        if self.status == self.TRIALING:
            return timezone.now() < self.trial_ends_at
        return False

    def __str__(self):
        return f"{self.tenant.name} ({self.status})"
