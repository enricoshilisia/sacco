from decimal import Decimal

from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission

from .models import Account, JournalEntry
from .serializers import AccountBalanceSerializer, JournalEntrySerializer
from .services import reverse_journal_entry


class TrialBalanceView(APIView):
    """
    Every active account's signed balance, plus whether debits and credits
    reconcile across the whole ledger - the "done when" check for this
    phase (CLAUDE.md / BUILD_PLAN.md): the trial balance must balance.
    """

    permission_classes = [IsAuthenticated, require_permission("accounting.view_trial_balance")]

    def get(self, request):
        accounts = Account.objects.filter(is_active=True)
        rows = [{"account": a, "balance": a.balance()} for a in accounts]
        total_debit_side = sum(
            (r["balance"] for r in rows if r["account"].account_type in ("ASSET", "EXPENSE")),
            Decimal("0"),
        )
        total_credit_side = sum(
            (r["balance"] for r in rows if r["account"].account_type not in ("ASSET", "EXPENSE")),
            Decimal("0"),
        )
        return Response(
            {
                "accounts": AccountBalanceSerializer([r["account"] for r in rows], many=True).data,
                "total_debit_side": str(total_debit_side),
                "total_credit_side": str(total_credit_side),
                "balanced": total_debit_side == total_credit_side,
            }
        )


class JournalEntryListView(generics.ListAPIView):
    queryset = JournalEntry.objects.prefetch_related("lines", "lines__account", "lines__member").all()
    serializer_class = JournalEntrySerializer
    permission_classes = [IsAuthenticated, require_permission("accounting.view_ledger")]


class JournalEntryReverseView(APIView):
    permission_classes = [IsAuthenticated, require_permission("accounting.reverse_journal")]

    def post(self, request, pk):
        entry = generics.get_object_or_404(JournalEntry, pk=pk)
        reason = request.data.get("reason", "")
        if not reason:
            return Response({"detail": "A reason is required."}, status=status.HTTP_400_BAD_REQUEST)
        try:
            reversal = reverse_journal_entry(entry, reason=reason, created_by=request.user)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(JournalEntrySerializer(reversal).data, status=status.HTTP_201_CREATED)
