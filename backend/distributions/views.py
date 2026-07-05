from django.db import connection
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission
from members.models import Member

from .models import DistributionEntry, DistributionRun
from .serializers import (
    DistributionEntrySerializer,
    DistributionRunListSerializer,
    DistributionRunSerializer,
    InitiatePayoutInputSerializer,
    ProposeDividendRunInputSerializer,
    ProposeInterestRunInputSerializer,
    RejectRunInputSerializer,
)
from .services import (
    approve_distribution_run,
    initiate_distribution_payout,
    propose_dividend_run,
    propose_interest_run,
    reject_distribution_run,
)


class DistributionRunListView(generics.ListAPIView):
    queryset = DistributionRun.objects.all()
    serializer_class = DistributionRunListSerializer
    permission_classes = [IsAuthenticated, require_permission("distributions.view")]


class DistributionRunDetailView(generics.RetrieveAPIView):
    queryset = DistributionRun.objects.prefetch_related("entries", "entries__member", "entries__payouts").all()
    serializer_class = DistributionRunSerializer
    permission_classes = [IsAuthenticated, require_permission("distributions.view")]


class ProposeDividendRunView(APIView):
    permission_classes = [IsAuthenticated, require_permission("distributions.run_dividend")]

    def post(self, request):
        serializer = ProposeDividendRunInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            run = propose_dividend_run(created_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(DistributionRunSerializer(run).data, status=status.HTTP_201_CREATED)


class ProposeInterestRunView(APIView):
    permission_classes = [IsAuthenticated, require_permission("distributions.run_interest")]

    def post(self, request):
        serializer = ProposeInterestRunInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            run = propose_interest_run(created_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(DistributionRunSerializer(run).data, status=status.HTTP_201_CREATED)


class ApproveDistributionRunView(APIView):
    permission_classes = [IsAuthenticated, require_permission("distributions.approve_distribution")]

    def post(self, request, pk):
        run = generics.get_object_or_404(DistributionRun, pk=pk)
        try:
            run = approve_distribution_run(run, approved_by=request.user)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(DistributionRunSerializer(run).data)


class RejectDistributionRunView(APIView):
    permission_classes = [IsAuthenticated, require_permission("distributions.approve_distribution")]

    def post(self, request, pk):
        run = generics.get_object_or_404(DistributionRun, pk=pk)
        serializer = RejectRunInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            run = reject_distribution_run(run, rejected_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(DistributionRunSerializer(run).data)


class InitiateDistributionPayoutView(APIView):
    permission_classes = [IsAuthenticated, require_permission("distributions.disburse")]

    def post(self, request, pk):
        entry = generics.get_object_or_404(DistributionEntry, pk=pk)
        serializer = InitiatePayoutInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        phone_number = data.get("phone_number") or entry.member.phone_number
        try:
            initiate_distribution_payout(
                entry=entry,
                phone_number=phone_number,
                idempotency_key=data.get("idempotency_key") or None,
                created_by=request.user,
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        entry.refresh_from_db()
        return Response(DistributionEntrySerializer(entry).data)


class PayoutAllView(APIView):
    """
    Bulk-triggers payout for every POSTED (not yet PAID) entry in an
    APPROVED run, async via Celery - see distributions/tasks.py:
    run_distribution_payouts_task. Returns immediately; poll
    DistributionRunDetailView / DistributionEntrySerializer.latest_payout
    for progress.
    """

    permission_classes = [IsAuthenticated, require_permission("distributions.disburse")]

    def post(self, request, pk):
        run = generics.get_object_or_404(DistributionRun, pk=pk)
        if run.status != "APPROVED":
            return Response({"detail": "Only an approved run can be paid out."}, status=status.HTTP_400_BAD_REQUEST)

        from .tasks import run_distribution_payouts_task

        run_distribution_payouts_task.delay(str(run.id), connection.schema_name, str(request.user.id))
        return Response({"detail": "Payout run queued."}, status=status.HTTP_202_ACCEPTED)


class MyDistributionsListView(generics.ListAPIView):
    """Self-service: a member's own dividend/interest history, ownership
    resolved from request.user (same shape as loans.MyLoansListView)."""

    serializer_class = DistributionEntrySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        member = Member.objects.filter(user=self.request.user).first()
        if member is None:
            return DistributionEntry.objects.none()
        return DistributionEntry.objects.filter(member=member)
