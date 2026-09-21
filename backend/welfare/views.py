from django.db import connection, transaction
from rest_framework import generics, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission, user_has_permission
from members.models import Member

from . import services
from .models import (
    WelfareCase,
    WelfareCaseType,
    WelfareContribution,
    WelfarePayment,
    WelfareSettings,
    WelfareYearClose,
)
from .serializers import (
    CreateCaseInputSerializer,
    DecisionInputSerializer,
    MemberBriefSerializer,
    RecordPaymentInputSerializer,
    RecordPayoutInputSerializer,
    RejectInputSerializer,
    WelfareCaseSerializer,
    WelfareCaseTypeSerializer,
    WelfareContributionSerializer,
    WelfarePaymentSerializer,
    WelfareSettingsSerializer,
    WelfareYearCloseSerializer,
    summary_payload,
)
from .tasks import close_welfare_year_task, levy_welfare_case_task

CASE_QUERYSET = WelfareCase.objects.select_related(
    "case_type", "beneficiary", "created_by", "decided_by"
).prefetch_related("contributions", "payouts__recorded_by")


def _require_any(request, *codes):
    if not any(user_has_permission(request.user, code) for code in codes):
        raise PermissionDenied()


def _bad_request(exc):
    return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)


class WelfareSettingsView(APIView):
    """GET: any logged-in user (members see the yearly amount they owe).
    PATCH: welfare.manage_rules."""

    def get_permissions(self):
        if self.request.method == "PATCH":
            return [IsAuthenticated(), require_permission("welfare.manage_rules")()]
        return [IsAuthenticated()]

    def get(self, request):
        return Response(WelfareSettingsSerializer(WelfareSettings.get_solo()).data)

    def patch(self, request):
        serializer = WelfareSettingsSerializer(WelfareSettings.get_solo(), data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class CaseTypeListCreateView(generics.ListCreateAPIView):
    """The constitution's welfare rules. Readable by every member
    (transparency about what each case costs them); editable only with
    welfare.manage_rules."""

    serializer_class = WelfareCaseTypeSerializer
    pagination_class = None

    def get_queryset(self):
        qs = WelfareCaseType.objects.all()
        if self.request.query_params.get("active") == "true":
            qs = qs.filter(is_active=True)
        return qs

    def get_permissions(self):
        if self.request.method == "POST":
            return [IsAuthenticated(), require_permission("welfare.manage_rules")()]
        return [IsAuthenticated()]


class CaseTypeDetailView(generics.RetrieveUpdateAPIView):
    """Rules are deactivated, never deleted - existing cases reference them."""

    queryset = WelfareCaseType.objects.all()
    serializer_class = WelfareCaseTypeSerializer

    def get_permissions(self):
        if self.request.method in ("PUT", "PATCH"):
            return [IsAuthenticated(), require_permission("welfare.manage_rules")()]
        return [IsAuthenticated()]


class CaseListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        _require_any(request, "welfare.view")
        qs = CASE_QUERYSET
        status_filter = request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)
        return Response(WelfareCaseSerializer(qs[:100], many=True).data)

    def post(self, request):
        _require_any(request, "welfare.create_case")
        serializer = CreateCaseInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            case = services.create_case(created_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return _bad_request(exc)
        return Response(WelfareCaseSerializer(CASE_QUERYSET.get(pk=case.pk)).data, status=status.HTTP_201_CREATED)


class CaseDetailView(APIView):
    permission_classes = [IsAuthenticated, require_permission("welfare.view")]

    def get(self, request, pk):
        case = generics.get_object_or_404(CASE_QUERYSET, pk=pk)
        return Response(WelfareCaseSerializer(case).data)


class CaseContributionsView(generics.ListAPIView):
    """Who has paid / still owes for a case."""

    serializer_class = WelfareContributionSerializer
    permission_classes = [IsAuthenticated, require_permission("welfare.view")]

    def get_queryset(self):
        qs = WelfareContribution.objects.filter(case_id=self.kwargs["pk"]).select_related(
            "member", "case__case_type", "case__beneficiary"
        )
        if self.request.query_params.get("outstanding") == "true":
            qs = [c for c in qs if c.outstanding > 0]
        return qs


class ApproveCaseView(APIView):
    permission_classes = [IsAuthenticated, require_permission("welfare.approve_case")]

    def post(self, request, pk):
        case = generics.get_object_or_404(WelfareCase, pk=pk)
        serializer = DecisionInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            case = services.approve_case(case, approved_by=request.user, notes=serializer.validated_data["notes"])
        except ValueError as exc:
            return _bad_request(exc)
        # Levying every member is money math: async, retryable, logged
        # (CLAUDE.md rule 7). Queued after commit so the task sees APPROVED.
        schema = connection.schema_name
        transaction.on_commit(lambda: levy_welfare_case_task.delay(str(case.id), schema))
        return Response(WelfareCaseSerializer(CASE_QUERYSET.get(pk=case.pk)).data)


class RejectCaseView(APIView):
    permission_classes = [IsAuthenticated, require_permission("welfare.approve_case")]

    def post(self, request, pk):
        case = generics.get_object_or_404(WelfareCase, pk=pk)
        serializer = RejectInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            case = services.reject_case(case, rejected_by=request.user, notes=serializer.validated_data["notes"])
        except ValueError as exc:
            return _bad_request(exc)
        return Response(WelfareCaseSerializer(CASE_QUERYSET.get(pk=case.pk)).data)


class CloseCaseView(APIView):
    permission_classes = [IsAuthenticated, require_permission("welfare.record_payout")]

    def post(self, request, pk):
        case = generics.get_object_or_404(WelfareCase, pk=pk)
        try:
            case = services.close_case(case)
        except ValueError as exc:
            return _bad_request(exc)
        return Response(WelfareCaseSerializer(CASE_QUERYSET.get(pk=case.pk)).data)


class RecordPayoutView(APIView):
    permission_classes = [IsAuthenticated, require_permission("welfare.record_payout")]

    def post(self, request, pk):
        case = generics.get_object_or_404(WelfareCase, pk=pk)
        serializer = RecordPayoutInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            services.record_payout(case=case, recorded_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return _bad_request(exc)
        return Response(WelfareCaseSerializer(CASE_QUERYSET.get(pk=case.pk)).data, status=status.HTTP_201_CREATED)


class MemberSearchView(APIView):
    """Pick a beneficiary / payer without needing the broad members.view."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        _require_any(request, "welfare.create_case", "welfare.record_payment", "welfare.view")
        members = services.search_members(request.query_params.get("q", ""))
        return Response(MemberBriefSerializer(members, many=True).data)


class MemberFamilyForCaseView(APIView):
    """A member's approved family register, for choosing who a case is for."""

    permission_classes = [IsAuthenticated]

    def get(self, request, member_id):
        from members.models import FamilyMemberStatus
        from members.profile_serializers import FamilyMemberSerializer

        _require_any(request, "welfare.create_case", "welfare.view")
        member = generics.get_object_or_404(Member, pk=member_id)
        people = member.family.filter(status=FamilyMemberStatus.APPROVED, is_deceased=False)
        return Response(FamilyMemberSerializer(people, many=True).data)


class MemberWelfareView(APIView):
    """Staff view of one member's welfare position (for the counter)."""

    permission_classes = [IsAuthenticated]

    def get(self, request, member_id):
        _require_any(request, "welfare.view", "welfare.record_payment")
        member = generics.get_object_or_404(Member, pk=member_id)
        return Response(_member_payload(member))


class RecordMemberPaymentView(APIView):
    """Counter payment (cash/bank). Mobile-money payments come through
    payments/me/collect/ with purpose WELFARE_CONTRIBUTION instead."""

    permission_classes = [IsAuthenticated, require_permission("welfare.record_payment")]

    def post(self, request, member_id):
        member = generics.get_object_or_404(Member, pk=member_id)
        serializer = RecordPaymentInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            payment = services.record_payment(member=member, created_by=request.user, **serializer.validated_data)
        except ValueError as exc:
            return _bad_request(exc)
        return Response(
            {"payment": WelfarePaymentSerializer(payment).data, **_member_payload(member)},
            status=status.HTTP_201_CREATED,
        )


class MyWelfareView(APIView):
    """Self-service: my welfare balance, what I owe, and my history.
    Ownership is the access check, like every other /me/ endpoint."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        member = Member.objects.filter(user=request.user).first()
        if member is None:
            return Response({"detail": "No member record is linked to this account."}, status=status.HTTP_404_NOT_FOUND)
        return Response(_member_payload(member))


def _member_payload(member):
    contributions = WelfareContribution.objects.filter(member=member).select_related(
        "case__case_type", "case__beneficiary", "member"
    ).order_by("-created_at")[:50]
    payments = WelfarePayment.objects.filter(member=member)[:50]
    return {
        "member": MemberBriefSerializer(member).data,
        "summary": summary_payload(services.member_summary(member)),
        "contributions": WelfareContributionSerializer(contributions, many=True).data,
        "payments": WelfarePaymentSerializer(payments, many=True).data,
    }


class YearCloseListView(generics.ListAPIView):
    queryset = WelfareYearClose.objects.prefetch_related("sweeps")
    serializer_class = WelfareYearCloseSerializer
    permission_classes = [IsAuthenticated, require_permission("welfare.view")]
    pagination_class = None


class CloseYearView(APIView):
    permission_classes = [IsAuthenticated, require_permission("welfare.close_year")]

    def post(self, request, year):
        try:
            year_close = services.start_year_close(year=year, closed_by=request.user)
        except ValueError as exc:
            return _bad_request(exc)
        schema = connection.schema_name
        transaction.on_commit(lambda: close_welfare_year_task.delay(year_close.id, schema))
        return Response(WelfareYearCloseSerializer(year_close).data, status=status.HTTP_202_ACCEPTED)
