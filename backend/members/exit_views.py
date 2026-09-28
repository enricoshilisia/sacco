"""Leaving the group, and suspension."""

from datetime import date

from django.shortcuts import get_object_or_404
from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission, user_has_permission
from audit.services import record

from . import exit_services
from .models import Member, Resignation, ResignationStatus


def _bad(exc, code=status.HTTP_400_BAD_REQUEST):
    return Response({"detail": str(exc)}, status=code)


def _money(values: dict) -> dict:
    return {k: (str(v) if hasattr(v, "quantize") else v) for k, v in values.items()}


class ResignationSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source="member.full_name", read_only=True)
    member_number = serializers.CharField(source="member.member_number", read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    requested_by_name = serializers.SerializerMethodField()
    decided_by_name = serializers.SerializerMethodField()
    can_pay_now = serializers.SerializerMethodField()

    class Meta:
        model = Resignation
        fields = [
            "id", "member", "member_name", "member_number", "status", "status_label", "reason",
            "notice_given_on", "leaving_on", "requested_by", "requested_by_name", "created_at",
            "decided_by_name", "decided_at", "decision_notes", "savings_at_exit", "refund_percent",
            "debts_deducted", "refund_paid", "retained_by_group", "paid_on", "can_pay_now",
        ]

    def get_requested_by_name(self, r):
        return r.requested_by.get_full_name() if r.requested_by else ""

    def get_decided_by_name(self, r):
        return r.decided_by.get_full_name() if r.decided_by else ""

    def get_can_pay_now(self, r):
        return r.status == ResignationStatus.APPROVED and r.leaving_on <= date.today()


class MyExitQuoteView(APIView):
    """What leaving would mean for me: notice, refund, and what I owe."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        member = Member.objects.filter(user=request.user).first()
        if member is None:
            return Response({"detail": "No member record is linked to this login."}, status=status.HTTP_404_NOT_FOUND)
        mine = member.resignations.exclude(
            status__in=[ResignationStatus.CANCELLED, ResignationStatus.REJECTED]
        ).first()
        return Response({
            **_money(exit_services.exit_quote(member)),
            "resignation": ResignationSerializer(mine).data if mine else None,
        })

    def post(self, request):
        """Give notice."""
        member = Member.objects.filter(user=request.user).first()
        if member is None:
            return Response({"detail": "No member record is linked to this login."}, status=status.HTTP_404_NOT_FOUND)
        try:
            resignation = exit_services.give_notice(
                member=member, reason=str(request.data.get("reason", "")), by=request.user
            )
        except ValueError as exc:
            return _bad(exc)
        record(request=request, event="members.notice_given", area="members",
               summary=f"{member.full_name} gave notice to leave on {resignation.leaving_on}",
               target=resignation, target_label=member.full_name)
        return Response(ResignationSerializer(resignation).data, status=status.HTTP_201_CREATED)


class ResignationListView(APIView):
    """The committee's list. ?status=NOTICE|APPROVED|PAID, ?due=1 for the
    ones whose notice has run out."""

    permission_classes = [IsAuthenticated, require_permission("members.view")]

    def get(self, request):
        qs = Resignation.objects.select_related("member", "requested_by", "decided_by")
        if request.query_params.get("status"):
            qs = qs.filter(status=request.query_params["status"])
        if request.query_params.get("due") in ("1", "true"):
            qs = exit_services.due_for_refund()
        return Response(ResignationSerializer(qs, many=True).data)

    def post(self, request):
        """Staff recording a notice a member gave in person."""
        if not user_has_permission(request.user, "members.approve_changes"):
            return _bad("You can't record a resignation.", status.HTTP_403_FORBIDDEN)
        member = get_object_or_404(Member, pk=request.data.get("member"))
        try:
            resignation = exit_services.give_notice(
                member=member, reason=str(request.data.get("reason", "")), by=request.user
            )
        except ValueError as exc:
            return _bad(exc)
        record(request=request, event="members.notice_given", area="members",
               summary=f"Recorded {member.full_name}'s notice to leave on {resignation.leaving_on}",
               target=resignation, target_label=member.full_name)
        return Response(ResignationSerializer(resignation).data, status=status.HTTP_201_CREATED)


class ResignationDecisionView(APIView):
    """approve / reject a notice (never your own)."""

    permission_classes = [IsAuthenticated, require_permission("members.approve_admission")]
    approve = True

    def post(self, request, pk):
        resignation = get_object_or_404(Resignation.objects.select_related("member"), pk=pk)
        try:
            exit_services.decide_notice(resignation=resignation, approve=self.approve, by=request.user,
                                        notes=str(request.data.get("notes", "")))
        except ValueError as exc:
            return _bad(exc)
        record(request=request, event=f"members.notice_{'approved' if self.approve else 'rejected'}", area="members",
               summary=f"{'Approved' if self.approve else 'Rejected'} {resignation.member.full_name}'s notice",
               target=resignation, target_label=resignation.member.full_name)
        return Response(ResignationSerializer(Resignation.objects.get(pk=pk)).data)


class ResignationCancelView(APIView):
    """A member who changes their mind (or staff cancelling on their behalf)."""

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        resignation = get_object_or_404(Resignation.objects.select_related("member"), pk=pk)
        mine = resignation.member.user_id == request.user.pk
        if not mine and not user_has_permission(request.user, "members.approve_changes"):
            return _bad("You can't cancel this notice.", status.HTTP_403_FORBIDDEN)
        try:
            exit_services.cancel_notice(resignation=resignation, by=request.user,
                                        reason=str(request.data.get("reason", "")))
        except ValueError as exc:
            return _bad(exc)
        record(request=request, event="members.notice_cancelled", area="members",
               summary=f"Cancelled {resignation.member.full_name}'s notice to leave", target=resignation,
               target_label=resignation.member.full_name)
        return Response(ResignationSerializer(Resignation.objects.get(pk=pk)).data)


class ResignationPayoutView(APIView):
    """Pay the leaver out once the notice has run (Treasurer)."""

    permission_classes = [IsAuthenticated, require_permission("payments.initiate_disbursement")]

    def get(self, request, pk):
        resignation = get_object_or_404(Resignation.objects.select_related("member"), pk=pk)
        return Response(_money(exit_services.exit_quote(resignation.member)))

    def post(self, request, pk):
        resignation = get_object_or_404(Resignation.objects.select_related("member"), pk=pk)
        try:
            exit_services.pay_refund(
                resignation=resignation, by=request.user, method=str(request.data.get("method", "CASH")),
                reference=str(request.data.get("reference", "")),
            )
        except ValueError as exc:
            return _bad(exc)
        resignation.refresh_from_db()
        record(request=request, event="members.exit_paid", area="members",
               summary=(f"Paid {resignation.member.full_name} {resignation.refund_paid} on leaving "
                        f"({resignation.refund_percent}% of {resignation.savings_at_exit})"),
               target=resignation, target_label=resignation.member.full_name)
        return Response(ResignationSerializer(resignation).data)


class SuspendMemberView(APIView):
    """Suspension: {days, reason}. Lifting it is the same endpoint with
    {lift: true}."""

    permission_classes = [IsAuthenticated, require_permission("fines.waive")]

    def post(self, request, pk):
        member = get_object_or_404(Member, pk=pk)
        try:
            if request.data.get("lift"):
                exit_services.lift_suspension(member=member, by=request.user,
                                              reason=str(request.data.get("reason", "Lifted by the committee")))
                summary = f"Lifted {member.full_name}'s suspension"
            else:
                exit_services.suspend(member=member, days=int(request.data.get("days", 90)),
                                      reason=str(request.data.get("reason", "")), by=request.user)
                summary = f"Suspended {member.full_name} until {member.suspended_until}"
        except (ValueError, TypeError) as exc:
            return _bad(exc)
        record(request=request, event="members.suspension", area="members", summary=summary, target=member,
               target_label=member.full_name)
        return Response({"status": member.status, "suspended_until": member.suspended_until,
                         "reason": member.suspension_reason})
