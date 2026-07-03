from dataclasses import dataclass
from decimal import Decimal


@dataclass
class CollectionInitiationResult:
    success: bool
    provider_reference: str = ""
    error: str = ""


class PaymentProvider:
    """
    Provider-agnostic mobile-money interface (CLAUDE.md: `initiate_
    collection()`, `initiate_disbursement()`, and a webhook handler; every
    callback verifies signature, runs in Celery, posts to the ledger, is
    idempotent). Which adapter runs is a per-tenant config switch
    (TenantConfig.active_payment_provider via payments/providers/registry.py),
    never a country branch in calling code.

    initiate_disbursement has no caller yet - Phase 4 (Loans) is the first
    real use - but it's on the interface now so every adapter added later
    has to account for it rather than being retrofitted.
    """

    code = "base"

    def initiate_collection(
        self, *, phone_number: str, amount: Decimal, reference: str, callback_url: str
    ) -> CollectionInitiationResult:
        raise NotImplementedError

    def initiate_disbursement(
        self, *, phone_number: str, amount: Decimal, reference: str
    ) -> CollectionInitiationResult:
        raise NotImplementedError

    def verify_callback(self, *, headers: dict, body: bytes) -> bool:
        """
        Best-effort authenticity check for an inbound webhook. Confidence
        varies by adapter - see each one's own docstring for what's
        actually been verified against live provider documentation versus
        what's a reasonable-but-unconfirmed guess.
        """
        raise NotImplementedError

    def check_status(self, *, provider_reference: str) -> CollectionInitiationResult:
        """
        Query the provider for a PENDING collection's current status - used
        by the reconciliation job (payments/tasks.py:reconcile_pending_collections)
        for collections whose callback never arrived.
        """
        raise NotImplementedError
