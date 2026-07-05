from django.urls import reverse
from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission
from distributions.serializers import DistributionEntrySerializer
from distributions.services import handle_distribution_payout_callback
from loans.serializers import LoanSerializer
from loans.services import handle_loan_disbursement_callback
from members.models import Member
from savings.services import get_or_open_savings_account

from .models import CollectionPurpose, PaymentCollection
from .providers.daraja import DarajaProvider
from .providers.registry import get_active_payment_provider
from .providers.selcom import SelcomProvider
from .serializers import (
    InitiateCollectionInputSerializer,
    MyInitiateCollectionInputSerializer,
    PaymentCollectionSerializer,
)
from .services import handle_collection_callback, initiate_collection

CALLBACK_URL_NAMES = {
    "mock": "payments:mock_callback",
    "daraja": "payments:mpesa_callback",
    "selcom": "payments:selcom_callback",
}


def _my_member(request):
    return Member.objects.filter(user=request.user).first()


class InitiateCollectionView(APIView):
    """Starts a mobile-money collection for one member, into one of their
    savings products (opened on first use, same as a manual deposit)."""

    permission_classes = [IsAuthenticated, require_permission("payments.initiate_collection")]

    def post(self, request, member_id):
        member = generics.get_object_or_404(Member, pk=member_id)
        serializer = InitiateCollectionInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        phone_number = data.get("phone_number") or member.phone_number
        savings_account = get_or_open_savings_account(member, data["product"])

        provider = get_active_payment_provider()
        callback_path = reverse(CALLBACK_URL_NAMES.get(provider.code, "payments:mock_callback"))
        callback_url = request.build_absolute_uri(callback_path)

        try:
            collection = initiate_collection(
                member=member,
                savings_account=savings_account,
                amount=data["amount"],
                phone_number=phone_number,
                callback_url=callback_url,
                idempotency_key=data.get("idempotency_key") or None,
                created_by=request.user,
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(PaymentCollectionSerializer(collection).data, status=status.HTTP_201_CREATED)


class MyInitiateCollectionView(APIView):
    """
    Self-service: a member funding their own share contribution or
    savings deposit via mobile money, from their own dashboard - ownership
    is the check (the member is resolved from request.user), the same
    shape as every other /me/ endpoint in this codebase, needing no
    accesscontrol permission at all. Real money only ever moves once the
    provider confirms via callback (handle_collection_callback) - nothing
    here posts to the ledger directly, so there's no way for a member to
    just self-declare a contribution with no payment behind it.
    """

    permission_classes = [IsAuthenticated, require_permission("payments.initiate_own_collection")]

    def post(self, request):
        member = _my_member(request)
        if member is None:
            return Response(
                {"detail": "No member record is linked to this account."}, status=status.HTTP_404_NOT_FOUND
            )
        serializer = MyInitiateCollectionInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        purpose = data["purpose"]
        savings_account = (
            get_or_open_savings_account(member, data["product"]) if purpose == CollectionPurpose.SAVINGS_DEPOSIT else None
        )

        provider = get_active_payment_provider()
        callback_path = reverse(CALLBACK_URL_NAMES.get(provider.code, "payments:mock_callback"))
        callback_url = request.build_absolute_uri(callback_path)

        try:
            collection = initiate_collection(
                member=member,
                purpose=purpose,
                savings_account=savings_account,
                amount=data["amount"],
                phone_number=data["phone_number"],
                callback_url=callback_url,
                idempotency_key=data.get("idempotency_key") or None,
                created_by=request.user,
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(PaymentCollectionSerializer(collection).data, status=status.HTTP_201_CREATED)


class CollectionListView(generics.ListAPIView):
    queryset = PaymentCollection.objects.select_related("member", "savings_account__product").all()
    serializer_class = PaymentCollectionSerializer
    permission_classes = [IsAuthenticated, require_permission("payments.view_transactions")]


class CollectionDetailView(generics.RetrieveAPIView):
    queryset = PaymentCollection.objects.select_related("member", "savings_account__product").all()
    serializer_class = PaymentCollectionSerializer
    permission_classes = [IsAuthenticated, require_permission("payments.view_transactions")]


class MpesaCallbackView(APIView):
    """
    Daraja STK push callback. Unauthenticated like any real payment
    webhook - reachability is via the tenant's own domain (django-tenants
    resolves the schema the same way it does for every other request to
    that domain), and correctness is via provider_reference correlation +
    idempotent processing in handle_collection_callback, not a login.
    """

    permission_classes = [AllowAny]

    def post(self, request):
        if not DarajaProvider().verify_callback(headers=request.headers, body=request.body):
            return Response(status=status.HTTP_400_BAD_REQUEST)

        stk = request.data.get("Body", {}).get("stkCallback", {})
        checkout_id = stk.get("CheckoutRequestID", "")
        success = stk.get("ResultCode") == 0
        receipt = ""
        if success:
            items = stk.get("CallbackMetadata", {}).get("Item", [])
            receipt = next((i.get("Value") for i in items if i.get("Name") == "MpesaReceiptNumber"), "")

        handle_collection_callback(
            provider_code="daraja",
            provider_reference=checkout_id,
            success=success,
            receipt=str(receipt),
            failure_reason="" if success else stk.get("ResultDesc", ""),
            raw_payload=request.data,
        )
        # Daraja expects this exact ack shape regardless of what we did with it.
        return Response({"ResultCode": 0, "ResultDesc": "Accepted"})


class SelcomCallbackView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        if not SelcomProvider().verify_callback(headers=request.headers, body=request.body):
            return Response(status=status.HTTP_400_BAD_REQUEST)

        order_id = request.data.get("order_id", "")
        success = str(request.data.get("payment_status", "")).upper() == "COMPLETED"
        handle_collection_callback(
            provider_code="selcom",
            provider_reference=order_id,
            success=success,
            receipt=str(request.data.get("reference", "")),
            failure_reason="" if success else str(request.data.get("message", "")),
            raw_payload=request.data,
        )
        return Response({"result": "SUCCESS"})


class MockCallbackView(APIView):
    """
    Manual trigger for the mock provider's callback - lets a test/curl
    script simulate a provider webhook directly, on demand, rather than
    only via the Celery-scheduled simulate_mock_callback_task. Real
    providers never hit this path.
    """

    permission_classes = [AllowAny]

    def post(self, request):
        provider_reference = request.data.get("provider_reference", "")
        success = bool(request.data.get("success", True))
        receipt = request.data.get("receipt", "")
        collection = handle_collection_callback(
            provider_code="mock",
            provider_reference=provider_reference,
            success=success,
            receipt=receipt,
            raw_payload=request.data,
        )
        if collection is None:
            return Response({"detail": "Unknown provider_reference."}, status=status.HTTP_404_NOT_FOUND)
        return Response(PaymentCollectionSerializer(collection).data)


class MockLoanDisbursementCallbackView(APIView):
    """
    Manual trigger for the mock provider's loan-disbursement callback -
    the disbursement-side twin of MockCallbackView above, same purpose
    (let a test/curl script simulate a provider webhook directly rather
    than waiting on the Celery-scheduled simulate_mock_loan_disbursement_
    callback_task). Real providers never hit this path.
    """

    permission_classes = [AllowAny]

    def post(self, request):
        provider_reference = request.data.get("provider_reference", "")
        success = bool(request.data.get("success", True))
        disbursement = handle_loan_disbursement_callback(
            provider_code="mock",
            provider_reference=provider_reference,
            success=success,
            raw_payload=request.data,
        )
        if disbursement is None:
            return Response({"detail": "Unknown provider_reference."}, status=status.HTTP_404_NOT_FOUND)
        return Response(LoanSerializer(disbursement.loan).data)


class MockDistributionPayoutCallbackView(APIView):
    """
    Manual trigger for the mock provider's distribution-payout callback -
    the payout-side twin of MockLoanDisbursementCallbackView above. Real
    providers never hit this path.
    """

    permission_classes = [AllowAny]

    def post(self, request):
        provider_reference = request.data.get("provider_reference", "")
        success = bool(request.data.get("success", True))
        payout = handle_distribution_payout_callback(
            provider_code="mock",
            provider_reference=provider_reference,
            success=success,
            raw_payload=request.data,
        )
        if payout is None:
            return Response({"detail": "Unknown provider_reference."}, status=status.HTTP_404_NOT_FOUND)
        return Response(DistributionEntrySerializer(payout.entry).data)
