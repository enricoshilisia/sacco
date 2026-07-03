import uuid

from .base import SmsProvider, SmsResult


class MockSmsProvider(SmsProvider):
    """
    Stands in for a real SMS gateway until live credentials exist for
    Africa's Talking or Beem - this environment doesn't have any yet (see
    CLAUDE.md's "confirm rather than guess" rule, applied here to external
    provider credentials rather than a domain fact). Always succeeds and
    never makes a network call, but still exercises the real pipeline -
    NotificationLog, the Celery task, status transitions - for real. This
    is the default active provider for every tenant until an admin
    configures a real one in Settings.
    """

    code = "mock"

    def send_sms(self, *, phone_number: str, message: str) -> SmsResult:
        return SmsResult(success=True, provider_message_id=f"mock-{uuid.uuid4().hex[:12]}")
