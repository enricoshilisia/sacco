from rest_framework import serializers

from .models import LoanEligibilityPolicy


class LoanEligibilityPolicySerializer(serializers.ModelSerializer):
    class Meta:
        model = LoanEligibilityPolicy
        fields = [
            "id", "product", "is_active",
            "require_kyc_verified", "require_no_active_arrears", "max_active_loans",
            "min_membership_months", "min_guarantor_coverage_ratio",
            "require_crb_check", "crb_deny_below_score", "crb_refer_below_score",
            "created_at", "updated_at",
        ]
        read_only_fields = ["id", "product", "created_at", "updated_at"]
