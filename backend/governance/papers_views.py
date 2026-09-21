from django.db import connection
from django.http import FileResponse, HttpResponse
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission
from audit.services import record

from . import papers
from .models import Meeting, MeetingDocument, MeetingMinutes, MinutesStatus


def _bad(exc, code=status.HTTP_400_BAD_REQUEST):
    return Response({"detail": str(exc)}, status=code)


def _forbidden():
    return _bad("You can't see this meeting's papers.", status.HTTP_403_FORBIDDEN)


def _name(user):
    return user.get_full_name() if user else ""


def document_json(d: MeetingDocument) -> dict:
    return {
        "id": str(d.pk),
        "meeting": str(d.meeting_id),
        "kind": d.kind,
        "kind_label": d.get_kind_display(),
        "title": d.title,
        "original_name": d.original_name,
        "content_type": d.content_type,
        "size": d.size,
        "uploaded_by_name": _name(d.uploaded_by),
        "uploaded_at": d.uploaded_at,
        "withdrawn": d.withdrawn_at is not None,
        "withdrawn_reason": d.withdrawn_reason,
        "download_path": f"/api/governance/documents/{d.pk}/download/",
    }


def minutes_json(m: MeetingMinutes | None, meeting: Meeting, user) -> dict:
    writer = papers.can_write_minutes(user)
    base = {
        "meeting": str(meeting.pk),
        "meeting_title": meeting.title,
        "confidential": papers.is_confidential(meeting),
        "can_write": writer,
        "can_approve": papers.can_approve_minutes(user),
    }
    if m is None:
        return {**base, "exists": False, "status": None, "body": papers.draft_template(meeting) if writer else "",
                "addenda": []}
    return {
        **base,
        "exists": True,
        "status": m.status,
        "status_label": m.get_status_display(),
        "body": m.body,
        "return_comment": m.return_comment,
        "drafted_by_name": _name(m.drafted_by),
        "updated_at": m.updated_at,
        "submitted_by": str(m.submitted_by_id) if m.submitted_by_id else None,
        "submitted_by_name": _name(m.submitted_by),
        "submitted_at": m.submitted_at,
        "approved_by_name": _name(m.approved_by),
        "approved_at": m.approved_at,
        "addenda": [
            {"text": a.text, "added_by_name": _name(a.added_by), "added_at": a.added_at}
            for a in m.addenda.select_related("added_by")
        ],
    }


class MeetingDocumentsView(APIView):
    """GET: the meeting's documents. POST (multipart: file, title, kind):
    attach one (governance.upload_minutes)."""

    permission_classes = [IsAuthenticated, require_permission("governance.view")]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request, pk):
        meeting = get_object_or_404(Meeting, pk=pk)
        if not papers.can_see_meeting_papers(request.user, meeting):
            return _forbidden()
        docs = meeting.documents.select_related("uploaded_by")
        if not papers.can_write_minutes(request.user):
            docs = docs.filter(withdrawn_at__isnull=True)
        return Response([document_json(d) for d in docs])

    def post(self, request, pk):
        meeting = get_object_or_404(Meeting, pk=pk)
        if not papers.can_write_minutes(request.user):
            return _bad("You can't add meeting documents.", status.HTTP_403_FORBIDDEN)
        uploaded = request.FILES.get("file")
        if uploaded is None:
            return _bad("Choose a file.")
        try:
            document = papers.upload_document(
                meeting=meeting, uploaded=uploaded, title=request.data.get("title", ""),
                kind=request.data.get("kind", "ATTACHMENT"), by=request.user,
            )
        except ValueError as exc:
            return _bad(exc)
        record(request=request, event="governance.document_uploaded", area="governance",
               summary=f"Added '{document.title}' to {meeting.title}", target=document, target_label=document.title)
        return Response(document_json(document), status=status.HTTP_201_CREATED)


class DocumentDownloadView(APIView):
    """Streams the file after checking the person may see it - meeting
    papers are never served from a public URL."""

    permission_classes = [IsAuthenticated, require_permission("governance.view")]

    def get(self, request, pk):
        document = get_object_or_404(MeetingDocument.objects.select_related("meeting"), pk=pk)
        if not papers.can_see_meeting_papers(request.user, document.meeting):
            return _forbidden()
        if document.withdrawn_at and not papers.can_write_minutes(request.user):
            return _bad("This document was withdrawn.", status.HTTP_404_NOT_FOUND)
        record(request=request, event="governance.document_opened", area="governance",
               summary=f"Opened '{document.title}' ({document.meeting.title})", target=document,
               target_label=document.title)
        return FileResponse(document.file.open("rb"), as_attachment=False,
                            filename=document.original_name or "document", content_type=document.content_type or None)


class DocumentWithdrawView(APIView):
    permission_classes = [IsAuthenticated, require_permission("governance.upload_minutes")]

    def post(self, request, pk):
        document = get_object_or_404(MeetingDocument, pk=pk)
        try:
            papers.withdraw_document(document, by=request.user, reason=str(request.data.get("reason", "")))
        except ValueError as exc:
            return _bad(exc)
        record(request=request, event="governance.document_withdrawn", area="governance",
               summary=f"Withdrew '{document.title}': {document.withdrawn_reason}", target=document,
               target_label=document.title)
        return Response(document_json(document))


