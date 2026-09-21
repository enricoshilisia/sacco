from decimal import Decimal

from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission

from .models import Account, JournalEntry
from .serializers import (
    AccountBalanceSerializer,
    AccountSerializer,
    JournalEntrySerializer,
    ManualJournalInputSerializer,
)
from .services import LineInput, UnbalancedJournalEntry, post_journal_entry, reverse_journal_entry


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
    """GET: the journal, newest first. POST: a manual journal entry
    (accounting.post_journal) - expenses, fees, bank charges and other
    entries no module posts for you. Still balanced and append-only."""

    serializer_class = JournalEntrySerializer

    def get_queryset(self):
        return (
            JournalEntry.objects.select_related("created_by", "reverses", "reversed_by")
            .prefetch_related("lines", "lines__account", "lines__member")
            .order_by("-entry_date", "-created_at")
        )

    def get_permissions(self):
        code = "accounting.post_journal" if self.request.method == "POST" else "accounting.view_ledger"
        return [IsAuthenticated(), require_permission(code)()]

    def post(self, request):
        serializer = ManualJournalInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            entry = post_journal_entry(
                description=data["description"],
                entry_date=data["entry_date"],
                lines=[
                    LineInput(account=l["account"], debit=l["debit"], credit=l["credit"], description=l["description"])
                    for l in data["lines"]
                ],
                created_by=request.user,
            )
        except UnbalancedJournalEntry as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(JournalEntrySerializer(entry).data, status=status.HTTP_201_CREATED)


class AccountListCreateView(generics.ListCreateAPIView):
    """Chart of accounts. Adding accounts (e.g. a new expense line) needs
    accounting.manage_chart; accounts are deactivated, never deleted."""

    queryset = Account.objects.all()
    serializer_class = AccountSerializer
    pagination_class = None

    def get_permissions(self):
        if self.request.method == "POST":
            return [IsAuthenticated(), require_permission("accounting.manage_chart")()]
        return [IsAuthenticated(), require_permission("accounting.view_ledger")()]


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
