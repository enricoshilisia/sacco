import secrets
import uuid
from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone

from configuration.models import IdType
from core.models import AuditMixin


class MemberCategory(models.TextChoices):
    ORDINARY = "ORDINARY", "Ordinary"
    ASSOCIATE = "ASSOCIATE", "Associate"
    JUNIOR = "JUNIOR", "Junior"
    CORPORATE = "CORPORATE", "Corporate"


class MemberStatus(models.TextChoices):
    ACTIVE = "ACTIVE", "Active"
    DORMANT = "DORMANT", "Dormant"
    EXITED = "EXITED", "Exited"


class MaritalStatus(models.TextChoices):
    SINGLE = "SINGLE", "Single"
    MARRIED = "MARRIED", "Married"
    WIDOWED = "WIDOWED", "Widowed"
    DIVORCED = "DIVORCED", "Divorced / separated"


class ProfileStatus(models.TextChoices):
    """Where a member's profile stands. Once APPROVED, identity details and
    the family register are locked: changes go through ProfileChangeRequest."""

    DRAFT = "DRAFT", "Not yet submitted"
    PENDING = "PENDING", "Awaiting approval"
    APPROVED = "APPROVED", "Approved"


class Gender(models.TextChoices):
    FEMALE = "FEMALE", "Female"
    MALE = "MALE", "Male"
    OTHER = "OTHER", "Other"


def member_photo_path(instance, filename):
    return f"members/{instance.id}/photo/{filename}"


class Member(AuditMixin, models.Model):
    """
    The membership record itself - distinct from identity.User. A member is
    commonly registered by branch staff before they ever have (or want) a
    login account, so `user` is an optional link, not a requirement.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member_number = models.CharField(max_length=20, unique=True)

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="member_records",
        help_text="Linked once this member has (or is given) self-service login access.",
    )

    category = models.CharField(max_length=20, choices=MemberCategory.choices, default=MemberCategory.ORDINARY)
    status = models.CharField(max_length=20, choices=MemberStatus.choices, default=MemberStatus.ACTIVE)

    first_name = models.CharField(max_length=150)
    last_name = models.CharField(max_length=150)
    other_names = models.CharField(max_length=150, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=10, choices=Gender.choices, blank=True)

    id_type = models.CharField(max_length=20, choices=IdType.choices)
    id_number = models.CharField(max_length=50)

    phone_number = models.CharField(max_length=20)
    email = models.EmailField(blank=True)
    physical_address = models.TextField(blank=True)
    photo = models.ImageField(upload_to=member_photo_path, blank=True, null=True)

    # Personal details. Marital status is identity data (approval needed);
    # occupation/employer/county are basic data members may update freely.
    marital_status = models.CharField(max_length=10, choices=MaritalStatus.choices, blank=True)
    occupation = models.CharField(max_length=120, blank=True)
    employer = models.CharField(max_length=150, blank=True)
    county = models.CharField(max_length=80, blank=True, help_text="County / region of residence.")
    profile_status = models.CharField(max_length=10, choices=ProfileStatus.choices, default=ProfileStatus.DRAFT)

    is_kyc_verified = models.BooleanField(default=False)
    kyc_verified_at = models.DateTimeField(null=True, blank=True)
    kyc_verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )

    date_joined = models.DateField(auto_now_add=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ("id_type", "id_number")
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.member_number} - {self.first_name} {self.last_name}"

    def full_name(self):
        return " ".join(filter(None, [self.first_name, self.other_names, self.last_name]))


def _generate_portal_invite_token():
    return secrets.token_urlsafe(32)


def _default_portal_invite_expiry():
    return timezone.now() + timedelta(days=7)


class MemberPortalInvite(models.Model):
    """
    A one-time link letting an EXISTING Member record set up self-service
    login access. Unlike accesscontrol.StaffInvite there's no name/role to
    collect - the Member row already exists (a real cooperative registers
    the member first, usually on paper at a branch; login access is a
    separate, later step), so this just links Member.user once accepted.
    Same token-based pattern as staff invites: no SMS/email delivery
    exists yet (Phase 3 notifications only sends after an event, it has no
    "invite" template), so an admin copies the link and shares it
    out of band until that's wired up.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name="portal_invites")
    token = models.CharField(max_length=64, unique=True, default=_generate_portal_invite_token, editable=False)

    invited_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(default=_default_portal_invite_expiry)
    accepted_at = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Portal invite for {self.member}"

    @property
    def status(self) -> str:
        if self.accepted_at:
            return "accepted"
        if self.revoked_at:
            return "revoked"
        if self.expires_at <= timezone.now():
            return "expired"
        return "pending"


