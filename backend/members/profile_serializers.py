from datetime import date

from rest_framework import serializers

from configuration.models import IdType

from .models import (
    FamilyMember,
    FamilyRelationship,
    Gender,
    MaritalStatus,
    MemberDocument,
    ProfileChangeRequest,
)


class FamilyMemberSerializer(serializers.ModelSerializer):
    relationship_label = serializers.CharField(source="get_relationship_display", read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    age = serializers.SerializerMethodField()

    class Meta:
        model = FamilyMember
        fields = [
            "id", "relationship", "relationship_label", "full_name", "date_of_birth", "age", "gender",
            "id_number", "birth_certificate_number", "phone_number", "is_next_of_kin", "is_deceased",
            "status", "status_label", "approved_at",
        ]

    def get_age(self, person):
        return person.age_on(date.today())


class FamilyInputSerializer(serializers.Serializer):
    """Validates a family member's details (all optional on update)."""

    relationship = serializers.ChoiceField(choices=FamilyRelationship.choices)
    full_name = serializers.CharField(max_length=255)
    date_of_birth = serializers.DateField(required=False, allow_null=True)
    gender = serializers.ChoiceField(choices=Gender.choices, required=False, allow_blank=True)
    id_number = serializers.CharField(max_length=50, required=False, allow_blank=True)
    birth_certificate_number = serializers.CharField(max_length=50, required=False, allow_blank=True)
    phone_number = serializers.CharField(max_length=20, required=False, allow_blank=True)
    is_next_of_kin = serializers.BooleanField(required=False)
    is_deceased = serializers.BooleanField(required=False)

    def validate_date_of_birth(self, value):
        if value and value > date.today():
            raise serializers.ValidationError("Date of birth can't be in the future.")
        return value

    def validate(self, attrs):
        if not self.partial and attrs.get("relationship") == FamilyRelationship.CHILD and not attrs.get("date_of_birth"):
            raise serializers.ValidationError({"date_of_birth": "A child's date of birth is needed for welfare cover."})
        return attrs


class ProfileChangesSerializer(serializers.Serializer):
    """New values for protected personal details - every field optional."""

    first_name = serializers.CharField(max_length=150, required=False)
    last_name = serializers.CharField(max_length=150, required=False)
    other_names = serializers.CharField(max_length=150, required=False, allow_blank=True)
    date_of_birth = serializers.DateField(required=False, allow_null=True)
    gender = serializers.ChoiceField(choices=Gender.choices, required=False, allow_blank=True)
    id_type = serializers.ChoiceField(choices=IdType.choices, required=False)
    id_number = serializers.CharField(max_length=50, required=False)
    phone_number = serializers.CharField(max_length=20, required=False)
    marital_status = serializers.ChoiceField(choices=MaritalStatus.choices, required=False, allow_blank=True)

    def validate_date_of_birth(self, value):
        if value and value > date.today():
            raise serializers.ValidationError("Date of birth can't be in the future.")
        return value


class MemberDocumentSerializer(serializers.ModelSerializer):
    document_type_label = serializers.CharField(source="get_document_type_display", read_only=True)
    family_member_name = serializers.CharField(source="family_member.full_name", read_only=True, default=None)
    file = serializers.FileField(read_only=True, use_url=True)

    class Meta:
        model = MemberDocument
        fields = [
            "id", "document_type", "document_type_label", "family_member", "family_member_name",
            "file", "ocr_id_number", "id_number_match", "uploaded_at",
        ]


class DocumentUploadSerializer(serializers.Serializer):
    document_type = serializers.ChoiceField(choices=MemberDocument.DOCUMENT_TYPE_CHOICES)
    file = serializers.FileField()
    family_member = serializers.UUIDField(required=False, allow_null=True)
    ocr_id_number = serializers.CharField(max_length=50, required=False, allow_blank=True, default="")


class ChangeRequestSerializer(serializers.ModelSerializer):
    target_label = serializers.CharField(source="get_target_display", read_only=True)
    status_label = serializers.CharField(source="get_status_display", read_only=True)
    member_id = serializers.UUIDField(source="member.id", read_only=True)
    member_number = serializers.CharField(source="member.member_number", read_only=True)
    member_name = serializers.CharField(source="member.full_name", read_only=True)
    member_profile_status = serializers.CharField(source="member.profile_status", read_only=True)
    family_member = FamilyMemberSerializer(read_only=True)
    decided_by_name = serializers.CharField(source="decided_by.get_full_name", read_only=True, default=None)
    documents = serializers.SerializerMethodField()
    current = serializers.SerializerMethodField()

    class Meta:
        model = ProfileChangeRequest
        fields = [
            "id", "target", "target_label", "status", "status_label", "member_id", "member_number", "member_name",
            "member_profile_status", "family_member", "changes", "before", "current", "note", "submitted_at",
            "decided_by_name", "decided_at", "decision_notes", "documents",
        ]

    def get_current(self, request):
        """For a first profile approval: everything on record, so the approver
        reviews the whole profile, not just the (possibly empty) changes."""
        if request.target != "PROFILE":
            return {}
        from .profile_services import PROTECTED_MEMBER_FIELDS, _snapshot

        return _snapshot(request.member, PROTECTED_MEMBER_FIELDS)

    def get_documents(self, request):
        """The documents relevant to deciding: the family member's for a family
        change, the member's own ID documents for a profile change."""
        docs = MemberDocument.objects.filter(member=request.member)
        docs = docs.filter(family_member=request.family_member) if request.family_member_id else docs.filter(
            family_member__isnull=True
        )
        return MemberDocumentSerializer(docs.order_by("-uploaded_at")[:10], many=True, context=self.context).data
