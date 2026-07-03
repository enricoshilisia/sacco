import requests
from django.conf import settings

from .base import SmsProvider, SmsResult


class AfricasTalkingProvider(SmsProvider):
    """
    Kenya SMS gateway. Request shape follows Africa's Talking's public SMS
    API docs, but this has NOT been exercised against a live sandbox in
    this session - no AFRICASTALKING_USERNAME/AFRICASTALKING_API_KEY exist
    in this environment yet. Confirm the exact field names against their
    current docs before switching any tenant's active_sms_provider to
    "africastalking" in production.
    """

    code = "africastalking"
    BASE_URL = "https://api.africastalking.com/version1/messaging"

    def send_sms(self, *, phone_number: str, message: str) -> SmsResult:
        api_key = settings.AFRICASTALKING_API_KEY
        username = settings.AFRICASTALKING_USERNAME
        if not api_key or not username:
            return SmsResult(success=False, error="Africa's Talking credentials are not configured.")
        try:
            response = requests.post(
                self.BASE_URL,
                headers={"apiKey": api_key, "Accept": "application/json"},
                data={"username": username, "to": phone_number, "message": message},
                timeout=10,
            )
            response.raise_for_status()
            data = response.json()
            recipients = data.get("SMSMessageData", {}).get("Recipients", [])
            if recipients and recipients[0].get("status") == "Success":
                return SmsResult(success=True, provider_message_id=recipients[0].get("messageId", ""))
            error = recipients[0].get("status") if recipients else "No recipients in response"
            return SmsResult(success=False, error=str(error))
        except requests.RequestException as exc:
            return SmsResult(success=False, error=str(exc))
