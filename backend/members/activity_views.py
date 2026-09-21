from django.utils import timezone
from rest_framework import generics, serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission

from . import activity
from .models import InactivityFlag, Member, MemberActivitySettings, MemberStatus

MANAGE = "members.approve_changes"  # the Secretary (plus Branch Manager, SuperAdmin)


class ActivitySettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = MemberActivitySettings
        fields = [
            "contribution_rule_enabled", "warn_after_months", "inactive_after_months", "min_monthly_contribution",
            "meeting_rule_enabled", "warn_after_meetings", "inactive_after_meetings", "last_run_at",
        ]
        read_only_fields = ["last_run_at"]

    def validate(self, attrs):
        s = self.instance
        warn_m = attrs.get("warn_after_months", s.warn_after_months)
        limit_m = attrs.get("inactive_after_months", s.inactive_after_months)
        warn_g = attrs.get("warn_after_meetings", s.warn_after_meetings)
        limit_g = attrs.get("inactive_after_meetings", s.inactive_after_meetings)
        if limit_m < 1 or limit_g < 1:
            raise serializers.ValidationError("Limits must be at least 1.")
        if warn_m >= limit_m or warn_g >= limit_g:
            raise serializers.ValidationError("The warning must come before the limit.")
        return attrs


class FlagSerializer(serializers.ModelSerializer):
    member_id = serializers.UUIDField(source="member.id", read_only=True)
    member_number = serializers.CharField(source="member.member_number", read_only=True)
    member_name = serializers.CharField(source="member.full_name", read_only=True)
    member_phone = serializers.CharField(source="member.phone_number", read_only=True)
    reason_label = serializers.CharField(source="get_reason_display", read_only=True)
    decided_by_name = serializers.CharField(source="decided_by.get_full_name", read_only=True, default=None)

    class Meta:
        model = InactivityFlag
        fields = [
            "id", "member_id", "member_number", "member_name", "member_phone", "reason", "reason_label", "detail",
            "status", "created_at", "decided_by_name", "decided_at", "notes",
        ]


class ActivitySettingsView(APIView):
    permission_classes = [IsAuthenticated, require_permission(MANAGE)]

    def get(self, request):
        return Response(ActivitySettingsSerializer(MemberActivitySettings.get_solo()).data)

    def patch(self, request):
        serializer = ActivitySettingsSerializer(MemberActivitySettings.get_solo(), data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class RunActivityCheckView(APIView):
    """Run the monthly check now (it also runs on the 1st of each month)."""

    permission_classes = [IsAuthenticated, require_permission(MANAGE)]

    def post(self, request):
        result = activity.run_activity_check()
        settings = MemberActivitySettings.get_solo()
        settings.last_run_at = timezone.now()
        settings.save(update_fields=["last_run_at"])
        return Response(result)


class FlagListView(generics.ListAPIView):
    serializer_class = FlagSerializer
    permission_classes = [IsAuthenticated, require_permission(MANAGE)]

    def get_queryset(self):
        return InactivityFlag.objects.select_related("member", "decided_by").filter(
            status=self.request.query_params.get("status", InactivityFlag.PENDING)
        )


class FlagDecisionView(APIView):
    permission_classes = [IsAuthenticated, require_permission(MANAGE)]
    confirm = True

    def post(self, request, pk):
        flag = generics.get_object_or_404(InactivityFlag, pk=pk)
        notes = request.data.get("notes", "")
        try:
            if self.confirm:
                flag = activity.confirm_flag(flag, confirmed_by=request.user, notes=notes)
            else:
                if not notes.strip():
                    return Response({"detail": "Say why you're keeping them active."}, status=status.HTTP_400_BAD_REQUEST)
                flag = activity.dismiss_flag(flag, dismissed_by=request.user, notes=notes)
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(FlagSerializer(flag).data)


class DormantMembersView(APIView):
    permission_classes = [IsAuthenticated, require_permission(MANAGE)]

    def get(self, request):
        rows = []
        for member in Member.objects.filter(status=MemberStatus.DORMANT).prefetch_related("status_changes"):
            change = member.status_changes.first()
            rows.append({
                "member_id": member.pk, "member_number": member.member_number, "member_name": member.full_name,
                "since": change.changed_at if change else None, "reason": change.reason if change else "",
            })
        return Response(rows)


class ReactivateMemberView(APIView):
    permission_classes = [IsAuthenticated, require_permission(MANAGE)]

    def post(self, request, pk):
        member = generics.get_object_or_404(Member, pk=pk)
        try:
            activity.reactivate(member, by=request.user, reason=request.data.get("reason") or "Reactivated by the Secretary")
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"status": MemberStatus.ACTIVE})


class MyActivityView(APIView):
    """A member's own standing: status and how close they are to a limit."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        member = Member.objects.filter(user=request.user).first()
        if member is None:
            return Response({"detail": "No member record is linked to this account."}, status=status.HTTP_404_NOT_FOUND)
        settings = MemberActivitySettings.get_solo()
        result = activity.evaluate_member(member, settings=settings)
        return Response({
            "status": member.status,
            "missed_months": result["months"],
            "inactive_after_months": settings.inactive_after_months if settings.contribution_rule_enabled else None,
            "missed_meetings": result["meetings"],
            "inactive_after_meetings": settings.inactive_after_meetings if settings.meeting_rule_enabled else None,
        })
