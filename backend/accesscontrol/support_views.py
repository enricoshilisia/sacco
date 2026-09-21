"""Admin support endpoints: people and their access, positions, passwords."""

from django.db.models import Q
from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from audit.models import AuditEvent
from identity.models import TenantAccess, User

from . import services
from .models import Membership, Role
from .permissions import require_permission


def _error(exc):
    code = status.HTTP_403_FORBIDDEN if isinstance(exc, PermissionError) else status.HTTP_400_BAD_REQUEST
    return Response({"detail": str(exc)}, status=code)


def _user_row(user, *, members_by_user, access_by_user, roles_by_user, last_seen_by_user):
    member = members_by_user.get(user.pk)
    return {
        "id": str(user.pk),
        "name": user.get_full_name(),
        "phone_number": user.phone_number,
        "email": user.email or "",
        "member_id": str(member.pk) if member else None,
        "member_number": member.member_number if member else "",
        "member_status": member.status if member else "",
        "member_verified": member.is_verified if member else None,
        "has_photo": bool(member and member.photo),
        "photo": member.photo.url if member and member.photo else None,
        "roles": roles_by_user.get(user.pk, []),
        "login_enabled": access_by_user.get(user.pk, False),
        "must_change_password": user.must_change_password,
        "last_login": user.last_login,
        "last_seen": last_seen_by_user.get(user.pk),
    }


def _rows(users):
    from django.db import connection
    from django.db.models import Max

    from members.models import Member

    ids = [u.pk for u in users]
    members_by_user = {m.user_id: m for m in Member.objects.filter(user_id__in=ids)}
    access_by_user = dict(
        TenantAccess.objects.filter(user_id__in=ids, tenant__schema_name=connection.schema_name)
        .values_list("user_id", "is_active")
    )
    roles_by_user = {}
    for m in Membership.objects.filter(user_id__in=ids, is_active=True).select_related("role"):
        roles_by_user.setdefault(m.user_id, []).append(m.role.name)
    last_seen_by_user = dict(
        AuditEvent.objects.filter(user_id__in=ids).values("user_id").annotate(last=Max("at"))
        .values_list("user_id", "last")
    )
    return [
        _user_row(u, members_by_user=members_by_user, access_by_user=access_by_user,
                  roles_by_user=roles_by_user, last_seen_by_user=last_seen_by_user)
        for u in users
    ]


class UserListView(APIView):
    """Everyone with a login here. ?search= name/phone/member no.,
    ?role=<name>, ?disabled=1."""

    permission_classes = [IsAuthenticated, require_permission("users.view")]

    def get(self, request):
        from members.models import Member

        qs = services.tenant_users().order_by("first_name", "last_name")
        search = request.query_params.get("search", "").strip()
        if search:
            member_users = Member.objects.filter(member_number__icontains=search).values_list("user_id", flat=True)
            qs = qs.filter(
                Q(first_name__icontains=search) | Q(last_name__icontains=search)
                | Q(phone_number__icontains=search) | Q(pk__in=member_users)
            )
        if request.query_params.get("role"):
            holders = Membership.objects.filter(role__name=request.query_params["role"], is_active=True)
            qs = qs.filter(pk__in=holders.values_list("user_id", flat=True))
        if request.query_params.get("disabled") in ("1", "true"):
            from django.db import connection

            qs = qs.filter(tenant_access__tenant__schema_name=connection.schema_name, tenant_access__is_active=False)
        return Response(_rows(list(qs[:200])))


class UserDetailView(APIView):
    permission_classes = [IsAuthenticated, require_permission("users.view")]

    def get(self, request, pk):
        user = get_object_or_404(services.tenant_users(), pk=pk)
        row = _rows([user])[0]
        recent = AuditEvent.objects.filter(user=user).order_by("-at")[:5]
        row["recent_devices"] = list(
            AuditEvent.objects.filter(user=user).exclude(device="").values("device", "location", "ip_address")
            .order_by().distinct()[:5]
        )
        row["recent_activity"] = [
            {"at": e.at, "summary": e.summary, "location": e.location, "device": e.device} for e in recent
        ]
        return Response(row)


class ResetPasswordView(APIView):
    permission_classes = [IsAuthenticated, require_permission("users.reset_password")]

    def post(self, request, pk):
        user = get_object_or_404(services.tenant_users(), pk=pk)
        try:
            temporary = services.reset_password(user=user, by=request.user, request=request)
        except (ValueError, PermissionError) as exc:
            return _error(exc)
        return Response({"temporary_password": temporary, "name": user.get_full_name(),
                         "phone_number": user.phone_number})


