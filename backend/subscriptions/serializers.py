from rest_framework import serializers

from identity.models import User
from tenants.models import Country


class SaccoSignupSerializer(serializers.Serializer):
    sacco_name = serializers.CharField(max_length=255)
    country = serializers.ChoiceField(choices=Country.choices)
    address = serializers.CharField(required=False, allow_blank=True, default="")
    contact_email = serializers.EmailField(required=False, allow_blank=True, default="")
    contact_phone = serializers.CharField(max_length=20, required=False, allow_blank=True, default="")

    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150)
    phone_number = serializers.CharField(max_length=20)
    email = serializers.EmailField()
    job_title = serializers.CharField(max_length=100, required=False, allow_blank=True, default="")
    password = serializers.CharField(write_only=True, min_length=8)

    def validate_phone_number(self, value):
        if User.objects.filter(phone_number=value).exists():
            raise serializers.ValidationError(
                "An account with this phone number already exists. Log in and use "
                "your existing account instead of signing up again."
            )
        return value
