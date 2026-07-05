import uuid

from .base import CollectionInitiationResult, PaymentProvider


class MockPaymentProvider(PaymentProvider):
    """
    Stands in for Daraja/Selcom until live sandbox credentials exist in
    this environment. initiate_collection/initiate_disbursement both
    succeed immediately and schedule a short-delayed simulated callback
    through the exact same idempotent processing path a real provider's
    webhook would hit (payments/tasks.py:simulate_mock_callback_task /
    simulate_mock_loan_disbursement_callback_task /
    simulate_mock_distribution_payout_callback_task, chosen by
    initiate_disbursement's `kind`) - so the full async round trip
    (initiate -> provider confirms -> ledger posts -> notification fires)
    is proven for real via Celery, not faked as a synchronous shortcut.

    Testing hook only: a phone number ending in "0000" simulates a
    declined collection/disbursement instead of a success, so both
    outcomes are reachable without a real provider. This is the default
    active provider for every tenant until an admin configures a real one.
    """

    code = "mock"

    def initiate_collection(self, *, phone_number, amount, reference, callback_url) -> CollectionInitiationResult:
        from django.db import connection

        from .. import tasks

        provider_reference = f"MOCK-{uuid.uuid4().hex[:10].upper()}"
        should_succeed = not phone_number.endswith("0000")
        tasks.simulate_mock_callback_task.apply_async(
            args=[connection.schema_name, provider_reference, should_succeed],
            countdown=2,
        )
        return CollectionInitiationResult(success=True, provider_reference=provider_reference)

    def initiate_disbursement(self, *, phone_number, amount, reference, kind: str = "loan") -> CollectionInitiationResult:
        from django.db import connection

        from .. import tasks

        provider_reference = f"MOCK-{uuid.uuid4().hex[:10].upper()}"
        should_succeed = not phone_number.endswith("0000")
        task = (
            tasks.simulate_mock_distribution_payout_callback_task
            if kind == "distribution"
            else tasks.simulate_mock_loan_disbursement_callback_task
        )
        task.apply_async(
            args=[connection.schema_name, provider_reference, should_succeed],
            countdown=2,
        )
        return CollectionInitiationResult(success=True, provider_reference=provider_reference)

    def verify_callback(self, *, headers, body) -> bool:
        return True

    def check_status(self, *, provider_reference: str) -> CollectionInitiationResult:
        # The mock always resolves itself via its own scheduled callback
        # within seconds, so there's nothing genuinely stuck to reconcile.
        return CollectionInitiationResult(success=False, error="Still pending (mock resolves on its own).")
