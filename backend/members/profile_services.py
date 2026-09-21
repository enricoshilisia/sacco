"""
Member profile, family register, documents and the approval workflow.

Identity details and the family register are protected: once a profile is
approved, a member (or staff on their behalf) can't edit them directly -
they submit a ProfileChangeRequest, and an approver (members.approve_changes,
the Secretary by default) applies or rejects it. Basic contact details
(email, address, occupation...) stay freely editable.
"""

import re
from datetime import date

from django.db import IntegrityError, transaction
from django.utils import timezone

from core.images import InvalidImage, normalize_image

from .models import (
    ChangeRequestStatus,
    ChangeRequestTarget,
    FamilyMember,
    FamilyMemberStatus,
    Member,
    MemberDocument,
    ProfileChangeRequest,
    ProfileStatus,
)

# Changing any of these after approval needs an approved change request.
PROTECTED_MEMBER_FIELDS = [
    "first_name", "last_name", "other_names", "date_of_birth", "gender",
    "id_type", "id_number", "phone_number", "marital_status",
]
# Members update these themselves, any time.
FREE_MEMBER_FIELDS = ["email", "physical_address", "occupation", "employer", "county"]
FAMILY_FIELDS = [
    "relationship", "full_name", "date_of_birth", "gender", "id_number",
    "birth_certificate_number", "phone_number", "is_next_of_kin", "is_deceased",
]
DATE_FIELDS = {"date_of_birth"}

MAX_DOCUMENT_BYTES = 15 * 1024 * 1024
DOCUMENT_MAX_SIDE = 2000  # documents need to stay readable, unlike avatars


def _jsonable(value):
    return value.isoformat() if isinstance(value, date) else value


def _from_json(field, value):
    if field in DATE_FIELDS and isinstance(value, str) and value:
        return date.fromisoformat(value)
    return value


def _snapshot(obj, fields):
    return {f: _jsonable(getattr(obj, f)) for f in fields}


def _pending(member, **filters):
    return ProfileChangeRequest.objects.filter(member=member, status=ChangeRequestStatus.PENDING, **filters)


# --- Submitting --------------------------------------------------------------


def submit_profile_changes(*, member: Member, changes: dict, note: str = "", submitted_by=None) -> ProfileChangeRequest:
    """Proposes new values for protected fields. With no changes and a
    not-yet-approved profile, it submits the profile as it stands for its
    first approval."""
    unknown = set(changes) - set(PROTECTED_MEMBER_FIELDS)
    if unknown:
        raise ValueError(f"These fields can't be changed this way: {', '.join(sorted(unknown))}.")
    changes = {f: _jsonable(v) for f, v in changes.items() if _jsonable(getattr(member, f)) != _jsonable(v)}
    if not changes and member.profile_status == ProfileStatus.APPROVED:
        raise ValueError("Nothing has changed.")
    if _pending(member, target=ChangeRequestTarget.PROFILE).exists():
        raise ValueError("You already have personal-detail changes waiting for approval. Cancel them first to send new ones.")
    with transaction.atomic():
        request = ProfileChangeRequest.objects.create(
            member=member, target=ChangeRequestTarget.PROFILE, changes=changes,
            before=_snapshot(member, changes.keys()), note=note, submitted_by=submitted_by,
        )
        if member.profile_status == ProfileStatus.DRAFT:
            member.profile_status = ProfileStatus.PENDING
            member.save(update_fields=["profile_status"])
    return request


def submit_family_add(*, member: Member, data: dict, note: str = "", submitted_by=None) -> ProfileChangeRequest:
    with transaction.atomic():
        person = FamilyMember.objects.create(member=member, status=FamilyMemberStatus.PENDING, **data)
        return ProfileChangeRequest.objects.create(
            member=member, target=ChangeRequestTarget.FAMILY_ADD, family_member=person,
            changes={f: _jsonable(v) for f, v in data.items()}, note=note, submitted_by=submitted_by,
        )


def submit_family_update(*, person: FamilyMember, changes: dict, note: str = "", submitted_by=None) -> ProfileChangeRequest:
    if person.status != FamilyMemberStatus.APPROVED:
        raise ValueError("Only an approved family member can be changed. Cancel the pending request and add them again.")
    changes = {f: _jsonable(v) for f, v in changes.items() if _jsonable(getattr(person, f)) != _jsonable(v)}
    if not changes:
        raise ValueError("Nothing has changed.")
    if _pending(person.member, family_member=person).exists():
        raise ValueError("There's already a change waiting for approval for this person.")
    return ProfileChangeRequest.objects.create(
        member=person.member, target=ChangeRequestTarget.FAMILY_UPDATE, family_member=person,
        changes=changes, before=_snapshot(person, changes.keys()), note=note, submitted_by=submitted_by,
    )


def submit_family_remove(*, person: FamilyMember, note: str = "", submitted_by=None) -> ProfileChangeRequest:
    if person.status != FamilyMemberStatus.APPROVED:
        raise ValueError("Only an approved family member can be removed.")
    if _pending(person.member, family_member=person).exists():
        raise ValueError("There's already a change waiting for approval for this person.")
    return ProfileChangeRequest.objects.create(
        member=person.member, target=ChangeRequestTarget.FAMILY_REMOVE, family_member=person,
        before=_snapshot(person, ["full_name", "relationship"]), note=note, submitted_by=submitted_by,
    )


