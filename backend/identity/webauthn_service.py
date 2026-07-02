"""
Biometric / passkey authentication (WebAuthn) service layer.

This wraps the `webauthn` package so views stay thin. Two ceremonies:
registration (enrol a fingerprint/Face ID/security key against an already
logged-in user) and authentication (log in using a previously registered
credential instead of a password).
"""

from datetime import timedelta

import webauthn
from django.conf import settings
from django.utils import timezone
from webauthn.helpers import base64url_to_bytes, bytes_to_base64url
from webauthn.helpers.exceptions import InvalidAuthenticationResponse, InvalidRegistrationResponse
from webauthn.helpers.structs import (
    AuthenticationCredential,
    AuthenticatorSelectionCriteria,
    PublicKeyCredentialDescriptor,
    RegistrationCredential,
    ResidentKeyRequirement,
    UserVerificationRequirement,
)

from .models import User, WebAuthnChallenge, WebAuthnCredential

CHALLENGE_TTL_SECONDS = 300


def _store_challenge(user, challenge_type, challenge_bytes):
    WebAuthnChallenge.objects.filter(user=user, challenge_type=challenge_type).delete()
    return WebAuthnChallenge.objects.create(
        user=user,
        challenge_type=challenge_type,
        challenge=bytes_to_base64url(challenge_bytes),
        expires_at=timezone.now() + timedelta(seconds=CHALLENGE_TTL_SECONDS),
    )


def _consume_challenge(user, challenge_type):
    record = (
        WebAuthnChallenge.objects.filter(user=user, challenge_type=challenge_type)
        .order_by("-created_at")
        .first()
    )
    if record is None or record.is_expired():
        return None
    challenge_bytes = base64url_to_bytes(record.challenge)
    record.delete()
    return challenge_bytes


def build_registration_options(user: User):
    exclude = [
        PublicKeyCredentialDescriptor(id=base64url_to_bytes(cred.credential_id))
        for cred in user.webauthn_credentials.all()
    ]
    options = webauthn.generate_registration_options(
        rp_id=settings.WEBAUTHN_RP_ID,
        rp_name=settings.WEBAUTHN_RP_NAME,
        user_id=user.id.bytes,
        user_name=user.phone_number,
        user_display_name=user.get_full_name(),
        exclude_credentials=exclude,
        authenticator_selection=AuthenticatorSelectionCriteria(
            resident_key=ResidentKeyRequirement.PREFERRED,
            user_verification=UserVerificationRequirement.PREFERRED,
        ),
    )
    _store_challenge(user, WebAuthnChallenge.REGISTRATION, options.challenge)
    return webauthn.options_to_json(options)


def verify_registration(user: User, credential_json: dict, device_name: str = ""):
    challenge = _consume_challenge(user, WebAuthnChallenge.REGISTRATION)
    if challenge is None:
        raise ValueError("Registration challenge expired or not found - request new options first.")

    credential = RegistrationCredential.parse_raw(credential_json)
    try:
        verified = webauthn.verify_registration_response(
            credential=credential,
            expected_challenge=challenge,
            expected_origin=settings.WEBAUTHN_ORIGIN,
            expected_rp_id=settings.WEBAUTHN_RP_ID,
        )
    except InvalidRegistrationResponse as exc:
        raise ValueError(str(exc)) from exc

    return WebAuthnCredential.objects.create(
        user=user,
        credential_id=bytes_to_base64url(verified.credential_id),
        public_key=bytes_to_base64url(verified.credential_public_key),
        sign_count=verified.sign_count,
        transports=credential.response.transports or [],
        device_name=device_name,
    )


def build_authentication_options(user: User):
    allow = [
        PublicKeyCredentialDescriptor(id=base64url_to_bytes(cred.credential_id))
        for cred in user.webauthn_credentials.all()
    ]
    options = webauthn.generate_authentication_options(
        rp_id=settings.WEBAUTHN_RP_ID,
        allow_credentials=allow,
        user_verification=UserVerificationRequirement.PREFERRED,
    )
    _store_challenge(user, WebAuthnChallenge.AUTHENTICATION, options.challenge)
    return webauthn.options_to_json(options)


def verify_authentication(user: User, credential_json: dict):
    challenge = _consume_challenge(user, WebAuthnChallenge.AUTHENTICATION)
    if challenge is None:
        raise ValueError("Authentication challenge expired or not found - request new options first.")

    credential = AuthenticationCredential.parse_raw(credential_json)
    stored = WebAuthnCredential.objects.filter(
        credential_id=bytes_to_base64url(base64url_to_bytes(credential.raw_id))
        if isinstance(credential.raw_id, str)
        else bytes_to_base64url(credential.raw_id),
        user=user,
    ).first()
    if stored is None:
        raise ValueError("Unknown credential for this user.")

    try:
        verified = webauthn.verify_authentication_response(
            credential=credential,
            expected_challenge=challenge,
            expected_rp_id=settings.WEBAUTHN_RP_ID,
            expected_origin=settings.WEBAUTHN_ORIGIN,
            credential_public_key=base64url_to_bytes(stored.public_key),
            credential_current_sign_count=stored.sign_count,
        )
    except InvalidAuthenticationResponse as exc:
        raise ValueError(str(exc)) from exc

    stored.sign_count = verified.new_sign_count
    stored.last_used_at = timezone.now()
    stored.save(update_fields=["sign_count", "last_used_at"])
    return stored
