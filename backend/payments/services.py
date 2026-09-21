import uuid
from datetime import date
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from notifications.services import queue_sms
from savings.services import contribute_shares, deposit_savings

from .models import CollectionPurpose, CollectionStatus, PaymentCollection
from .providers.registry import get_active_payment_provider


def initiate_collection(
    *,
    member,
    amount: Decimal,
    phone_number: str,
    callback_url: str,
    savings_account=None,
    purpose: str = CollectionPurpose.SAVINGS_DEPOSIT,
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

    `savings_account` is required for the default SAVINGS_DEPOSIT purpose
    and ignored for SHARE_CONTRIBUTION (shares have no per-product
    account - CLAUDE.md: share capital != deposits, never conflated).
    """
    if amount <= 0:
        raise ValueError("Collection amount must be positive.")
    if purpose == CollectionPurpose.SAVINGS_DEPOSIT and savings_account is None:
        raise ValueError("savings_account is required for a savings deposit collection.")
    if purpose == CollectionPurpose.REGISTRATION_FEE:
        from members.admission import verification_status

        outstanding = verification_status(member)["fee_outstanding"]
        if outstanding <= 0:
            raise ValueError("There is no registration fee outstanding.")
        if amount > outstanding:
            raise ValueError(f"Only {outstanding} of the registration fee is outstanding.")

    idempotency_key = idempotency_key or f"collect-{uuid.uuid4().hex}"
    existing = PaymentCollection.objects.filter(idempotency_key=idempotency_key).first()
    if existing is not None:
        return existing

    provider = get_active_payment_provider()
    collection = PaymentCollection.objects.create(
        idempotency_key=idempotency_key,
        member=member,
        purpose=purpose,
        savings_account=savings_account if purpose == CollectionPurpose.SAVINGS_DEPOSIT else None,
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

        description = f"{provider_code.title()} collection {receipt or provider_reference}".strip()
        if collection.purpose == CollectionPurpose.WELFARE_CONTRIBUTION:
            # Clears the member's oldest welfare dues first, the rest tops
            # up their yearly welfare balance (welfare.services.record_payment).
            from welfare.models import WelfarePaymentMethod
            from welfare.services import record_payment

            payment = record_payment(
                member=collection.member,
                amount=collection.amount,
                method=WelfarePaymentMethod.MOBILE_MONEY,
                transaction_date=date.today(),
                reference=receipt or provider_reference,
                created_by=collection.created_by,
            )
            collection.welfare_payment = payment
            update_fields = ["status", "provider_receipt", "welfare_payment", "raw_callback", "completed_at"]
            confirmation_target = "welfare contributions"
        elif collection.purpose == CollectionPurpose.REGISTRATION_FEE:
            # One-off, non-refundable: SACCO income (members.admission).
            from members.admission import record_registration_fee
            from members.models import PaymentMethod

            fee = record_registration_fee(
                member=collection.member,
                amount=collection.amount,
                method=PaymentMethod.MOBILE_MONEY,
                paid_on=date.today(),
                reference=receipt or provider_reference,
                idempotency_key=f"collection-{collection.pk}",
                recorded_by=collection.created_by,
            )
            collection.registration_fee = fee
            update_fields = ["status", "provider_receipt", "registration_fee", "raw_callback", "completed_at"]
            confirmation_target = "registration fee"
        elif collection.purpose == CollectionPurpose.SHARE_CONTRIBUTION:
            contribution = contribute_shares(
                member=collection.member,
                amount=collection.amount,
                transaction_date=date.today(),
                created_by=collection.created_by,
                description=description,
            )
            collection.share_contribution = contribution
            update_fields = ["status", "provider_receipt", "share_contribution", "raw_callback", "completed_at"]
            confirmation_target = "share capital"
        else:
            txn = deposit_savings(
                savings_account=collection.savings_account,
                amount=collection.amount,
                transaction_date=date.today(),
                created_by=collection.created_by,
                description=description,
            )
            collection.savings_transaction = txn
            update_fields = ["status", "provider_receipt", "savings_transaction", "raw_callback", "completed_at"]
            confirmation_target = f"{collection.savings_account.product.name} account"

        collection.status = CollectionStatus.SUCCESS
        collection.provider_receipt = receipt
        collection.save(update_fields=update_fields)

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
                    f"{confirmation_target}. Ref {receipt or provider_reference}."
                ),
            )
        )

    return collection
