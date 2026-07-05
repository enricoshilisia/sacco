from datetime import timedelta

from celery import shared_task
from django.utils import timezone
from django_tenants.utils import schema_context


@shared_task
def simulate_mock_callback_task(tenant_schema: str, provider_reference: str, success: bool):
    """
    The mock provider's stand-in for a real STK-push/checkout callback -
    runs in a Celery worker a couple seconds after initiation, exercising
    the exact same idempotent processing path a real webhook would hit.
    """
    with schema_context(tenant_schema):
        from .services import handle_collection_callback

        handle_collection_callback(
            provider_code="mock",
            provider_reference=provider_reference,
            success=success,
            receipt=f"MOCKRCPT{provider_reference[-6:]}" if success else "",
            failure_reason="" if success else "Simulated decline (mock phone number ending in 0000).",
            raw_payload={"simulated": True, "success": success},
        )


@shared_task
def simulate_mock_loan_disbursement_callback_task(tenant_schema: str, provider_reference: str, success: bool):
    """
    Loan-disbursement counterpart to simulate_mock_callback_task above -
    same "resolve a couple seconds later, through the real idempotent
    processing path" shape, just calling loans.services instead of
    payments.services since disbursement money and journal postings belong
    to the loans app, not this one (loans/services.py:
    handle_loan_disbursement_callback).
    """
    with schema_context(tenant_schema):
        from loans.services import handle_loan_disbursement_callback

        handle_loan_disbursement_callback(
            provider_code="mock",
            provider_reference=provider_reference,
            success=success,
            failure_reason="" if success else "Simulated decline (mock phone number ending in 0000).",
            raw_payload={"simulated": True, "success": success},
        )


@shared_task
def simulate_mock_distribution_payout_callback_task(tenant_schema: str, provider_reference: str, success: bool):
    """
    Distribution-payout counterpart to simulate_mock_loan_disbursement_
    callback_task above - same "resolve a couple seconds later, through
    the real idempotent processing path" shape, calling distributions.
    services since payout money and journal postings belong to the
    distributions app, not this one (distributions/services.py:
    handle_distribution_payout_callback).
    """
    with schema_context(tenant_schema):
        from distributions.services import handle_distribution_payout_callback

        handle_distribution_payout_callback(
            provider_code="mock",
            provider_reference=provider_reference,
            success=success,
            failure_reason="" if success else "Simulated decline (mock phone number ending in 0000).",
            raw_payload={"simulated": True, "success": success},
        )


@shared_task
def reconcile_pending_collections():
    """
    Periodic job (BUILD_PLAN.md Phase 3: "daily reconciliation job") - for
    every active tenant, re-checks any collection still PENDING past the
    window a real STK push/checkout should have resolved in, in case a
    callback was lost. Registered via
    `python manage.py seed_periodic_tasks` (see
    payments/management/commands/seed_periodic_tasks.py) rather than a
    per-tenant migration: the schedule is one global Celery Beat row -
    django_celery_beat lives in the public schema, not per-tenant data -
    while the task body itself loops every tenant's own PENDING rows.
    """
    from tenants.models import Tenant

    from .models import CollectionStatus, PaymentCollection
    from .providers.registry import get_provider
    from .services import handle_collection_callback

    cutoff = timezone.now() - timedelta(minutes=10)
    for tenant in Tenant.objects.filter(is_active=True):
        with schema_context(tenant.schema_name):
            stuck = PaymentCollection.objects.filter(status=CollectionStatus.PENDING, created_at__lt=cutoff)
            for collection in stuck:
                provider = get_provider(collection.provider)
                try:
                    result = provider.check_status(provider_reference=collection.provider_reference)
                except NotImplementedError:
                    continue
                if result.success:
                    handle_collection_callback(
                        provider_code=collection.provider,
                        provider_reference=collection.provider_reference,
                        success=True,
                        receipt=result.provider_reference,
                        raw_payload={"reconciled": True},
                    )
