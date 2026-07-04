from configuration.models import TenantConfig

from .base import CrbProvider
from .mock import MockCrbProvider

CRB_PROVIDERS: dict[str, type[CrbProvider]] = {
    "mock": MockCrbProvider,
}


def get_active_crb_provider() -> CrbProvider:
    """
    Reads this tenant's configured CRB provider (TenantConfig.active_crb_
    provider) and instantiates it - config-not-code-branch (CLAUDE.md rule
    6). Falls back to the mock provider for any tenant that hasn't
    configured a real one, which today is every tenant.
    """
    config = TenantConfig.get_solo()
    return get_provider(config.active_crb_provider)


def get_provider(code: str) -> CrbProvider:
    provider_class = CRB_PROVIDERS.get(code) or MockCrbProvider
    return provider_class()
