from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission
from members.models import Member

from . import services
from .models import Meeting, MeetingStatus
from .serializers import MeetingSerializer, RecordAttendanceSerializer, ScheduleMeetingSerializer

MEETINGS = Meeting.objects.prefetch_related("attendance")


def _bad(exc):
    return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)


def _my_member(request):
    return Member.objects.filter(user=request.user).first()


class MeetingListCreateView(APIView):
    """GET: meetings (governance.view - members see them too, with their own
    attendance). POST: schedule one (governance.call_meeting)."""

    def get_permissions(self):
        code = "governance.call_meeting" if self.request.method == "POST" else "governance.view"
        return [IsAuthenticated(), require_permission(code)()]

    def get(self, request):
        qs = MEETINGS
        when = request.query_params.get("when")
        if when == "upcoming":
            qs = qs.filter(status=MeetingStatus.SCHEDULED).order_by("scheduled_at")
        elif when == "past":
            qs = qs.exclude(status=MeetingStatus.SCHEDULED)
        return Response(MeetingSerializer(qs[:50], many=True, context={"member": _my_member(request)}).data)

    def post(self, request):
        data = ScheduleMeetingSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        try:
            meeting = services.schedule_meeting(created_by=request.user, **data.validated_data)
        except ValueError as exc:
            return _bad(exc)
        return Response(MeetingSerializer(meeting).data, status=status.HTTP_201_CREATED)


class MeetingRegisterView(APIView):
    """GET: the register - every expected member and their mark.
    POST: record marks (governance.take_attendance)."""

    def get_permissions(self):
        return [IsAuthenticated(), require_permission("governance.take_attendance")()]

    def get(self, request, pk):
        meeting = generics.get_object_or_404(Meeting, pk=pk)
        marks = {a.member_id: a for a in meeting.attendance.all()}
        people = {m.pk: m for m in services.expected_members(meeting)}
        # Include anyone already marked even if no longer expected (e.g. since archived).
        for member_id in marks.keys() - people.keys():
            people[member_id] = marks[member_id].member
        rows = [
            {
                "member_id": m.pk, "member_number": m.member_number, "full_name": m.full_name,
                # New members on probation attend but can't vote.
                "is_verified": m.is_verified,
                "status": marks[m.pk].status if m.pk in marks else None,
                "apology_reason": marks[m.pk].apology_reason if m.pk in marks else "",
            }
            for m in sorted(people.values(), key=lambda m: m.member_number)
        ]
        return Response({"meeting": MeetingSerializer(meeting).data, "rows": rows})

    def post(self, request, pk):
        meeting = generics.get_object_or_404(Meeting, pk=pk)
        data = RecordAttendanceSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        members = {str(m.pk): m for m in Member.objects.filter(pk__in=[e["member"] for e in data.validated_data["entries"]])}
        entries = [
            {"member": members[str(e["member"])], "status": e["status"], "apology_reason": e.get("apology_reason", "")}
            for e in data.validated_data["entries"]
            if str(e["member"]) in members
        ]
        try:
            count = services.record_attendance(meeting=meeting, entries=entries, recorded_by=request.user)
        except ValueError as exc:
            return _bad(exc)
        return Response({"recorded": count})


class CloseRegisterView(APIView):
    permission_classes = [IsAuthenticated, require_permission("governance.take_attendance")]

    def post(self, request, pk):
        meeting = generics.get_object_or_404(Meeting, pk=pk)
        try:
            absent = services.close_register(meeting=meeting, closed_by=request.user)
        except ValueError as exc:
            return _bad(exc)
        return Response({"marked_absent": absent, "meeting": MeetingSerializer(MEETINGS.get(pk=pk)).data})


class CancelMeetingView(APIView):
    permission_classes = [IsAuthenticated, require_permission("governance.call_meeting")]

    def post(self, request, pk):
        meeting = generics.get_object_or_404(Meeting, pk=pk)
        try:
            services.cancel_meeting(meeting=meeting)
        except ValueError as exc:
            return _bad(exc)
        return Response(MeetingSerializer(MEETINGS.get(pk=pk)).data)


class MyApologyView(APIView):
    """A member sending an apology for a meeting they can't attend."""

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        member = _my_member(request)
        if member is None:
            return Response({"detail": "No member record is linked to this account."}, status=status.HTTP_404_NOT_FOUND)
        meeting = generics.get_object_or_404(Meeting, pk=pk)
        try:
            services.send_apology(meeting=meeting, member=member, reason=request.data.get("reason", ""))
        except ValueError as exc:
            return _bad(exc)
        return Response(MeetingSerializer(MEETINGS.get(pk=pk), context={"member": member}).data)
