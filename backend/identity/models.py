import uuid

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.db import models
from django.utils import timezone


class UserManager(BaseUserManager):
    def create_user(self, phone_number, email=None, password=None, **extra_fields):
        if not phone_number:
            raise ValueError("Users must have a phone number")
        email = self.normalize_email(email) if email else None
        user = self.model(phone_number=phone_number, email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, phone_number, email=None, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        return self.create_user(phone_number, email, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    """
    Shared (public schema) - a person can belong to more than one SACCO.
    Login identity is the phone number (SMS/USSD-first user base); email is
    optional. Per-tenant role assignment lives in accesscontrol.Membership
    inside each tenant's schema.
    """

    LANGUAGE_CHOICES = [("en", "English"), ("sw", "Kiswahili")]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone_number = models.CharField(max_length=20, unique=True)
    email = models.EmailField(blank=True, null=True)
    first_name = models.CharField(max_length=150, blank=True)
    last_name = models.CharField(max_length=150, blank=True)

    preferred_language = models.CharField(
        max_length=5, choices=LANGUAGE_CHOICES, default="en"
    )

    is_phone_verified = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)  # platform_admin staff, not tenant role
    date_joined = models.DateTimeField(default=timezone.now)

    objects = UserManager()

    USERNAME_FIELD = "phone_number"
    REQUIRED_FIELDS = []

    class Meta:
        pass

    def __str__(self):
        return self.phone_number

    def get_full_name(self):
        return f"{self.first_name} {self.last_name}".strip() or self.phone_number

    def get_short_name(self):
        return self.first_name or self.phone_number


class TenantAccess(models.Model):
    """
    Which SACCOs a user can log into. Kept in the public schema so the
    login/tenant-picker flow doesn't need to probe every tenant schema.
    The actual role for that tenant lives in accesscontrol.Membership,
    inside that tenant's own schema.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="tenant_access")
    tenant = models.ForeignKey("tenants.Tenant", on_delete=models.CASCADE, related_name="member_access")
    is_active = models.BooleanField(default=True)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "tenant")

    def __str__(self):
        return f"{self.user} @ {self.tenant}"


class WebAuthnCredential(models.Model):
    """
    A registered biometric/passkey credential (Touch ID, Face ID, Windows
    Hello, Android fingerprint, security key) for a user. The private key
    never leaves the user's device/authenticator - we only ever store the
    public key and a signature counter.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="webauthn_credentials")

    credential_id = models.TextField(unique=True)  # base64url, from the authenticator
    public_key = models.TextField()  # base64url-encoded COSE public key
    sign_count = models.PositiveBigIntegerField(default=0)
    transports = models.JSONField(default=list, blank=True)  # e.g. ["internal", "hybrid"]

    device_name = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_used_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = "WebAuthn credential"

    def __str__(self):
        return f"{self.device_name or 'credential'} for {self.user}"


class WebAuthnChallenge(models.Model):
    """
    Short-lived server-side challenge for a registration or authentication
    ceremony in progress. Cleared/expired after use - see
    identity.services.webauthn for the TTL check.
    """

    REGISTRATION = "registration"
    AUTHENTICATION = "authentication"
    CHALLENGE_TYPES = [(REGISTRATION, "Registration"), (AUTHENTICATION, "Authentication")]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="webauthn_challenges")
    challenge_type = models.CharField(max_length=20, choices=CHALLENGE_TYPES)
    challenge = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def is_expired(self):
        return timezone.now() >= self.expires_at


class PushDeviceToken(models.Model):
    """A Firebase Cloud Messaging registration token for one of a user's devices."""

    WEB = "web"
    ANDROID = "android"
    IOS = "ios"
    PLATFORM_CHOICES = [(WEB, "Web"), (ANDROID, "Android"), (IOS, "iOS")]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="push_tokens")
    token = models.TextField(unique=True)
    platform = models.CharField(max_length=10, choices=PLATFORM_CHOICES, default=WEB)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.platform} token for {self.user}"
