from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission
from members.models import Member

from .models import SavingsAccount, SavingsProduct
from .serializers import (
    ContributeSharesInputSerializer,
    DepositInputSerializer,
    SavingsAccountSerializer,
    SavingsProductSerializer,
    SavingsTransactionSerializer,
    ShareAccountSerializer,
    ShareContributionSerializer,
    WithdrawInputSerializer,
)
from .services import (
    InsufficientBalance,
    contribute_shares,
    deposit_savings,
    get_or_open_savings_account,
    get_or_open_share_account,
    withdraw_savings,
)


class SavingsProductListCreateView(generics.ListCreateAPIView):
    queryset = SavingsProduct.objects.all()
    serializer_class = SavingsProductSerializer

    def get_permissions(self):
        code = "savings.manage_products" if self.request.method == "POST" else "savings.view"
        return [IsAuthenticated(), require_permission(code)()]


class MemberStatementView(APIView):
    """
    Combined share + savings statement for one member - balances plus full
    transaction history for each. The savings balances here are derived the
    same way the trial balance derives control-account totals (sum of this
    member's JournalLines), so this is exactly the reconciliation check the
    Phase 2 "done when" criterion asks for, not a separately-maintained number.
    """

    permission_classes = [IsAuthenticated, require_permission("savings.view")]

    def get(self, request, member_id):
        member = generics.get_object_or_404(Member, pk=member_id)
        share_account = get_or_open_share_account(member)

        savings_accounts = SavingsAccount.objects.filter(member=member).select_related("product")

        return Response(
            {
                "shares": {
                    **ShareAccountSerializer(share_account).data,
                    "contributions": ShareContributionSerializer(
                        share_account.contributions.order_by("-transaction_date"), many=True
                    ).data,
                },
                "savings_accounts": [
                    {
                        **SavingsAccountSerializer(acc).data,
                        "transactions": SavingsTransactionSerializer(
                            acc.transactions.order_by("-transaction_date"), many=True
                        ).data,
                    }
                    for acc in savings_accounts
                ],
            }
        )


class ContributeSharesView(APIView):
    permission_classes = [IsAuthenticated, require_permission("savings.deposit")]

    def post(self, request, member_id):
        member = generics.get_object_or_404(Member, pk=member_id)
        serializer = ContributeSharesInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            contribution = contribute_shares(member=member, created_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(ShareContributionSerializer(contribution).data, status=status.HTTP_201_CREATED)


class DepositSavingsView(APIView):
    permission_classes = [IsAuthenticated, require_permission("savings.deposit")]

    def post(self, request, member_id):
        member = generics.get_object_or_404(Member, pk=member_id)
        serializer = DepositInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        product = data.pop("product")
        savings_account = get_or_open_savings_account(member, product)
        try:
            txn = deposit_savings(savings_account=savings_account, created_by=request.user, **data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(SavingsTransactionSerializer(txn).data, status=status.HTTP_201_CREATED)


class WithdrawSavingsView(APIView):
    permission_classes = [IsAuthenticated, require_permission("savings.withdraw")]

    def post(self, request, member_id):
        member = generics.get_object_or_404(Member, pk=member_id)
        serializer = WithdrawInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        savings_account = data.pop("savings_account")
        if savings_account.member_id != member.id:
            return Response(
                {"detail": "This savings account does not belong to this member."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            txn = withdraw_savings(savings_account=savings_account, created_by=request.user, **data)
        except InsufficientBalance as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(SavingsTransactionSerializer(txn).data, status=status.HTTP_201_CREATED)
