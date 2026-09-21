from rest_framework import serializers

from .models import AttendanceStatus, Meeting, MeetingAttendance, MeetingType


class MeetingSerializer(serializers.ModelSerializer):
    meeting_type_label = serializers.CharField(source="get_meeting_type_display", read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    counts = serializers.SerializerMethodField()
    my_attendance = serializers.SerializerMethodField()

    class Meta:
        model = Meeting
        fields = [
            "id", "meeting_type", "meeting_type_label", "title", "scheduled_at", "venue", "agenda",
            "counts_for_attendance", "status", "status_label", "notice_sent_at", "closed_at", "counts", "my_attendance",
        ]

    def get_counts(self, meeting):
        counts = {s: 0 for s in AttendanceStatus.values}
        for status in meeting.attendance.values_list("status", flat=True):
            counts[status] += 1
        return counts

    def get_my_attendance(self, meeting):
        member = self.context.get("member")
        if member is None:
            return None
        record = next((a for a in meeting.attendance.all() if a.member_id == member.pk), None)
        return {"status": record.status, "apology_reason": record.apology_reason} if record else None


class ScheduleMeetingSerializer(serializers.Serializer):
    meeting_type = serializers.ChoiceField(choices=MeetingType.choices)
    title = serializers.CharField(max_length=200)
    scheduled_at = serializers.DateTimeField()
    venue = serializers.CharField(max_length=200, required=False, allow_blank=True, default="")
    agenda = serializers.CharField(required=False, allow_blank=True, default="")
    send_notice = serializers.BooleanField(required=False, default=True)


class AttendanceRowSerializer(serializers.Serializer):
    """One row of the register: every expected member, with their mark (if any)."""

    member_id = serializers.UUIDField()
    member_number = serializers.CharField()
    full_name = serializers.CharField()
    status = serializers.CharField(allow_null=True)
    apology_reason = serializers.CharField(allow_blank=True)


class RecordAttendanceSerializer(serializers.Serializer):
    entries = serializers.ListField(child=serializers.DictField(), allow_empty=False)

    def validate_entries(self, entries):
        for entry in entries:
            if entry.get("status") not in AttendanceStatus.values:
                raise serializers.ValidationError(f"Unknown status: {entry.get('status')}")
            if not entry.get("member"):
                raise serializers.ValidationError("Each entry needs a member.")
        return entries


class MeetingAttendanceSerializer(serializers.ModelSerializer):
    class Meta:
        model = MeetingAttendance
        fields = ["member", "status", "apology_reason"]
