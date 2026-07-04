from rest_framework import serializers

from .models import GuarantorConsent, Member, MemberPortalInvite, MemberRelation
from .services import generate_member_number


class MemberRelationSerializer(serializers.ModelSerializer):
    class Meta:
        model = MemberRelation
        fields = ["id", "kind", "full_name", "relationship", "phone_number", "id_number", "benefit_percentage"]
        read_only_fields = ["id"]


class MemberListSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(read_only=True)

    class Meta:
        model = Member
        fields = [
            "id", "member_number", "full_name", "category", "status",
            "phone_number", "id_type", "id_number", "is_kyc_verified", "date_joined", "photo",
        ]


class MemberSerializer(serializers.ModelSerializer):
    relations = MemberRelationSerializer(many=True, required=False)

    class Meta:
        model = Member
        fields = [
            "id", "member_number", "user", "category", "status",
            "first_name", "last_name", "other_names", "date_of_birth", "gender",
            "id_type", "id_number", "phone_number", "email", "physical_address", "photo",
            "is_kyc_verified", "kyc_verified_at", "date_joined", "created_at", "relations",
        ]
        read_only_fields = [
            "id", "member_number", "photo", "is_kyc_verified", "kyc_verified_at",
            "date_joined", "created_at",
        ]

    def create(self, validated_data):
        relations_data = validated_data.pop("relations", [])
        validated_data["member_number"] = generate_member_number()
        request = self.context.get("request")
        if request is not None:
            validated_data["created_by"] = request.user
        member = Member.objects.create(**validated_data)
        for relation in relations_data:
            MemberRelation.objects.create(member=member, **relation)
        # Members don't create their own accounts (no open self-registration
        # - a real cooperative registers the member first, on paper/by
        # staff). So every new member gets a self-service setup link
        # automatically, right away, instead of staff having to remember a
        # separate "invite to portal" step afterward.
        MemberPortalInvite.objects.create(
            member=member, invited_by=request.user if request else None
        )
        return member

    def update(self, instance, validated_data):
        relations_data = validated_data.pop("relations", None)
        request = self.context.get("request")
        if request is not None:
            instance.updated_by = request.user
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if relations_data is not None:
            instance.relations.all().delete()
            for relation in relations_data:
                MemberRelation.objects.create(member=instance, **relation)
        return instance


class MyMemberSerializer(MemberSerializer):
    """
    Self-service view/edit of one's own member record. Reuses
    MemberSerializer's fields and update() (so `updated_by` still gets set
    from context) but locks down everything except contact details -
    identity/KYC fields (name, DOB, gender, ID type/number) and
    membership status/category are staff-mediated changes only, since
    changing them silently would invalidate the KYC verification already
    on file. Only phone_number, email and physical_address are writable
    here; the staff-facing MemberSerializer (any field, gated by
    members.edit) is the one used for a real KYC-reviewed correction.
    """

    class Meta(MemberSerializer.Meta):
        read_only_fields = MemberSerializer.Meta.read_only_fields + [
            "user", "category", "status", "first_name", "last_name", "other_names",
            "date_of_birth", "gender", "id_type", "id_number", "relations",
        ]


class MemberPhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Member
        fields = ["photo"]


class GuarantorConsentSerializer(serializers.ModelSerializer):
    guarantor_name = serializers.CharField(source="guarantor.full_name", read_only=True)
    borrower_name = serializers.CharField(source="borrower.full_name", read_only=True)

    class Meta:
        model = GuarantorConsent
        fields = [
            "id", "guarantor", "guarantor_name", "borrower", "borrower_name",
            "status", "requested_at", "responded_at",
        ]
        read_only_fields = ["id", "status", "requested_at", "responded_at"]


class MemberPortalInviteSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source="member.full_name", read_only=True)
    member_number = serializers.CharField(source="member.member_number", read_only=True)
    status = serializers.CharField(read_only=True)
    invite_path = serializers.SerializerMethodField()

    class Meta:
        model = MemberPortalInvite
        fields = [
            "id", "member", "member_name", "member_number", "token",
            "status", "created_at", "expires_at", "invite_path",
        ]
        read_only_fields = ["id", "token", "status", "created_at", "expires_at"]

    def get_invite_path(self, obj) -> str:
        return f"/members-portal/accept/{obj.token}"
