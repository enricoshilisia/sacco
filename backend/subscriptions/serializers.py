from rest_framework import serializers

from identity.models import User
from tenants.models import Country


class SaccoSignupSerializer(serializers.Serializer):
    sacco_name = serializers.CharField(max_length=255)
    country = serializers.ChoiceField(choices=Country.choices)

    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150)
    phone_number = serializers.CharField(max_length=20)
    password = serializers.CharField(write_only=True, min_length=8)

    def validate_phone_number(self, value):
        if User.objects.filter(phone_number=value).exists():
            raise serializers.ValidationError(
                "An account with this phone number already exists. Log in and use "
                "your existing account instead of signing up again."
            )
        return value