class MinutesView(APIView):
    """GET: the minutes (a pre-filled template for writers when none exist
    yet). PUT {body}: save the draft (governance.upload_minutes)."""

    permission_classes = [IsAuthenticated, require_permission("governance.view")]

    def get(self, request, pk):
        meeting = get_object_or_404(Meeting, pk=pk)
        if not papers.can_see_meeting_papers(request.user, meeting):
            return _forbidden()
        minutes = papers.get_minutes(meeting)
        if minutes is not None and not papers.can_see_minutes(request.user, minutes):
            minutes = None  # a member sees nothing until approved
            if not (papers.can_write_minutes(request.user) or papers.can_approve_minutes(request.user)):
                return Response({"meeting": str(meeting.pk), "meeting_title": meeting.title, "exists": False,
                                 "status": None, "body": "", "addenda": [], "can_write": False,
                                 "can_approve": False, "confidential": papers.is_confidential(meeting)})
        return Response(minutes_json(minutes, meeting, request.user))

    def put(self, request, pk):
        meeting = get_object_or_404(Meeting, pk=pk)
        if not papers.can_write_minutes(request.user):
            return _bad("You can't write minutes.", status.HTTP_403_FORBIDDEN)
        try:
            minutes = papers.save_draft(meeting=meeting, body=str(request.data.get("body", "")), by=request.user)
        except ValueError as exc:
            return _bad(exc)
        return Response(minutes_json(minutes, meeting, request.user))


class MinutesActionView(APIView):
    """submit (writer) · approve / return (approver, never the submitter) ·
    addendum (writer, approved minutes only)."""

    permission_classes = [IsAuthenticated, require_permission("governance.view")]
    action = "submit"

    def post(self, request, pk):
        meeting = get_object_or_404(Meeting, pk=pk)
        user = request.user
        try:
            if self.action == "submit":
                if not papers.can_write_minutes(user):
                    raise PermissionError
                papers.submit(meeting=meeting, by=user)
                summary = f"Sent minutes of {meeting.title} for approval"
            elif self.action == "approve":
                if not papers.can_approve_minutes(user):
                    raise PermissionError
                papers.approve(meeting=meeting, by=user)
                summary = f"Approved the minutes of {meeting.title}"
            elif self.action == "return":
                if not papers.can_approve_minutes(user):
                    raise PermissionError
                papers.send_back(meeting=meeting, by=user, comment=str(request.data.get("comment", "")))
                summary = f"Sent the minutes of {meeting.title} back for changes"
            else:
                if not papers.can_write_minutes(user):
                    raise PermissionError
                papers.add_addendum(meeting=meeting, text=str(request.data.get("text", "")), by=user)
                summary = f"Added an addendum to the minutes of {meeting.title}"
        except PermissionError:
            return _bad("You can't do that with these minutes.", status.HTTP_403_FORBIDDEN)
        except ValueError as exc:
            return _bad(exc)
        record(request=request, event=f"governance.minutes_{self.action}", area="governance", summary=summary,
               target=meeting, target_label=meeting.title)
        return Response(minutes_json(papers.get_minutes(meeting), meeting, user))


class MinutesPdfView(APIView):
    permission_classes = [IsAuthenticated, require_permission("governance.view")]

    def get(self, request, pk):
        from tenants.models import Tenant

        meeting = get_object_or_404(Meeting, pk=pk)
        minutes = papers.get_minutes(meeting)
        if minutes is None or not papers.can_see_minutes(request.user, minutes):
            return _forbidden()
        if minutes.status != MinutesStatus.APPROVED and not papers.can_approve_minutes(request.user) \
                and not papers.can_write_minutes(request.user):
            return _forbidden()
        sacco = Tenant.objects.get(schema_name=connection.schema_name).name
        pdf = papers.minutes_pdf(minutes, sacco_name=sacco)
        response = HttpResponse(pdf, content_type="application/pdf")
        safe = "".join(c if c.isalnum() else "-" for c in meeting.title)[:60]
        response["Content-Disposition"] = f'inline; filename="minutes-{safe}.pdf"'
        return response


class MinutesQueueView(APIView):
    """Minutes waiting for approval (for the Chairperson)."""

    permission_classes = [IsAuthenticated, require_permission("governance.approve_minutes")]

    def get(self, request):
        qs = MeetingMinutes.objects.filter(status=MinutesStatus.SUBMITTED).select_related("meeting", "submitted_by")
        return Response([
            {"meeting": str(m.meeting_id), "meeting_title": m.meeting.title, "scheduled_at": m.meeting.scheduled_at,
             "submitted_by_name": _name(m.submitted_by), "submitted_at": m.submitted_at,
             "mine": m.submitted_by_id == request.user.pk}
            for m in qs
        ])
