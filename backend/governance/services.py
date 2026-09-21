from django.db import transaction
from django.utils import timezone

from members.models import Member, MemberStatus
from notifications.services import queue_sms

from .models import GENERAL_MEETINGS, AttendanceStatus, Meeting, MeetingAttendance, MeetingStatus


def expected_members(meeting: Meeting):
    """Who the register covers: every active member for a general meeting.
    Members who joined after the meeting aren't expected at it."""
    return Member.objects.filter(status=MemberStatus.ACTIVE, date_joined__lte=meeting.scheduled_at.date())


def schedule_meeting(*, meeting_type, title, scheduled_at, venue="", agenda="", created_by=None, send_notice=True) -> Meeting:
    if scheduled_at <= timezone.now():
        raise ValueError("A meeting must be scheduled in the future.")
    meeting = Meeting.objects.create(
        meeting_type=meeting_type, title=title, scheduled_at=scheduled_at, venue=venue, agenda=agenda,
        counts_for_attendance=meeting_type in GENERAL_MEETINGS, created_by=created_by,
    )
    if send_notice and meeting_type in GENERAL_MEETINGS:
        send_notice_sms(meeting)
    return meeting


def send_notice_sms(meeting: Meeting) -> int:
    when = timezone.localtime(meeting.scheduled_at).strftime("%a %d %b %Y, %H:%M")
    message = f"Meeting notice: {meeting.title} on {when}" + (f" at {meeting.venue}" if meeting.venue else "") + \
        ". If you can't attend, send an apology in the Inuka West app."
    members = list(Member.objects.filter(status=MemberStatus.ACTIVE).exclude(phone_number=""))

    def _send():
        for member in members:
            queue_sms(member=member, event_type="meeting_notice", recipient=member.phone_number, message=message)

    transaction.on_commit(_send)
    meeting.notice_sent_at = timezone.now()
    meeting.save(update_fields=["notice_sent_at"])
    return len(members)


def send_apology(*, meeting: Meeting, member: Member, reason: str) -> MeetingAttendance:
    """A member saying in advance they can't attend."""
    if meeting.status != MeetingStatus.SCHEDULED:
        raise ValueError("Apologies can only be sent before the register is closed.")
    if not reason.strip():
        raise ValueError("Give a short reason for your apology.")
    attendance, _ = MeetingAttendance.objects.update_or_create(
        meeting=meeting, member=member,
        defaults={"status": AttendanceStatus.APOLOGY, "apology_reason": reason.strip()[:255]},
    )
    return attendance


def record_attendance(*, meeting: Meeting, entries: list[dict], recorded_by=None) -> int:
    """entries: [{"member": Member, "status": ..., "apology_reason": ""}]. Marking
    someone present or late reactivates them if they'd been archived for
    inactivity (members.activity.note_activity)."""
    from members.activity import note_activity

    if meeting.status == MeetingStatus.CANCELLED:
        raise ValueError("This meeting was cancelled.")
    count = 0
    with transaction.atomic():
        for entry in entries:
            MeetingAttendance.objects.update_or_create(
                meeting=meeting, member=entry["member"],
                defaults={
                    "status": entry["status"],
                    "apology_reason": entry.get("apology_reason", "")[:255],
                    "recorded_by": recorded_by,
                },
            )
            count += 1
            if entry["status"] in (AttendanceStatus.PRESENT, AttendanceStatus.LATE):
                note_activity(entry["member"], reason="attended a meeting", by=recorded_by)
    return count


def close_register(*, meeting: Meeting, closed_by=None) -> int:
    """Marks the meeting held. Everyone expected but not marked is recorded
    as absent without apology. Returns how many were marked absent."""
    if meeting.status != MeetingStatus.SCHEDULED:
        raise ValueError("This register is already closed or the meeting was cancelled.")
    with transaction.atomic():
        marked = set(meeting.attendance.values_list("member_id", flat=True))
        missing = [m for m in expected_members(meeting) if m.pk not in marked]
        MeetingAttendance.objects.bulk_create([
            MeetingAttendance(meeting=meeting, member=m, status=AttendanceStatus.ABSENT, recorded_by=closed_by)
            for m in missing
        ])
        meeting.status = MeetingStatus.HELD
        meeting.closed_at = timezone.now()
        meeting.save(update_fields=["status", "closed_at"])
    return len(missing)


def cancel_meeting(*, meeting: Meeting) -> Meeting:
    if meeting.status != MeetingStatus.SCHEDULED:
        raise ValueError("Only a scheduled meeting can be cancelled.")
    meeting.status = MeetingStatus.CANCELLED
    meeting.save(update_fields=["status"])
    return meeting
