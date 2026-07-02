from rest_framework import serializers

from .models import GuarantorConsent, Member, MemberRelation


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
            "phone_number", "id_type", "id_number", "is_kyc_verified", "date_joined",
        ]


class MemberSerializer(serializers.ModelSerializer):
    relations = MemberRelationSerializer(many=True, required=False)

    class Meta:
        model = Member
        fields = [
            "id", "member_number", "user", "category", "status",
            "first_name", "last_name", "other_names", "date_of_birth", "gender",
            "id_type", "id_number", "phone_number", "email", "physical_address",
            "is_kyc_verified", "kyc_verified_at", "date_joined", "created_at", "relations",
        ]
        read_only_fields = ["id", "member_number", "is_kyc_verified", "kyc_verified_at", "date_joined", "created_at"]

    def _generate_member_number(self):
        count = Member.objects.count() + 1
        candidate = f"M-{count:05d}"
        while Member.objects.filter(member_number=candidate).exists():
            count += 1
            candidate = f"M-{count:05d}"
        return candidate

    def create(self, validated_data):
        relations_data = validated_data.pop("relations", [])
        validated_data["member_number"] = self._generate_member_number()
        request = self.context.get("request")
        if request is not None:
            validated_data["created_by"] = request.user
        member = Member.objects.create(**validated_data)
        for relation in relations_data:
            MemberRelation.objects.create(member=member, **relation)
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
