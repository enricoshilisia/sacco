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


def build_member_statement(member) -> dict:
    """
    Combined share + savings statement for one member - balances plus full
    transaction history for each. The savings balances here are derived the
    same way the trial balance derives control-account totals (sum of this
    member's JournalLines), so this is exactly the reconciliation check the
    Phase 2 "done when" criterion asks for, not a separately-maintained
    number. Shared by the staff-facing MemberStatementView (any member_id,
    gated by savings.view) and the self-service MyStatementView (always
    request.user's own member, no permission-catalog check needed) so the
    two can never drift out of sync with each other.
    """
    share_account = get_or_open_share_account(member)
    savings_accounts = SavingsAccount.objects.filter(member=member).select_related("product")

    return {
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


class MemberStatementView(APIView):
    """Staff-facing: any member_id, gated by savings.view."""

    permission_classes = [IsAuthenticated, require_permission("savings.view")]

    def get(self, request, member_id):
        member = generics.get_object_or_404(Member, pk=member_id)
        return Response(build_member_statement(member))


class MyStatementView(APIView):
    """
    Self-service: always request.user's own statement, never gated by
    savings.view - ownership is the access check (see members.views.
    MyMemberView for the same pattern applied to the member record itself).
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        member = Member.objects.filter(user=request.user).first()
        if member is None:
            return Response(
                {"detail": "No member record is linked to this account."}, status=status.HTTP_404_NOT_FOUND
            )
        return Response(build_member_statement(member))


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
