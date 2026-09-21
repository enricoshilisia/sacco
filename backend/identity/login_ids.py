"""What people may type in the login box: their phone number in any
common form (+254711..., 254711..., 0711...) or their member number."""

import re

from django.db import connection
from django_tenants.utils import get_public_schema_name

# Country calling codes, keyed like Tenant.country (data, not branches).
CALLING_CODES = {"KE": "254", "TZ": "255", "UG": "256", "RW": "250"}


def _calling_code() -> str | None:
    from tenants.models import Tenant

    tenant = Tenant.objects.filter(schema_name=connection.schema_name).only("country").first()
    return CALLING_CODES.get(getattr(tenant, "country", "") or "")


def normalize_phone(raw: str) -> str:
    digits = re.sub(r"[^\d+]", "", raw or "")
    if digits.startswith("+"):
        return digits
    code = _calling_code()
    if code and digits.startswith(code):
        return "+" + digits
    if code and digits.startswith("0") and len(digits) >= 10:
        return f"+{code}{digits[1:]}"
    return digits


def resolve_login_id(raw: str) -> str:
    """Returns the phone number (the login identity) for what was typed.
    Member numbers are looked up in this SACCO only."""
    value = (raw or "").strip()
    if not value or connection.schema_name == get_public_schema_name():
        return value
    looks_like_phone = re.fullmatch(r"\+?[\d\s\-()]{9,}", value) is not None
    if not looks_like_phone:
        from members.models import Member

        member = Member.objects.filter(member_number__iexact=value).select_related("user").first()
        if member is not None and member.user_id:
            return member.user.phone_number
        return value
    return normalize_phone(value)