class MemberRelationKind(models.TextChoices):
    NEXT_OF_KIN = "NEXT_OF_KIN", "Next of kin"
    NOMINEE = "NOMINEE", "Nominee"
    BENEFICIARY = "BENEFICIARY", "Beneficiary"


class MemberRelation(models.Model):
    """
    Next-of-kin, nominee, or beneficiary attached to a member. Modeled as
    one table with a `kind` discriminator rather than three separate ones -
    they share the same shape (a named relation with contact/ID details),
    and a real person is very often more than one of these at once (e.g. a
    spouse who is both next-of-kin and beneficiary).
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name="relations")

    kind = models.CharField(max_length=20, choices=MemberRelationKind.choices)
    full_name = models.CharField(max_length=255)
    relationship = models.CharField(max_length=50, help_text="e.g. spouse, child, parent, sibling")
    phone_number = models.CharField(max_length=20, blank=True)
    id_number = models.CharField(max_length=50, blank=True)

    # Only meaningful for kind=BENEFICIARY; shares across a member's
    # beneficiaries should sum to 100 but that's a UI-level nudge, not
    # enforced here - a member mid-update may temporarily be over/under.
    benefit_percentage = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.full_name} ({self.get_kind_display()}) for {self.member}"


class GuarantorConsentStatus(models.TextChoices):
    PENDING = "PENDING", "Pending"
    CONSENTED = "CONSENTED", "Consented"
    DECLINED = "DECLINED", "Declined"


class GuarantorConsent(models.Model):
    """
    The guarantor relationship graph, structure only. This records who has
    agreed to guarantee whom and whether they've consented - it does NOT
    lock any deposits or compute available-to-borrow amounts. That's real
    pledge accounting and belongs to the `loans` app (Phase 4), once an
    actual loan exists to pledge against.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    guarantor = models.ForeignKey(Member, on_delete=models.CASCADE, related_name="guaranteeing_for")
    borrower = models.ForeignKey(Member, on_delete=models.CASCADE, related_name="guarantors")

    status = models.CharField(max_length=20, choices=GuarantorConsentStatus.choices, default=GuarantorConsentStatus.PENDING)
    requested_at = models.DateTimeField(auto_now_add=True)
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ("guarantor", "borrower")

    def __str__(self):
        return f"{self.guarantor} guarantees {self.borrower} ({self.status})"


def member_document_path(instance, filename):
    return f"members/{instance.member_id}/documents/{filename}"


