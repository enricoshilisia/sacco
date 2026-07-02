import uuid

from django.conf import settings
from django.db import models

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
    PASSPORT_PHOTO = "PASSPORT_PHOTO"
    PROOF_OF_ADDRESS = "PROOF_OF_ADDRESS"
    OTHER = "OTHER"
    DOCUMENT_TYPE_CHOICES = [
        (NATIONAL_ID_DOC, "ID document"),
        (PASSPORT_PHOTO, "Passport photo"),
        (PROOF_OF_ADDRESS, "Proof of address"),
        (OTHER, "Other"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name="documents")
    document_type = models.CharField(max_length=20, choices=DOCUMENT_TYPE_CHOICES)
    file = models.FileField(upload_to=member_document_path)
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
