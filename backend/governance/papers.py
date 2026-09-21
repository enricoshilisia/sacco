"""
Meeting papers: documents attached to a meeting, and its minutes.

Who sees what:
- General meetings (AGM, SGM, monthly): every member sees the documents
  and the APPROVED minutes.
- Committee and board meetings are confidential: only people with
  governance.view_confidential.
- Draft or submitted minutes: only those who write (governance.upload_minutes)
  or approve (governance.approve_minutes) them.
"""

import mimetypes
import re
from io import BytesIO

from django.db import transaction
from django.utils import timezone

from accesscontrol.permissions import user_has_permission
from core.images import InvalidImage, normalize_image

from .models import (
    GENERAL_MEETINGS,
    AttendanceStatus,
    DocumentKind,
    Meeting,
    MeetingDocument,
    MeetingMinutes,
    MeetingStatus,
    MinutesAddendum,
    MinutesStatus,
)

MAX_BYTES = 25 * 1024 * 1024
# Office documents and PDFs are kept as they are; photos are straightened and
# resized to a readable JPEG (phone photos of printed reports).
ALLOWED_EXTENSIONS = {".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".odt", ".ods", ".txt", ".csv"}
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp", ".gif", ".bmp"}


# --- Access ---------------------------------------------------------------


def is_confidential(meeting: Meeting) -> bool:
    return meeting.meeting_type not in GENERAL_MEETINGS


def can_see_meeting_papers(user, meeting: Meeting) -> bool:
    if not user_has_permission(user, "governance.view"):
        return False
    return not is_confidential(meeting) or user_has_permission(user, "governance.view_confidential")


def can_write_minutes(user) -> bool:
    return user_has_permission(user, "governance.upload_minutes")


def can_approve_minutes(user) -> bool:
    return user_has_permission(user, "governance.approve_minutes")


def can_see_minutes(user, minutes: MeetingMinutes) -> bool:
    if not can_see_meeting_papers(user, minutes.meeting):
        return False
    if minutes.status == MinutesStatus.APPROVED:
        return True
    return can_write_minutes(user) or can_approve_minutes(user)


# --- Documents --------------------------------------------------------------


def _extension(name: str) -> str:
    match = re.search(r"\.[A-Za-z0-9]+$", name or "")
    return match.group(0).lower() if match else ""


def upload_document(*, meeting: Meeting, uploaded, title: str, kind: str, by) -> MeetingDocument:
    if kind not in DocumentKind.values:
        raise ValueError("Unknown document type.")
    if uploaded.size and uploaded.size > MAX_BYTES:
        raise ValueError("That file is larger than 25 MB.")
    original = (getattr(uploaded, "name", "") or "document")[-200:]
    ext = _extension(original)
    uploaded.seek(0)
    head = uploaded.read(5)
    uploaded.seek(0)
    if head == b"%PDF-":
        ext = ".pdf"
    if ext in ALLOWED_EXTENSIONS:
        stored = uploaded
        safe = re.sub(r"[^A-Za-z0-9._-]+", "-", original).strip("-") or f"document{ext}"
        stored.name = safe if safe.lower().endswith(ext) else f"{safe}{ext}"
        content_type = mimetypes.guess_type(stored.name)[0] or "application/octet-stream"
    else:
        # Anything else must be a photo (any format, e.g. HEIC from an iPhone).
        try:
            stored = normalize_image(uploaded, name="document.jpg", max_side=2400)
        except InvalidImage:
            raise ValueError("Upload a PDF, Word, Excel or PowerPoint file, or a photo.")
        content_type = "image/jpeg"
        original = re.sub(r"\.[A-Za-z0-9]+$", "", original) + ".jpg"
    return MeetingDocument.objects.create(
        meeting=meeting,
        kind=kind,
        title=(title or original).strip()[:200],
        file=stored,
        original_name=original,
        content_type=content_type,
        size=getattr(stored, "size", 0) or 0,
        uploaded_by=by,
    )


def withdraw_document(document: MeetingDocument, *, by, reason: str) -> MeetingDocument:
    if not reason.strip():
        raise ValueError("Say why the document is being withdrawn.")
    if document.withdrawn_at is not None:
        raise ValueError("This document was already withdrawn.")
    document.withdrawn_at = timezone.now()
    document.withdrawn_by = by
    document.withdrawn_reason = reason.strip()[:255]
    document.save(update_fields=["withdrawn_at", "withdrawn_by", "withdrawn_reason"])
    return document


# --- Minutes -----------------------------------------------------------------


def minute_prefix(meeting: Meeting) -> str:
    return f"MIN {{n:02d}}/{meeting.scheduled_at:%m/%Y}"


def draft_template(meeting: Meeting) -> str:
    """A starting point in the usual SACCO style: heading, attendance,
    then one numbered minute per agenda item (MIN 01/10/2026 ...)."""
    local = timezone.localtime(meeting.scheduled_at)
    lines = [
        meeting.title.upper(),
        f"{meeting.get_meeting_type_display()} held on {local:%A %d %B %Y} at {local:%H:%M}"
        + (f", {meeting.venue}" if meeting.venue else "") + ".",
        "",
    ]
    marks = list(meeting.attendance.select_related("member").order_by("member__first_name"))
    present = [a.member.full_name for a in marks if a.status in (AttendanceStatus.PRESENT, AttendanceStatus.LATE)]
    apologies = [a.member.full_name for a in marks if a.status == AttendanceStatus.APOLOGY]
    absent = sum(1 for a in marks if a.status == AttendanceStatus.ABSENT)
    lines.append(f"PRESENT ({len(present)}): " + (", ".join(present) if present else "-"))
    lines.append(f"APOLOGIES ({len(apologies)}): " + (", ".join(apologies) if apologies else "-"))
    lines.append(f"ABSENT WITHOUT APOLOGY: {absent}")
    lines.append("")
    items = [re.sub(r"^\s*(\d+[.)]|[-*•])\s*", "", line).strip() for line in (meeting.agenda or "").splitlines()]
    items = [i for i in items if i] or ["Opening prayer and preliminaries", "Confirmation of previous minutes",
                                        "Matters arising", "Any other business", "Closing"]
    prefix = minute_prefix(meeting)
    for n, item in enumerate(items, start=1):
        lines.append(f"{prefix.format(n=n)}: {item.upper()}")
        lines.append("")
        lines.append("")
    lines.append("There being no other business, the meeting ended at __:__.")
    return "\n".join(lines)


def get_minutes(meeting: Meeting) -> MeetingMinutes | None:
    return MeetingMinutes.objects.filter(meeting=meeting).first()


def save_draft(*, meeting: Meeting, body: str, by) -> MeetingMinutes:
    if meeting.status == MeetingStatus.CANCELLED:
        raise ValueError("A cancelled meeting has no minutes.")
    with transaction.atomic():
        minutes, _ = MeetingMinutes.objects.select_for_update().get_or_create(
            meeting=meeting, defaults={"drafted_by": by}
        )
        if minutes.status == MinutesStatus.APPROVED:
            raise ValueError("These minutes are approved and locked. Add an addendum instead.")
        if minutes.status == MinutesStatus.SUBMITTED:
            raise ValueError("These minutes are waiting for approval. Ask the approver to send them back to edit.")
        minutes.body = body
        minutes.drafted_by = minutes.drafted_by or by
        minutes.save(update_fields=["body", "drafted_by", "updated_at"])
        return minutes


def submit(*, meeting: Meeting, by) -> MeetingMinutes:
    with transaction.atomic():
        minutes = MeetingMinutes.objects.select_for_update().filter(meeting=meeting).first()
        if minutes is None or not minutes.body.strip():
            raise ValueError("Write the minutes before sending them for approval.")
        if minutes.status != MinutesStatus.DRAFT:
            raise ValueError("Only draft minutes can be sent for approval.")
        if meeting.status == MeetingStatus.SCHEDULED:
            raise ValueError("Close the meeting's register first - minutes are for a meeting that was held.")
        minutes.status = MinutesStatus.SUBMITTED
        minutes.submitted_by = by
        minutes.submitted_at = timezone.now()
        minutes.return_comment = ""
        minutes.save(update_fields=["status", "submitted_by", "submitted_at", "return_comment", "updated_at"])
        return minutes


def _decide(meeting: Meeting, by) -> MeetingMinutes:
    minutes = MeetingMinutes.objects.select_for_update().filter(meeting=meeting).first()
    if minutes is None or minutes.status != MinutesStatus.SUBMITTED:
        raise ValueError("These minutes aren't waiting for approval.")
    if minutes.submitted_by_id == by.pk:
        raise ValueError("You sent these minutes for approval, so someone else must approve them.")
    return minutes


def approve(*, meeting: Meeting, by) -> MeetingMinutes:
    with transaction.atomic():
        minutes = _decide(meeting, by)
        minutes.status = MinutesStatus.APPROVED
        minutes.approved_by = by
        minutes.approved_at = timezone.now()
        minutes.save(update_fields=["status", "approved_by", "approved_at", "updated_at"])
        return minutes


def send_back(*, meeting: Meeting, by, comment: str) -> MeetingMinutes:
    if not comment.strip():
        raise ValueError("Say what needs changing.")
    with transaction.atomic():
        minutes = _decide(meeting, by)
        minutes.status = MinutesStatus.DRAFT
        minutes.return_comment = comment.strip()
        minutes.save(update_fields=["status", "return_comment", "updated_at"])
        return minutes


def add_addendum(*, meeting: Meeting, text: str, by) -> MinutesAddendum:
    minutes = get_minutes(meeting)
    if minutes is None or minutes.status != MinutesStatus.APPROVED:
        raise ValueError("Addenda are for approved minutes. Edit the draft instead.")
    if not text.strip():
        raise ValueError("Write the correction or note.")
    return MinutesAddendum.objects.create(minutes=minutes, text=text.strip(), added_by=by)


# --- PDF -----------------------------------------------------------------------


def minutes_pdf(minutes: MeetingMinutes, *, sacco_name: str) -> bytes:
    """Approved minutes as a printable PDF, with the approval record and
    space for signatures (for the file copy / auditors)."""
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
    from xml.sax.saxutils import escape

    meeting = minutes.meeting
    styles = getSampleStyleSheet()
    body = ParagraphStyle("body", parent=styles["BodyText"], fontSize=10.5, leading=14)
    minute = ParagraphStyle("minute", parent=body, fontName="Helvetica-Bold", spaceBefore=8)
    title = ParagraphStyle("title", parent=styles["Title"], fontSize=15, alignment=TA_CENTER, spaceAfter=2)
    small = ParagraphStyle("small", parent=body, fontSize=8.5, textColor=colors.grey, alignment=TA_CENTER)

    story = [Paragraph(escape(sacco_name.upper()), title),
             Paragraph(escape(f"Minutes - {meeting.title}"), small), Spacer(1, 6 * mm)]
    for line in minutes.body.splitlines():
        text = escape(line) or "&nbsp;"
        story.append(Paragraph(text, minute if re.match(r"^\s*MIN\s+\d+", line) else body))
    for addendum in minutes.addenda.select_related("added_by"):
        who = addendum.added_by.get_full_name() if addendum.added_by else ""
        story += [Spacer(1, 4 * mm),
                  Paragraph(escape(f"Addendum ({timezone.localtime(addendum.added_at):%d %b %Y}, {who}):"), minute),
                  Paragraph(escape(addendum.text).replace("\n", "<br/>"), body)]

    approver = minutes.approved_by.get_full_name() if minutes.approved_by else ""
    secretary = minutes.submitted_by.get_full_name() if minutes.submitted_by else ""
    approved_on = f"{timezone.localtime(minutes.approved_at):%d %B %Y}" if minutes.approved_at else ""
    story += [Spacer(1, 12 * mm), Table(
        [["Secretary", "Chairperson"],
         [secretary, approver],
         ["Signature: ____________________", "Signature: ____________________"],
         ["Date: ______________", f"Approved in Inuka West on {approved_on}"]],
        colWidths=[85 * mm, 85 * mm],
        style=TableStyle([("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"), ("FONTSIZE", (0, 0), (-1, -1), 9.5),
                          ("TOPPADDING", (0, 0), (-1, -1), 5)]),
    )]

    out = BytesIO()
    SimpleDocTemplate(out, pagesize=A4, leftMargin=20 * mm, rightMargin=20 * mm, topMargin=18 * mm,
                      bottomMargin=18 * mm, title=f"Minutes - {meeting.title}").build(story)
    return out.getvalue()