class LoginEnabledView(APIView):
    permission_classes = [IsAuthenticated, require_permission("users.manage_access")]
    enabled = True

    def post(self, request, pk):
        user = get_object_or_404(services.tenant_users(), pk=pk)
        try:
            services.set_login_enabled(user=user, enabled=self.enabled, by=request.user, request=request)
        except (ValueError, PermissionError) as exc:
            return _error(exc)
        return Response(_rows([user])[0])


# --- Positions ---------------------------------------------------------------


def _position_row(role, holders):
    return {
        "id": str(role.pk),
        "name": role.name,
        "description": role.description,
        "is_position": role.is_position,
        "is_system": role.is_system,
        "max_holders": role.max_holders,
        "assistant_of": str(role.assistant_of_id) if role.assistant_of_id else None,
        "assistant_of_name": role.assistant_of.name if role.assistant_of_id else "",
        "permission_count": role.permissions.count(),
        "holders": [
            {
                "membership_id": str(m.pk),
                "user_id": str(m.user_id),
                "name": m.user.get_full_name(),
                "phone_number": m.user.phone_number,
                "job_title": m.job_title,
                "assigned_at": m.assigned_at,
            }
            for m in holders.get(role.pk, [])
        ],
    }


class PositionListCreateView(APIView):
    """GET: every assignable role (offices first) with who holds it.
    POST: create a new position {name, description, max_holders,
    copy_from, assistant_of}."""

    permission_classes = [IsAuthenticated, require_permission("accesscontrol.assign_roles")]

    def get(self, request):
        roles = list(Role.objects.exclude(name__in=services.AUTOMATIC_ROLES).select_related("assistant_of")
                     .order_by("-is_position", "sort_order", "name"))
        holders = {}
        for m in Membership.objects.filter(is_active=True, role__in=roles).select_related("user").order_by("assigned_at"):
            holders.setdefault(m.role_id, []).append(m)
        return Response([_position_row(r, holders) for r in roles])

    def post(self, request):
        data = request.data
        max_holders = data.get("max_holders")
        try:
            max_holders = int(max_holders) if max_holders not in (None, "") else None
            if max_holders is not None and max_holders < 1:
                raise ValueError("A position needs room for at least one person.")
            copy_from = Role.objects.filter(pk=data["copy_from"]).first() if data.get("copy_from") else None
            assistant_of = Role.objects.filter(pk=data["assistant_of"]).first() if data.get("assistant_of") else None
            role = services.create_position(
                name=data.get("name", ""), description=data.get("description", ""), max_holders=max_holders,
                copy_from=copy_from, assistant_of=assistant_of, by=request.user, request=request,
            )
        except (ValueError, PermissionError) as exc:
            return _error(exc)
        return Response(_position_row(role, {}), status=status.HTTP_201_CREATED)


class PositionAssignView(APIView):
    """{user_id} or {member_id}, optional job_title."""

    permission_classes = [IsAuthenticated, require_permission("accesscontrol.assign_roles")]

    def post(self, request, pk):
        from members.models import Member

        role = get_object_or_404(Role, pk=pk)
        if request.data.get("member_id"):
            member = get_object_or_404(Member, pk=request.data["member_id"])
            if member.user_id is None:
                return Response({"detail": f"{member.full_name} has no login yet."}, status=status.HTTP_400_BAD_REQUEST)
            user = member.user
        else:
            user = get_object_or_404(User, pk=request.data.get("user_id"))
        try:
            services.assign_role(role=role, user=user, job_title=request.data.get("job_title", ""),
                                 by=request.user, request=request)
        except (ValueError, PermissionError) as exc:
            return _error(exc)
        return Response({"detail": "Assigned."})


class MembershipRemoveView(APIView):
    permission_classes = [IsAuthenticated, require_permission("accesscontrol.assign_roles")]

    def post(self, request, pk):
        membership = get_object_or_404(Membership.objects.select_related("role", "user"), pk=pk)
        try:
            services.remove_role(membership=membership, by=request.user, request=request)
        except (ValueError, PermissionError) as exc:
            return _error(exc)
        return Response({"detail": "Removed."})


class UserPositionsView(generics.GenericAPIView):
    """The roles one person holds (for the user detail screen)."""

    permission_classes = [IsAuthenticated, require_permission("users.view")]

    def get(self, request, pk):
        user = get_object_or_404(services.tenant_users(), pk=pk)
        memberships = Membership.objects.filter(user=user, is_active=True).select_related("role")
        return Response([
            {"membership_id": str(m.pk), "role_id": str(m.role_id), "role_name": m.role.name,
             "job_title": m.job_title, "assigned_at": m.assigned_at,
             "automatic": m.role.name in services.AUTOMATIC_ROLES}
            for m in memberships
        ])
