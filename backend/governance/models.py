"""
Meetings and attendance. The Secretary schedules meetings (members get an
SMS notice), members can send an apology in advance, and the Secretary marks
the register. Once the register is closed, anyone not marked counts as
absent. Absences without apology feed the member-activity rule
(members.activity): too many in a row and a member is flagged as inactive.
"""

import uuid

from django.conf import settings
from django.db import models


class MeetingType(models.TextChoices):
    AGM = "AGM", "Annual general meeting"
    SGM = "SGM", "Special general meeting"
    MONTHLY = "MONTHLY", "Monthly members' meeting"
    COMMITTEE = "COMMITTEE", "Committee meeting"
    BOARD = "BOARD", "Board meeting"


# General meetings every member is expected at - these count towards the
# attendance rule. Committee/board meetings don't (only some members attend).
GENERAL_MEETINGS = {MeetingType.AGM, MeetingType.SGM, MeetingType.MONTHLY}


class MeetingStatus(models.TextChoices):
    SCHEDULED = "SCHEDULED", "Scheduled"
    HELD = "HELD", "Held - register closed"
    CANCELLED = "CANCELLED", "Cancelled"


class Meeting(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    meeting_type = models.CharField(max_length=12, choices=MeetingType.choices)
    title = models.CharField(max_length=200)
    scheduled_at = models.DateTimeField()
    venue = models.CharField(max_length=200, blank=True)
    agenda = models.TextField(blank=True)
    counts_for_attendance = models.BooleanField(
        default=True, help_text="Whether absences here count towards the inactivity rule."
    )
    status = models.CharField(max_length=10, choices=MeetingStatus.choices, default=MeetingStatus.SCHEDULED)
    notice_sent_at = models.DateTimeField(null=True, blank=True)
    closed_at = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-scheduled_at"]

    def __str__(self):
        return f"{self.title} ({self.scheduled_at:%Y-%m-%d})"


class AttendanceStatus(models.TextChoices):
    PRESENT = "PRESENT", "Present"
    LATE = "LATE", "Late"
    APOLOGY = "APOLOGY", "Absent with apology"
    ABSENT = "ABSENT", "Absent without apology"


class MeetingAttendance(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    meeting = models.ForeignKey(Meeting, on_delete=models.CASCADE, related_name="attendance")
    member = models.ForeignKey("members.Member", on_delete=models.CASCADE, related_name="meeting_attendance")
    status = models.CharField(max_length=10, choices=AttendanceStatus.choices)
    apology_reason = models.CharField(max_length=255, blank=True)
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    recorded_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["meeting", "member"], name="one_attendance_per_member")]
