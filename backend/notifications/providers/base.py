from dataclasses import dataclass


@dataclass
class SmsResult:
    success: bool
    provider_message_id: str = ""
    error: str = ""


class SmsProvider:
    """
    Provider-agnostic SMS interface (CLAUDE.md: "swapping providers is a
    config change, never code"). Every adapter below implements exactly
    this, and notifications/providers/registry.py picks which one runs
    based on TenantConfig.active_sms_provider - never an `if country`
    branch in calling code.
    """

    code = "base"

    def send_sms(self, *, phone_number: str, message: str) -> SmsResult:
        raise NotImplementedError
