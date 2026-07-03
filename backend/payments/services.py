import uuid
from datetime import date
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from notifications.services import queue_sms
from savings.services import deposit_savings

from .models import CollectionStatus, PaymentCollection
from .providers.registry import get_active_payment_provider


def initiate_collection(
    *,
    member,
    savings_account,
    amount: Decimal,
    phone_number: str,
    callback_url: str,
    idempotency_key: str | None = None,
    created_by=None,
) -> PaymentCollection:
    """
    Starts a mobile-money collection. If the caller supplies an
    idempotency_key that's already been used, returns the EXISTING
    collection instead of starting a second one - CLAUDE.md rule 4:
    "Every collection/disbursement carries an idempotency key." A caller
    that doesn't supply one (e.g. a one-off UI button click) gets a fresh
    key generated, which only protects against retries that explicitly
    reuse it - callers that need retry-safety across their own network
    failures should generate and pass their own key.
    """
    if amount <= 0:
        raise ValueError("Collection amount must be positive.")

    idempotency_key = idempotency_key or f"collect-{uuid.uuid4().hex}"
    existing = PaymentCollection.objects.filter(idempotency_key=idempotency_key).first()
    if existing is not None:
        return existing

    provider = get_active_payment_provider()
    collection = PaymentCollection.objects.create(
        idempotency_key=idempotency_key,
        member=member,
        savings_account=savings_account,
        provider=provider.code,
        phone_number=phone_number,
        amount=amount,
        created_by=created_by,
    )

    result = provider.initiate_collection(
        phone_number=phone_number,
        amount=amount,
        reference=str(collection.id),
        callback_url=callback_url,
    )
    if result.success:
        collection.provider_reference = result.provider_reference
        collection.save(update_fields=["provider_reference"])
    else:
        collection.status = CollectionStatus.FAILED
        collection.failure_reason = result.error
        collection.completed_at = timezone.now()
        collection.save(update_fields=["status", "failure_reason", "completed_at"])
    return collection


def handle_collection_callback(
    *,
    provider_code: str,
    provider_reference: str,
    success: bool,
    receipt: str = "",
    failure_reason: str = "",
    raw_payload=None,
) -> PaymentCollection | None:
    """
    The one place a provider callback (real webhook or the mock's
    simulated one) is allowed to move a PaymentCollection out of PENDING.
    Idempotent by construction: provider callbacks WILL be delivered more
    than once (CLAUDE.md rule 4), so once a collection is already in a
    terminal state this is a no-op that returns it unchanged rather than
    posting to the ledger a second time. select_for_update() closes the
    race where two deliveries of the same callback arrive concurrently and
    both read PENDING before either has written its outcome - the same
    locking pattern savings.services.withdraw_savings uses.
    """
    with transaction.atomic():
        collection = (
            PaymentCollection.objects.select_for_update()
            .filter(provider_reference=provider_reference, provider=provider_code)
            .first()
        )
        if collection is None:
            return None
        if collection.status != CollectionStatus.PENDING:
            return collection

        collection.raw_callback = raw_payload
        collection.completed_at = timezone.now()

        if not success:
            collection.status = CollectionStatus.FAILED
            collection.failure_reason = failure_reason
            collection.save(update_fields=["status", "failure_reason", "raw_callback", "completed_at"])
            return collection

        txn = deposit_savings(
            savings_account=collection.savings_account,
            amount=collection.amount,
            transaction_date=date.today(),
            created_by=collection.created_by,
            description=f"{provider_code.title()} collection {receipt or provider_reference}".strip(),
        )
        collection.status = CollectionStatus.SUCCESS
        collection.provider_receipt = receipt
        collection.savings_transaction = txn
        collection.save(
            update_fields=["status", "provider_receipt", "savings_transaction", "raw_callback", "completed_at"]
        )

        # Deferred to after commit: queuing the Celery send before the row
        # is actually committed risks the notification task running before
        # this transaction's changes are visible to it.
        transaction.on_commit(
            lambda: queue_sms(
                member=collection.member,
                event_type="payment_confirmation",
                recipient=collection.phone_number,
                message=(
                    f"Confirmed. {collection.amount} received into your "
                    f"{collection.savings_account.product.name} account. "
                    f"Ref {receipt or provider_reference}."
                ),
            )
        )

    return collection
