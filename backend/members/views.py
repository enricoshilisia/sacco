from django.utils import timezone
from rest_framework import generics, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from accesscontrol.permissions import require_permission
from identity.models import User
from identity.serializers import UserSerializer
from identity.views import _grant_default_tenant_membership

from .models import GuarantorConsent, GuarantorConsentStatus, Member, MemberPortalInvite
from .serializers import (
    GuarantorConsentSerializer,
    MemberListSerializer,
    MemberPhotoSerializer,
    MemberPortalInviteSerializer,
    MemberSerializer,
    MyMemberSerializer,
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


class MyMemberView(APIView):
    """
    Self-service: "my own member record", resolved from request.user - not
    a member_id in the URL. GET is deliberately not gated by members.view
    (the staff-facing permission that lets someone look up ANY member by
    id): ownership IS the access check here, so any authenticated user
    with a linked Member record may use it, and one with no linked record
    gets a 404, not a 403. PATCH additionally requires members.edit_own -
    a state change, so (like loans.repay/payments.initiate_own_collection)
    it gets its own permission code rather than piggybacking on the
    staff-facing members.edit, so an admin could toggle self-edit off for
    the Member role without touching the staff permission.
    """

    def get_permissions(self):
        if self.request.method == "PATCH":
            return [IsAuthenticated(), require_permission("members.edit_own")()]
        return [IsAuthenticated()]

    def _my_member(self, request):
        return Member.objects.filter(user=request.user).first()

    def get(self, request):
        member = self._my_member(request)
        if member is None:
            return Response({"detail": "No member record is linked to this account."}, status=status.HTTP_404_NOT_FOUND)
        return Response(MemberSerializer(member).data)

    def patch(self, request):
        member = self._my_member(request)
        if member is None:
            return Response({"detail": "No member record is linked to this account."}, status=status.HTTP_404_NOT_FOUND)
        serializer = MyMemberSerializer(member, data=request.data, partial=True, context={"request": request})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class MyMemberPhotoUploadView(APIView):
    """Self-service twin of MemberPhotoUploadView - a member updating their
    own profile photo, gated by members.edit_own (the same self-service
    permission as the rest of MyMemberView's PATCH) rather than the
    staff-facing members.edit."""

    permission_classes = [IsAuthenticated, require_permission("members.edit_own")]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        member = Member.objects.filter(user=request.user).first()
        if member is None:
            return Response({"detail": "No member record is linked to this account."}, status=status.HTTP_404_NOT_FOUND)
        serializer = MemberPhotoSerializer(member, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save(updated_by=request.user)
        return Response(MemberSerializer(member).data)


class InvitePortalAccessView(APIView):
    """Staff generates a one-time setup link for an existing member who
    doesn't have self-service login access yet."""

    permission_classes = [IsAuthenticated, require_permission("members.edit")]

    def post(self, request, member_id):
        member = generics.get_object_or_404(Member, pk=member_id)
        if member.user_id is not None:
            return Response(
                {"detail": "This member already has portal access."}, status=status.HTTP_400_BAD_REQUEST
            )
        invite = MemberPortalInvite.objects.create(member=member, invited_by=request.user)
        return Response(MemberPortalInviteSerializer(invite).data, status=status.HTTP_201_CREATED)


class PortalInviteListView(generics.ListAPIView):
    serializer_class = MemberPortalInviteSerializer
    permission_classes = [IsAuthenticated, require_permission("members.edit")]

    def get_queryset(self):
        qs = MemberPortalInvite.objects.select_related("member").all()
        member_id = self.request.query_params.get("member")
        if member_id:
            qs = qs.filter(member_id=member_id)
        return qs


class PortalInviteRevokeView(APIView):
    permission_classes = [IsAuthenticated, require_permission("members.edit")]

    def post(self, request, pk):
        invite = generics.get_object_or_404(MemberPortalInvite, pk=pk)
        if invite.status != "pending":
            return Response(
                {"detail": f"This invite is already {invite.status}."}, status=status.HTTP_400_BAD_REQUEST
            )
        invite.revoked_at = timezone.now()
        invite.save(update_fields=["revoked_at"])
        return Response(MemberPortalInviteSerializer(invite).data)


class PortalInviteAcceptView(APIView):
    """
    Public (no auth) - the destination of the setup link staff shares out
    of band. GET prefills the accept page; POST creates/reuses the account,
    links it to the member, and grants the default "Member" role. Only
    reachable within a tenant's own urlconf, same as /api/auth/register.
    """

    permission_classes = [AllowAny]

    def get(self, request, token):
        invite = generics.get_object_or_404(MemberPortalInvite, token=token)
        if invite.status != "pending":
            return Response({"detail": f"This invite is {invite.status}."}, status=status.HTTP_400_BAD_REQUEST)
        existing_account = User.objects.filter(phone_number=invite.member.phone_number).exists()
        return Response(
            {
                "member_name": invite.member.full_name(),
                "member_number": invite.member.member_number,
                "existing_account": existing_account,
            }
        )

    def post(self, request, token):
        invite = generics.get_object_or_404(MemberPortalInvite, token=token)
        if invite.status != "pending":
            return Response({"detail": f"This invite is {invite.status}."}, status=status.HTTP_400_BAD_REQUEST)

        password = request.data.get("password", "")
        existing_user = User.objects.filter(phone_number=invite.member.phone_number).first()

        if existing_user:
            if not existing_user.check_password(password):
                return Response(
                    {"detail": "Incorrect password for this existing account."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user = existing_user
        else:
            if len(password) < 8:
                return Response(
                    {"detail": "Password must be at least 8 characters."}, status=status.HTTP_400_BAD_REQUEST
                )
            user = User.objects.create_user(
                phone_number=invite.member.phone_number,
                first_name=invite.member.first_name,
                last_name=invite.member.last_name,
                email=invite.member.email or None,
                password=password,
            )

        _grant_default_tenant_membership(user)
        invite.member.user = user
        invite.member.save(update_fields=["user"])

        invite.accepted_at = timezone.now()
        invite.save(update_fields=["accepted_at"])

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "user": UserSerializer(user).data,
                "access": str(refresh.access_token),
                "refresh": str(refresh),
            },
            status=status.HTTP_201_CREATED,
        )