class MemberDocument(models.Model):
    """KYC/supporting documents. Stored via the tenant's configured S3/MinIO backend."""

    NATIONAL_ID_DOC = "ID_DOCUMENT"
    ID_FRONT = "ID_FRONT"
    ID_BACK = "ID_BACK"
    BIRTH_CERTIFICATE = "BIRTH_CERT"
    MARRIAGE_CERTIFICATE = "MARRIAGE_CERT"
    PASSPORT_PHOTO = "PASSPORT_PHOTO"
    PROOF_OF_ADDRESS = "PROOF_OF_ADDRESS"
    OTHER = "OTHER"
    DOCUMENT_TYPE_CHOICES = [
        (NATIONAL_ID_DOC, "ID document"),
        (ID_FRONT, "ID card - front"),
        (ID_BACK, "ID card - back"),
        (BIRTH_CERTIFICATE, "Birth certificate"),
        (MARRIAGE_CERTIFICATE, "Marriage certificate"),
        (PASSPORT_PHOTO, "Passport photo"),
        (PROOF_OF_ADDRESS, "Proof of address"),
        (OTHER, "Other"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name="documents")
    document_type = models.CharField(max_length=20, choices=DOCUMENT_TYPE_CHOICES)
    file = models.FileField(upload_to=member_document_path)
    # Whose document it is: the member (null) or someone on their family
    # register (a child's birth certificate, a spouse's ID...).
    family_member = models.ForeignKey(
        "FamilyMember", null=True, blank=True, on_delete=models.SET_NULL, related_name="documents"
    )
    # ID scans: the number the phone read from the image, and whether it
    # matched the ID number on record. Guidance for the approver, who still
    # compares the image themselves - the phone's reading isn't trusted alone.
    ocr_id_number = models.CharField(max_length=50, blank=True)
    id_number_match = models.BooleanField(null=True, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="+",
    )

    def __str__(self):
        return f"{self.get_document_type_display()} for {self.member}"


class FamilyRelationship(models.TextChoices):
    SPOUSE = "SPOUSE", "Spouse"
    CHILD = "CHILD", "Child"
    PARENT = "PARENT", "Parent"
    PARENT_IN_LAW = "PARENT_IN_LAW", "Parent-in-law"
    SIBLING = "SIBLING", "Sibling"


class FamilyMemberStatus(models.TextChoices):
    PENDING = "PENDING", "Awaiting approval"
    APPROVED = "APPROVED", "Approved"
    REJECTED = "REJECTED", "Rejected"
    REMOVED = "REMOVED", "Removed"


class FamilyMember(models.Model):
    """
    One person on a member's family register: spouse, children, parents,
    parents-in-law, siblings. Only APPROVED entries count - they're who
    welfare cases can be opened for (welfare.WelfareCaseType.covers says
    which relationships each kind of case covers). Entries are added,
    changed and removed only through an approved ProfileChangeRequest;
    removal keeps the row (status REMOVED) for the audit trail.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name="family")
    relationship = models.CharField(max_length=20, choices=FamilyRelationship.choices)
    full_name = models.CharField(max_length=255)
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=10, choices=Gender.choices, blank=True)
    id_number = models.CharField(max_length=50, blank=True, help_text="National ID / NIDA, if they have one.")
    birth_certificate_number = models.CharField(max_length=50, blank=True)
    phone_number = models.CharField(max_length=20, blank=True)
    is_next_of_kin = models.BooleanField(default=False)
    is_deceased = models.BooleanField(default=False)
    status = models.CharField(max_length=10, choices=FamilyMemberStatus.choices, default=FamilyMemberStatus.PENDING)
    approved_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["relationship", "date_of_birth", "full_name"]

    def __str__(self):
        return f"{self.full_name} ({self.get_relationship_display()} of {self.member.member_number})"

    def age_on(self, day):
        if not self.date_of_birth:
            return None
        dob = self.date_of_birth
        return day.year - dob.year - ((day.month, day.day) < (dob.month, dob.day))


class ChangeRequestStatus(models.TextChoices):
    PENDING = "PENDING", "Awaiting approval"
    APPROVED = "APPROVED", "Approved"
    REJECTED = "REJECTED", "Rejected"


class ChangeRequestTarget(models.TextChoices):
    PROFILE = "PROFILE", "Personal details"
    FAMILY_ADD = "FAMILY_ADD", "Add family member"
    FAMILY_UPDATE = "FAMILY_UPDATE", "Change family member"
    FAMILY_REMOVE = "FAMILY_REMOVE", "Remove family member"


class ProfileChangeRequest(models.Model):
    """
    A requested change to protected member data, applied only when an
    approver (the Secretary, by default) accepts it. `before` is a snapshot
    of the values being replaced and `changes` the new values, so the
    approver sees exactly what changes, and the history keeps it forever.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name="change_requests")
    target = models.CharField(max_length=20, choices=ChangeRequestTarget.choices)
    family_member = models.ForeignKey(
        FamilyMember, null=True, blank=True, on_delete=models.CASCADE, related_name="change_requests"
    )
    changes = models.JSONField(default=dict)
    before = models.JSONField(default=dict)
    note = models.TextField(blank=True, help_text="The member's explanation, e.g. a name change after marriage.")
    status = models.CharField(max_length=10, choices=ChangeRequestStatus.choices, default=ChangeRequestStatus.PENDING)
    submitted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    submitted_at = models.DateTimeField(auto_now_add=True)
    decided_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    decided_at = models.DateTimeField(null=True, blank=True)
    decision_notes = models.TextField(blank=True)

    class Meta:
        ordering = ["-submitted_at"]
