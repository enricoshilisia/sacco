import hashlib
import hmac
import json
from decimal import Decimal

import requests
from django.conf import settings

from .base import CollectionInitiationResult, PaymentProvider


class SelcomProvider(PaymentProvider):
    """
    Tanzania mobile money (Selcom). This adapter is a structural
    placeholder: Selcom's checkout-order API shape is less certain in this
    session than Daraja's - do NOT enable this in production without
    confirming the exact request/response field names and signing
    mechanism against Selcom's current merchant API documentation first.
    Wired to the same interface as every other provider so switching it on
    later is a config change, not new plumbing.
    """

    code = "selcom"
    BASE_URL = "https://apigw.selcommobile.com"

    def _headers(self, body: bytes) -> dict:
        digest = hmac.new(settings.SELCOM_API_SECRET.encode(), body, hashlib.sha256).hexdigest()
        return {
            "Content-Type": "application/json",
            "Authorization": f"SELCOM {settings.SELCOM_API_KEY}",
            "Digest-Method": "HS256",
            "Digest": digest,
        }

    def initiate_collection(
        self, *, phone_number: str, amount: Decimal, reference: str, callback_url: str
    ) -> CollectionInitiationResult:
        if not settings.SELCOM_API_KEY or not settings.SELCOM_VENDOR_ID:
            return CollectionInitiationResult(success=False, error="Selcom credentials are not configured.")
        payload = {
            "vendor": settings.SELCOM_VENDOR_ID,
            "order_id": reference,
            "buyer_phone": phone_number,
            "amount": str(amount),
            "currency": "TZS",
            "webhook": callback_url,
        }
        body = json.dumps(payload).encode()
        try:
            response = requests.post(
                f"{self.BASE_URL}/v1/checkout/create-order-minimal",
                headers=self._headers(body),
                data=body,
                timeout=15,
            )
            response.raise_for_status()
            data = response.json()
            if data.get("result") == "SUCCESS":
                return CollectionInitiationResult(success=True, provider_reference=reference)
            return CollectionInitiationResult(success=False, error=data.get("message", "Selcom order failed"))
        except requests.RequestException as exc:
            return CollectionInitiationResult(success=False, error=str(exc))

    def initiate_disbursement(self, *, phone_number, amount, reference) -> CollectionInitiationResult:
        raise NotImplementedError("Selcom disbursement isn't wired up yet - see Phase 4.")

    def verify_callback(self, *, headers: dict, body: bytes) -> bool:
        # Selcom signs webhooks with a Digest header using the same
        # HMAC-SHA256 scheme as outbound requests, per their docs - NOT
        # verified against a live callback in this session. Confirm the
        # exact header name/casing before relying on this in production.
        digest_header = headers.get("Digest", "")
        expected = hmac.new(settings.SELCOM_API_SECRET.encode(), body, hashlib.sha256).hexdigest()
        return hmac.compare_digest(digest_header, expected)

    def check_status(self, *, provider_reference: str) -> CollectionInitiationResult:
        raise NotImplementedError("Selcom order-status polling isn't wired up yet - confirm their query endpoint first.")
