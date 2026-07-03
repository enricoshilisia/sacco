from configuration.models import TenantConfig

from .base import PaymentProvider
from .daraja import DarajaProvider
from .mock import MockPaymentProvider
from .selcom import SelcomProvider

PAYMENT_PROVIDERS: dict[str, type[PaymentProvider]] = {
    "mock": MockPaymentProvider,
    "daraja": DarajaProvider,
    "selcom": SelcomProvider,
}


def get_active_payment_provider() -> PaymentProvider:
    """
    Reads this tenant's configured provider (TenantConfig.active_payment_
    provider) and instantiates it - config-not-code-branch (CLAUDE.md rule
    6). Falls back to the mock provider for any tenant that hasn't
    configured a real one, which today is every tenant.
    """
    config = TenantConfig.get_solo()
    return get_provider(config.active_payment_provider)


def get_provider(code: str) -> PaymentProvider:
    provider_class = PAYMENT_PROVIDERS.get(code) or MockPaymentProvider
    return provider_class()
