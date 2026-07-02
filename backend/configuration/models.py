import uuid

from django.db import models


class IdType(models.TextChoices):
    NATIONAL_ID = "NATIONAL_ID", "National ID"
    HUDUMA = "HUDUMA", "Huduma Namba"
    NIDA = "NIDA", "NIDA (Tanzania)"
    PASSPORT = "PASSPORT", "Passport"


class TenantConfig(models.Model):
    """
    One row per tenant schema (a singleton within that schema). Everything
    that differs by country - ID type, tax placeholders, loan multiplier,
    which SMS/payment provider is active - lives here as data, never as an
    `if country == "KE"` branch in business logic.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    default_language = models.CharField(
        max_length=5, choices=[("en", "English"), ("sw", "Kiswahili")], default="en"
    )

    allowed_id_types = models.JSONField(
        default=list, help_text="e.g. ['NATIONAL_ID', 'HUDUMA'] for a Kenyan tenant"
    )

    # Member number style - each SACCO defines its own (e.g. "SHK-" + 5
    # digits, or "M" + 4 digits); member creation reuses this automatically.
    # next_sequence is incremented atomically under a row lock at creation
    # time (see members/services.py) so numbers never collide or reuse a
    # deleted member's number.
    member_number_prefix = models.CharField(max_length=20, default="M-")
    member_number_padding = models.PositiveSmallIntegerField(
        default=5, help_text="Digits to zero-pad the sequence to, e.g. 5 -> 00001"
    )
    member_number_next_sequence = models.PositiveIntegerField(default=1)

    # Loan multiplier default (e.g. 3.0 == borrow up to 3x deposits).
    # Actual loan products can override this per-product in Phase 4.
    default_loan_multiplier = models.DecimalField(max_digits=6, decimal_places=2, default=3)

    # Withholding tax placeholders - config only, always flagged for a tax
    # adviser to confirm current values before relying on them.
    wht_dividends_rate = models.DecimalField(max_digits=5, decimal_places=4, default=0)
    wht_interest_rate = models.DecimalField(max_digits=5, decimal_places=4, default=0)
    wht_rates_confirmed_by_tax_adviser = models.BooleanField(default=False)

    # Provider selection - "config, never a code branch" (CLAUDE.md rule 6).
    active_sms_provider = models.CharField(max_length=30, default="")
    sms_provider_backup = models.CharField(max_length=30, default="africastalking")
    active_payment_provider = models.CharField(max_length=30, default="")

    feature_flags = models.JSONField(default=dict, blank=True)

    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Tenant configuration"
        verbose_name_plural = "Tenant configuration"

    def __str__(self):
        return "Tenant configuration"

    @classmethod
    def get_solo(cls):
        """Get this tenant's singleton config row, creating it with defaults if missing."""
        obj = cls.objects.first()
        if obj is None:
            obj = cls.objects.create()
        return obj
