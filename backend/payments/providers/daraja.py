import base64
from datetime import datetime
from decimal import Decimal

import requests
from django.conf import settings

from .base import CollectionInitiationResult, PaymentProvider


class DarajaProvider(PaymentProvider):
    """
    Kenya M-Pesa (Safaricom Daraja API), STK Push (Lipa na M-Pesa Online).
    Request/response shape follows Daraja's public documentation, but this
    has NOT been exercised against a live sandbox in this session - no
    DARAJA_CONSUMER_KEY/SECRET/SHORTCODE/PASSKEY exist in this environment
    yet. Confirm against Safaricom's current docs before switching any
    tenant's active_payment_provider to "daraja" in production.
    """

    code = "daraja"

    def _base_url(self) -> str:
        return (
            "https://sandbox.safaricom.co.ke" if settings.DARAJA_ENV == "sandbox" else "https://api.safaricom.co.ke"
        )

    def _access_token(self) -> str:
        auth = base64.b64encode(f"{settings.DARAJA_CONSUMER_KEY}:{settings.DARAJA_CONSUMER_SECRET}".encode()).decode()
        response = requests.get(
            f"{self._base_url()}/oauth/v1/generate?grant_type=client_credentials",
            headers={"Authorization": f"Basic {auth}"},
            timeout=10,
        )
        response.raise_for_status()
        return response.json()["access_token"]

    def initiate_collection(
        self, *, phone_number: str, amount: Decimal, reference: str, callback_url: str
    ) -> CollectionInitiationResult:
        if not settings.DARAJA_CONSUMER_KEY or not settings.DARAJA_SHORTCODE:
            return CollectionInitiationResult(success=False, error="Daraja credentials are not configured.")
        try:
            token = self._access_token()
            timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
            password = base64.b64encode(
                f"{settings.DARAJA_SHORTCODE}{settings.DARAJA_PASSKEY}{timestamp}".encode()
            ).decode()
            response = requests.post(
                f"{self._base_url()}/mpesa/stkpush/v1/processrequest",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "BusinessShortCode": settings.DARAJA_SHORTCODE,
                    "Password": password,
                    "Timestamp": timestamp,
                    "TransactionType": "CustomerPayBillOnline",
                    "Amount": int(amount),
                    "PartyA": phone_number,
                    "PartyB": settings.DARAJA_SHORTCODE,
                    "PhoneNumber": phone_number,
                    "CallBackURL": callback_url,
                    "AccountReference": reference[:12],
                    "TransactionDesc": "SACCO savings deposit",
                },
                timeout=15,
            )
            response.raise_for_status()
            data = response.json()
            if data.get("ResponseCode") == "0":
                return CollectionInitiationResult(success=True, provider_reference=data["CheckoutRequestID"])
            return CollectionInitiationResult(success=False, error=data.get("ResponseDescription", "STK push failed"))
        except requests.RequestException as exc:
            return CollectionInitiationResult(success=False, error=str(exc))

    def initiate_disbursement(self, *, phone_number, amount, reference, kind: str = "loan") -> CollectionInitiationResult:
        # B2C (Business to Customer) - callers exist now (loan disbursement,
        # distribution payouts) but left unimplemented rather than guessed
        # at without a concrete requirement to design a real integration against.
        raise NotImplementedError("Daraja B2C disbursement isn't wired up yet - see Phase 4.")

    def verify_callback(self, *, headers: dict, body: bytes) -> bool:
        # Daraja callbacks aren't HMAC-signed the way e.g. a typical
        # webhook provider's are; Safaricom's own guidance is to restrict
        # the callback URL by IP allowlist at the network level instead.
        # The real correlation guard is that handle_collection_callback
        # only acts on a CheckoutRequestID matching a PENDING collection
        # this tenant actually issued.
        return True

    def check_status(self, *, provider_reference: str) -> CollectionInitiationResult:
        if not settings.DARAJA_CONSUMER_KEY:
            return CollectionInitiationResult(success=False, error="Daraja credentials are not configured.")
        try:
            token = self._access_token()
            timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
            password = base64.b64encode(
                f"{settings.DARAJA_SHORTCODE}{settings.DARAJA_PASSKEY}{timestamp}".encode()
            ).decode()
            response = requests.post(
                f"{self._base_url()}/mpesa/stkpushquery/v1/query",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "BusinessShortCode": settings.DARAJA_SHORTCODE,
                    "Password": password,
                    "Timestamp": timestamp,
                    "CheckoutRequestID": provider_reference,
                },
                timeout=15,
            )
            response.raise_for_status()
            data = response.json()
            if data.get("ResultCode") == "0":
                return CollectionInitiationResult(success=True, provider_reference=provider_reference)
            return CollectionInitiationResult(success=False, error=data.get("ResultDesc", "Still pending"))
        except requests.RequestException as exc:
            return CollectionInitiationResult(success=False, error=str(exc))
