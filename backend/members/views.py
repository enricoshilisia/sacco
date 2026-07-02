from django.utils import timezone
from rest_framework import generics, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accesscontrol.permissions import require_permission

from .models import GuarantorConsent, GuarantorConsentStatus, Member
from .serializers import (
    GuarantorConsentSerializer,
    MemberListSerializer,
    MemberPhotoSerializer,
    MemberSerializer,
)


class MemberListCreateView(generics.ListCreateAPIView):
    queryset = Member.objects.prefetch_related("relations").all()

    def get_serializer_class(self):
        return MemberListSerializer if self.request.method == "GET" else MemberSerializer

    def get_permissions(self):
        code = "members.create" if self.request.method == "POST" else "members.view"
        return [IsAuthenticated(), require_permission(code)()]


class MemberDetailView(generics.RetrieveUpdateAPIView):
    queryset = Member.objects.prefetch_related("relations").all()
    serializer_class = MemberSerializer

    def get_permissions(self):
        code = "members.edit" if self.request.method in ("PUT", "PATCH") else "members.view"
        return [IsAuthenticated(), require_permission(code)()]


class MemberKycVerifyView(APIView):
    permission_classes = [IsAuthenticated, require_permission("members.kyc_verify")]

    def post(self, request, pk):
        member = generics.get_object_or_404(Member, pk=pk)
        member.is_kyc_verified = True
        member.kyc_verified_at = timezone.now()
        member.kyc_verified_by = request.user
        member.save(update_fields=["is_kyc_verified", "kyc_verified_at", "kyc_verified_by"])
        return Response(MemberSerializer(member).data)


class MemberPhotoUploadView(APIView):
    """Upload/replace a member's profile photo - a separate step from
    creating or editing the rest of the record."""

    permission_classes = [IsAuthenticated, require_permission("members.edit")]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, pk):
        member = generics.get_object_or_404(Member, pk=pk)
        serializer = MemberPhotoSerializer(member, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save(updated_by=request.user)
        return Response(MemberSerializer(member).data)


class GuarantorConsentListCreateView(generics.ListCreateAPIView):
    queryset = GuarantorConsent.objects.select_related("guarantor", "borrower").all()
    serializer_class = GuarantorConsentSerializer
    permission_classes = [IsAuthenticated, require_permission("members.manage_guarantors")]


class GuarantorConsentRespondView(APIView):
    """The guarantor themselves accepts or declines - not gated by members.manage_guarantors,
    since the person responding is the guarantor, not necessarily staff."""

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        consent = generics.get_object_or_404(GuarantorConsent, pk=pk)
        new_status = request.data.get("status")
        if new_status not in (GuarantorConsentStatus.CONSENTED, GuarantorConsentStatus.DECLINED):
            return Response(
                {"detail": "status must be CONSENTED or DECLINED"}, status=status.HTTP_400_BAD_REQUEST
            )
        consent.status = new_status
        consent.responded_at = timezone.now()
        consent.save(update_fields=["status", "responded_at"])
        return Response(GuarantorConsentSerializer(consent).data)
