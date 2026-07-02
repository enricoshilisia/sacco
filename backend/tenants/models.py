from django.db import models
from django_tenants.models import DomainMixin, TenantMixin


class Country(models.TextChoices):
    KENYA = "KE", "Kenya"
    TANZANIA = "TZ", "Tanzania"


class Currency(models.TextChoices):
    KES = "KES", "Kenyan Shilling"
    TZS = "TZS", "Tanzanian Shilling"


# Country -> default currency / default UI language, used when provisioning
# a tenant so we don't hardcode "if country == KE" logic elsewhere.
COUNTRY_DEFAULTS = {
    Country.KENYA: {"currency": Currency.KES, "language": "en"},
    Country.TANZANIA: {"currency": Currency.TZS, "language": "sw"},
}


class Tenant(TenantMixin):
    """One row per SACCO. Each gets its own Postgres schema."""

    name = models.CharField(max_length=255)
    country = models.CharField(max_length=2, choices=Country.choices)
    currency = models.CharField(max_length=3, choices=Currency.choices)
    default_language = models.CharField(max_length=5, default="en")

    # Official SACCO contact details - distinct from any individual
    # member/admin's personal phone or email.
    address = models.TextField(blank=True)
    contact_email = models.EmailField(blank=True)
    contact_phone = models.CharField(max_length=20, blank=True)

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    # django-tenants: auto-create/drop the schema when a Tenant is saved/deleted.
    auto_create_schema = True
    auto_drop_schema = False  # never silently drop a SACCO's data

    def __str__(self):
        return self.name


class Domain(DomainMixin):
    pass
