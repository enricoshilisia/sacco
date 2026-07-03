from configuration.models import TenantConfig

from .africastalking import AfricasTalkingProvider
from .base import SmsProvider
from .beem import BeemProvider
from .mock import MockSmsProvider

SMS_PROVIDERS: dict[str, type[SmsProvider]] = {
    "mock": MockSmsProvider,
    "africastalking": AfricasTalkingProvider,
    "beem": BeemProvider,
}


def get_active_sms_provider() -> SmsProvider:
    """
    Reads this tenant's configured provider (TenantConfig.active_sms_provider)
    and instantiates it - the config-not-code-branch switch CLAUDE.md
    requires. Falls back to the mock provider for any tenant that hasn't
    configured a real one (which today is every tenant - no live SMS
    credentials exist in this environment yet).
    """
    config = TenantConfig.get_solo()
    provider_class = SMS_PROVIDERS.get(config.active_sms_provider) or MockSmsProvider
    return provider_class()
