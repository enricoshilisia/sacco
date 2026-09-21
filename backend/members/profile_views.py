from rest_framework import generics, status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission

from . import profile_services as services
from .models import ChangeRequestStatus, FamilyMember, FamilyMemberStatus, Member, MemberDocument, ProfileChangeRequest
from .profile_serializers import (
    ChangeRequestSerializer,
    DocumentUploadSerializer,
    FamilyInputSerializer,
    FamilyMemberSerializer,
    MemberDocumentSerializer,
    ProfileChangesSerializer,
)
from .serializers import MemberSerializer

NO_MEMBER = {"detail": "No member record is linked to this account."}


def _bad(exc):
    return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)


def _profile_payload(member, request):
    return {
        "member": MemberSerializer(member, context={"request": request}).data,
        "family": FamilyMemberSerializer(member.family.exclude(status=FamilyMemberStatus.REMOVED), many=True).data,
        "requests": ChangeRequestSerializer(
            member.change_requests.select_related("family_member", "decided_by")[:20], many=True, context={"request": request}
        ).data,
        "documents": MemberDocumentSerializer(member.documents.order_by("-uploaded_at"), many=True, context={"request": request}).data,
        "protected_fields": services.PROTECTED_MEMBER_FIELDS,
        "free_fields": services.FREE_MEMBER_FIELDS,
    }


class _MyMemberMixin:
    def my_member(self, request):
        return Member.objects.filter(user=request.user).first()


class MyProfileView(_MyMemberMixin, APIView):
    """Self-service: my details, family register, pending changes and documents."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        member = self.my_member(request)
        if member is None:
            return Response(NO_MEMBER, status=status.HTTP_404_NOT_FOUND)
        return Response(_profile_payload(member, request))


class MyProfileChangeView(_MyMemberMixin, APIView):
    """Propose changes to protected personal details (or, with no changes,
    submit the profile for its first approval)."""

    permission_classes = [IsAuthenticated, require_permission("members.edit_own")]

    def post(self, request):
        member = self.my_member(request)
        if member is None:
            return Response(NO_MEMBER, status=status.HTTP_404_NOT_FOUND)
        changes = ProfileChangesSerializer(data=request.data.get("changes") or {})
        changes.is_valid(raise_exception=True)
        try:
            services.submit_profile_changes(
                member=member, changes=changes.validated_data, note=request.data.get("note", ""), submitted_by=request.user
            )
        except ValueError as exc:
            return _bad(exc)
        return Response(_profile_payload(member, request), status=status.HTTP_201_CREATED)


class MyFamilyView(_MyMemberMixin, APIView):
    """Ask to add someone to my family register."""

    permission_classes = [IsAuthenticated, require_permission("members.edit_own")]

    def post(self, request):
        member = self.my_member(request)
        if member is None:
            return Response(NO_MEMBER, status=status.HTTP_404_NOT_FOUND)
        data = FamilyInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        services.submit_family_add(member=member, data=data.validated_data, note=request.data.get("note", ""),
                                   submitted_by=request.user)
        return Response(_profile_payload(member, request), status=status.HTTP_201_CREATED)


class MyFamilyDetailView(_MyMemberMixin, APIView):
    """Ask to change (PATCH) or remove (DELETE) someone on my register."""

    permission_classes = [IsAuthenticated, require_permission("members.edit_own")]

    def _person(self, request, pk):
        member = self.my_member(request)
        return member, generics.get_object_or_404(FamilyMember, pk=pk, member=member)

    def patch(self, request, pk):
        member, person = self._person(request, pk)
        data = FamilyInputSerializer(data=request.data, partial=True)
        data.is_valid(raise_exception=True)
        try:
            services.submit_family_update(person=person, changes=data.validated_data,
                                          note=request.data.get("note", ""), submitted_by=request.user)
        except ValueError as exc:
            return _bad(exc)
        return Response(_profile_payload(member, request))

    def delete(self, request, pk):
        member, person = self._person(request, pk)
        try:
            services.submit_family_remove(person=person, note=request.data.get("note", ""), submitted_by=request.user)
        except ValueError as exc:
            return _bad(exc)
        return Response(_profile_payload(member, request))


class MyChangeRequestCancelView(_MyMemberMixin, APIView):
    permission_classes = [IsAuthenticated, require_permission("members.edit_own")]

    def post(self, request, pk):
        member = self.my_member(request)
        change = generics.get_object_or_404(ProfileChangeRequest, pk=pk, member=member)
        try:
            services.cancel_request(change, by_member=member)
        except ValueError as exc:
            return _bad(exc)
        member.refresh_from_db()
        return Response(_profile_payload(member, request))


class MyDocumentUploadView(_MyMemberMixin, APIView):
    """Upload an ID scan, birth certificate, etc. Any photo format or PDF."""

    permission_classes = [IsAuthenticated, require_permission("members.edit_own")]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        member = self.my_member(request)
        if member is None:
            return Response(NO_MEMBER, status=status.HTTP_404_NOT_FOUND)
        data = DocumentUploadSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        person = None
        if data.validated_data.get("family_member"):
            person = generics.get_object_or_404(FamilyMember, pk=data.validated_data["family_member"], member=member)
        try:
            doc = services.upload_document(
                member=member, document_type=data.validated_data["document_type"], uploaded=data.validated_data["file"],
                family_member=person, ocr_id_number=data.validated_data["ocr_id_number"], uploaded_by=request.user,
            )
        except ValueError as exc:
            return _bad(exc)
        return Response(MemberDocumentSerializer(doc, context={"request": request}).data, status=status.HTTP_201_CREATED)


# --- Staff ---------------------------------------------------------------------


class ChangeRequestListView(generics.ListAPIView):
    """The approval queue (members.approve_changes - the Secretary)."""

    serializer_class = ChangeRequestSerializer
    permission_classes = [IsAuthenticated, require_permission("members.approve_changes")]

    def get_queryset(self):
        qs = ProfileChangeRequest.objects.select_related("member", "family_member", "decided_by")
        return qs.filter(status=self.request.query_params.get("status", ChangeRequestStatus.PENDING))


class ChangeRequestDecisionView(APIView):
    permission_classes = [IsAuthenticated, require_permission("members.approve_changes")]
    approve = True

    def post(self, request, pk):
        change = generics.get_object_or_404(ProfileChangeRequest, pk=pk)
        notes = request.data.get("notes", "")
        if not self.approve and not notes.strip():
            return _bad("Give a reason so the member knows what to fix.")
        try:
            if self.approve:
                change = services.approve_request(change, approved_by=request.user, notes=notes)
            else:
                change = services.reject_request(change, rejected_by=request.user, notes=notes)
        except ValueError as exc:
            return _bad(exc)
        return Response(ChangeRequestSerializer(change, context={"request": request}).data)


class MemberFamilyView(APIView):
    """Staff: a member's approved family register."""

    permission_classes = [IsAuthenticated, require_permission("members.view")]

    def get(self, request, pk):
        member = generics.get_object_or_404(Member, pk=pk)
        people = member.family.filter(status=FamilyMemberStatus.APPROVED)
        return Response(FamilyMemberSerializer(people, many=True).data)


class MemberDocumentListView(generics.ListAPIView):
    serializer_class = MemberDocumentSerializer
    permission_classes = [IsAuthenticated, require_permission("members.view")]
    pagination_class = None

    def get_queryset(self):
        return MemberDocument.objects.filter(member_id=self.kwargs["pk"]).select_related("family_member").order_by("-uploaded_at")