def cancel_request(request: ProfileChangeRequest, *, by_member: Member) -> None:
    if request.member_id != by_member.pk or request.status != ChangeRequestStatus.PENDING:
        raise ValueError("Only your own pending requests can be cancelled.")
    with transaction.atomic():
        if request.target == ChangeRequestTarget.FAMILY_ADD:
            request.family_member.delete()  # cascades to this request
            return
        request.delete()
        member = by_member
        if (member.profile_status == ProfileStatus.PENDING
                and not _pending(member, target=ChangeRequestTarget.PROFILE).exists()):
            member.profile_status = ProfileStatus.DRAFT
            member.save(update_fields=["profile_status"])


# --- Deciding ----------------------------------------------------------------


def _check_approver(request: ProfileChangeRequest, user):
    if request.status != ChangeRequestStatus.PENDING:
        raise ValueError("This request has already been decided.")
    if user is not None and request.member.user_id == user.pk:
        raise ValueError("You can't approve changes to your own profile.")


def approve_request(request: ProfileChangeRequest, *, approved_by, notes: str = "") -> ProfileChangeRequest:
    with transaction.atomic():
        request = ProfileChangeRequest.objects.select_for_update(of=("self",)).select_related("member", "family_member").get(pk=request.pk)
        _check_approver(request, approved_by)
        now = timezone.now()
        member = request.member
        try:
            if request.target == ChangeRequestTarget.PROFILE:
                for field, value in request.changes.items():
                    setattr(member, field, _from_json(field, value))
                member.profile_status = ProfileStatus.APPROVED
                member.is_kyc_verified = True
                member.kyc_verified_at = now
                member.kyc_verified_by = approved_by
                member.updated_by = approved_by
                member.save()
            else:
                person = request.family_member
                if request.target == ChangeRequestTarget.FAMILY_ADD:
                    person.status = FamilyMemberStatus.APPROVED
                    person.approved_at = now
                elif request.target == ChangeRequestTarget.FAMILY_UPDATE:
                    for field, value in request.changes.items():
                        setattr(person, field, _from_json(field, value))
                elif request.target == ChangeRequestTarget.FAMILY_REMOVE:
                    person.status = FamilyMemberStatus.REMOVED
                person.save()
        except IntegrityError:
            raise ValueError("Another member is already registered with that ID number.")
        request.status = ChangeRequestStatus.APPROVED
        request.decided_by = approved_by
        request.decided_at = now
        request.decision_notes = notes
        request.save(update_fields=["status", "decided_by", "decided_at", "decision_notes"])
    return request


def reject_request(request: ProfileChangeRequest, *, rejected_by, notes: str) -> ProfileChangeRequest:
    with transaction.atomic():
        request = ProfileChangeRequest.objects.select_for_update(of=("self",)).select_related("member", "family_member").get(pk=request.pk)
        _check_approver(request, rejected_by)
        if request.target == ChangeRequestTarget.FAMILY_ADD:
            request.family_member.status = FamilyMemberStatus.REJECTED
            request.family_member.save(update_fields=["status"])
        member = request.member
        if request.target == ChangeRequestTarget.PROFILE and member.profile_status == ProfileStatus.PENDING:
            member.profile_status = ProfileStatus.DRAFT
            member.save(update_fields=["profile_status"])
        request.status = ChangeRequestStatus.REJECTED
        request.decided_by = rejected_by
        request.decided_at = timezone.now()
        request.decision_notes = notes
        request.save(update_fields=["status", "decided_by", "decided_at", "decision_notes"])
    return request


# --- Documents -----------------------------------------------------------------


def _digits(value: str) -> str:
    return re.sub(r"\D", "", value or "")


def upload_document(
    *, member: Member, document_type: str, uploaded, family_member: FamilyMember | None = None,
    ocr_id_number: str = "", uploaded_by=None,
) -> MemberDocument:
    """
    Stores a KYC document. Photos in any format (HEIC, huge JPEG, PNG...) are
    straightened and resized to a readable JPEG; PDFs are kept as they are.
    For ID scans, records whether the number the phone read matches the ID
    number on record - guidance for the approver, never a verification on
    its own (they compare the image themselves).
    """
    if uploaded.size and uploaded.size > MAX_DOCUMENT_BYTES:
        raise ValueError("That file is larger than 15 MB.")
    if family_member is not None and family_member.member_id != member.pk:
        raise ValueError("That family member isn't on your register.")

    uploaded.seek(0)
    head = uploaded.read(5)
    uploaded.seek(0)
    if head == b"%PDF-":
        stored = uploaded
        stored.name = "document.pdf"
    else:
        try:
            stored = normalize_image(uploaded, name="document.jpg", max_side=DOCUMENT_MAX_SIDE)
        except InvalidImage as exc:
            raise ValueError(str(exc).replace("image", "photo or PDF", 1))

    match = None
    if ocr_id_number:
        on_record = (family_member.id_number if family_member else member.id_number) or ""
        match = bool(_digits(on_record)) and _digits(ocr_id_number) == _digits(on_record)

    return MemberDocument.objects.create(
        member=member, document_type=document_type, file=stored, family_member=family_member,
        ocr_id_number=ocr_id_number[:50], id_number_match=match, uploaded_by=uploaded_by,
    )
