import re

from django.conf import settings
from django.utils.text import slugify

from .models import COUNTRY_DEFAULTS, Domain, Tenant

# Postgres schema identifiers: lowercase, start with a letter, only
# letters/digits/underscore, keep well under the 63-char limit.
_SCHEMA_SAFE_RE = re.compile(r"[^a-z0-9_]+")


def slugify_for_schema(name: str) -> str:
    base = _SCHEMA_SAFE_RE.sub("_", slugify(name).replace("-", "_"))[:40].strip("_")
    return base or "sacco"


def unique_schema_and_domain(name: str) -> tuple[str, str]:
    """Derive a free schema_name/domain pair from a SACCO's display name."""
    base = slugify_for_schema(name)
    base_domain = getattr(settings, "TENANT_BASE_DOMAIN", "localhost")

    schema_name = base
    suffix = 1
    while Tenant.objects.filter(schema_name=schema_name).exists():
        suffix += 1
        schema_name = f"{base}{suffix}"

    domain_slug = schema_name.replace("_", "-")
    domain = f"{domain_slug}.{base_domain}"
    suffix = 1
    while Domain.objects.filter(domain=domain).exists():
        suffix += 1
        domain = f"{domain_slug}-{suffix}.{base_domain}"

    return schema_name, domain


def provision_tenant(
    *,
    name: str,
    schema_name: str,
    domain: str,
    country: str,
    address: str = "",
    contact_email: str = "",
    contact_phone: str = "",
) -> Tenant:
    """
    Core tenant-creation logic shared by the `provision_tenant` management
    command and the public SACCO signup endpoint. Creating the Tenant row
    triggers django-tenants' auto_create_schema, which synchronously
    migrates the new schema (including the RBAC seed data migration), so a
    Tenant returned from here already has its default roles/permissions.
    """
    if Tenant.objects.filter(schema_name=schema_name).exists():
        raise ValueError(f"Tenant with schema '{schema_name}' already exists")

    defaults = COUNTRY_DEFAULTS[country]
    tenant = Tenant.objects.create(
        schema_name=schema_name,
        name=name,
        country=country,
        currency=defaults["currency"],
        default_language=defaults["language"],
        address=address,
        contact_email=contact_email,
        contact_phone=contact_phone,
    )
    Domain.objects.create(domain=domain, tenant=tenant, is_primary=True)
    return tenant
