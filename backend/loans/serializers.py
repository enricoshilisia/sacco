from decimal import Decimal

from rest_framework import serializers

from members.models import Member

from .models import Loan, LoanGuarantor, LoanProduct


class LoanProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = LoanProduct
        fields = [
            "id", "name", "code", "interest_method", "interest_rate",
            "min_term_months", "max_term_months", "max_multiple_of_deposits",
            "requires_guarantors", "min_guarantors", "is_active",
        ]


class LoanGuarantorSerializer(serializers.ModelSerializer):
    guarantor_name = serializers.CharField(source="guarantor.full_name", read_only=True)
    guarantor_member_number = serializers.CharField(source="guarantor.member_number", read_only=True)
    borrower_name = serializers.CharField(source="loan.member.full_name", read_only=True)

    class Meta:
        model = LoanGuarantor
        fields = [
            "id", "loan", "guarantor", "guarantor_name", "guarantor_member_number", "borrower_name",
            "pledged_amount", "status", "requested_at", "responded_at", "released_at",
        ]
        read_only_fields = ["id", "status", "requested_at", "responded_at", "released_at"]


class LoanSerializer(serializers.ModelSerializer):
    member_name = serializers.CharField(source="member.full_name", read_only=True)
    member_number = serializers.CharField(source="member.member_number", read_only=True)
    product_name = serializers.CharField(source="product.name", read_only=True)
    guarantors = LoanGuarantorSerializer(many=True, read_only=True)
    appraised_by_name = serializers.CharField(source="appraised_by.get_full_name", read_only=True, default=None)
    decided_by_name = serializers.CharField(source="decided_by.get_full_name", read_only=True, default=None)

    class Meta:
        model = Loan
        fields = [
            "id", "member", "member_name", "member_number", "product", "product_name",
            "amount_requested", "term_months", "purpose", "interest_method", "interest_rate",
            "status", "applied_at", "appraised_at", "appraised_by_name", "appraisal_notes",
            "decided_at", "decided_by_name", "decision_notes", "guarantors",
        ]


class LoanApplyInputSerializer(serializers.Serializer):
    product = serializers.PrimaryKeyRelatedField(queryset=LoanProduct.objects.filter(is_active=True))
    amount_requested = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0.01"))
    term_months = serializers.IntegerField(min_value=1)
    purpose = serializers.CharField(required=False, allow_blank=True, default="")


class AddGuarantorInputSerializer(serializers.Serializer):
    guarantor = serializers.PrimaryKeyRelatedField(queryset=Member.objects.all())
    pledged_amount = serializers.DecimalField(max_digits=18, decimal_places=2, min_value=Decimal("0.01"))


class RespondGuaranteeInputSerializer(serializers.Serializer):
    accept = serializers.BooleanField()


class AppraiseInputSerializer(serializers.Serializer):
    notes = serializers.CharField(required=False, allow_blank=True, default="")


class DecideInputSerializer(serializers.Serializer):
    approved = serializers.BooleanField()
    notes = serializers.CharField(required=False, allow_blank=True, default="")
