import base64

import requests
from django.conf import settings

from .base import SmsProvider, SmsResult


class BeemProvider(SmsProvider):
    """
    Tanzania SMS gateway (Beem Africa). Request shape follows Beem's public
    SMS API docs, but this has NOT been exercised against a live sandbox in
    this session - no BEEM_API_KEY/BEEM_SECRET_KEY exist in this
    environment yet. Confirm the exact field names against their current
    docs before switching any tenant's active_sms_provider to "beem" in
    production.
    """

    code = "beem"
    BASE_URL = "https://apisms.beem.africa/v1/send"

    def send_sms(self, *, phone_number: str, message: str) -> SmsResult:
        api_key = settings.BEEM_API_KEY
        secret_key = settings.BEEM_SECRET_KEY
        if not api_key or not secret_key:
            return SmsResult(success=False, error="Beem credentials are not configured.")
        auth = base64.b64encode(f"{api_key}:{secret_key}".encode()).decode()
        try:
            response = requests.post(
                self.BASE_URL,
                headers={"Authorization": f"Basic {auth}", "Content-Type": "application/json"},
                json={
                    "source_addr": settings.BEEM_SOURCE_ADDR,
                    "encoding": 0,
                    "message": message,
                    "recipients": [{"recipient_id": 1, "dest_addr": phone_number}],
                },
                timeout=10,
            )
            response.raise_for_status()
            data = response.json()
            if data.get("successful"):
                return SmsResult(success=True, provider_message_id=str(data.get("request_id", "")))
            return SmsResult(success=False, error=str(data))
        except requests.RequestException as exc:
            return SmsResult(success=False, error=str(exc))
