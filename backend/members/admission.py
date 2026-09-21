"""
Admitting new members, and when they become fully verified.

1. The Secretary registers an applicant (MemberApplication).
2. A second person - the Chairperson - approves. Nobody approves an
   application they submitted. Approval creates the Member (with a member
   number), their login with a temporary password, and posts any
   registration fee collected at registration.
3. The member is on probation until verified: registration fee paid plus
   N consecutive months (default 3) of mandatory monthly contributions.
   Verification is checked whenever they contribute or pay the fee, and is
   permanent once reached. Until then: no borrowing, guaranteeing, welfare
   cover, voting or holding office (require_verified).
"""

import secrets
from datetime import date
from decimal import Decimal

from django.db import connection, transaction
from django.db.models import Sum
from django.utils import timezone

from accounting.models import Account
from accounting.services import LineInput, post_journal_entry
from notifications.services import queue_sms

from .activity import contributed_months
from .models import (
    ApplicationStatus,
    Member,
    MemberApplication,
    MembershipSettings,
    MemberStatus,
    ProfileStatus,
    RegistrationFeePayment,
)
from .services import generate_member_number

CASH_ACCOUNT_CODE = "1000"
REGISTRATION_FEE_INCOME_CODE = "5100"
ZERO = Decimal("0")

# Readable on a phone and easy to type: no 0/O, 1/l/I.
_TEMP_ALPHABET = "abcdefghjkmnpqrstuvwxyz23456789"


def generate_temporary_password() -> str:
    """Three groups of four, e.g. k7mp-3xq9-ta4f (~60 bits)."""
    groups = ["".join(secrets.choice(_TEMP_ALPHABET) for _ in range(4)) for _ in range(3)]
    return "-".join(groups)


# --- Applications -------------------------------------------------------------


def _assert_not_duplicate(*, id_type, id_number, phone_number, exclude_application=None):
    if Member.objects.filter(id_type=id_type, id_number=id_number).exists():
        raise ValueError("A member with this ID number is already registered.")
    if Member.objects.filter(phone_number=phone_number).exclude(status=MemberStatus.EXITED).exists():
        raise ValueError("A member with this phone number is already registered.")
    pending = MemberApplication.objects.filter(status=ApplicationStatus.PENDING, id_type=id_type, id_number=id_number)
    if exclude_application is not None:
        pending = pending.exclude(pk=exclude_application.pk)
    if pending.exists():
        raise ValueError("An application with this ID number is already waiting for approval.")


def submit_application(*, data: dict, submitted_by) -> MemberApplication:
    _assert_not_duplicate(id_type=data["id_type"], id_number=data["id_number"], phone_number=data["phone_number"])
    fee = data.get("fee_collected") or ZERO
    if fee < 0:
        raise ValueError("The fee collected can't be negative.")
    if fee > 0 and not data.get("fee_method"):
        raise ValueError("Say how the registration fee was paid (cash, bank or mobile money).")
    return MemberApplication.objects.create(**data, submitted_by=submitted_by)


def cancel_application(application: MemberApplication, *, by) -> MemberApplication:
    with transaction.atomic():
        application = MemberApplication.objects.select_for_update().get(pk=application.pk)
        if application.status != ApplicationStatus.PENDING:
            raise ValueError("Only an application waiting for approval can be cancelled.")
        application.status = ApplicationStatus.CANCELLED
        application.decided_by = by
        application.decided_at = timezone.now()
        application.save(update_fields=["status", "decided_by", "decided_at"])
        return application


def reject_application(application: MemberApplication, *, by, reason: str) -> MemberApplication:
    if not reason.strip():
        raise ValueError("Give a reason for rejecting the application.")
    with transaction.atomic():
        application = MemberApplication.objects.select_for_update().get(pk=application.pk)
        if application.status != ApplicationStatus.PENDING:
            raise ValueError("This application has already been decided.")
        if application.submitted_by_id == by.pk:
            raise ValueError("You registered this applicant, so someone else must decide.")
        application.status = ApplicationStatus.REJECTED
        application.decided_by = by
        application.decided_at = timezone.now()
        application.decision_notes = reason.strip()
        application.save(update_fields=["status", "decided_by", "decided_at", "decision_notes"])
        return application


def _grant_login(member: Member) -> str | None:
    """Links (or creates) the member's login. Returns the temporary password
    when a new login was created; None when they already had one (e.g. a
    staff member joining as a member keeps their own password)."""
    from accesscontrol.models import Membership, Role
    from identity.models import TenantAccess, User
    from tenants.models import Tenant

    user = User.objects.filter(phone_number=member.phone_number).first()
    temporary = None
    if user is None:
        temporary = generate_temporary_password()
        user = User.objects.create_user(
            phone_number=member.phone_number,
            email=member.email or None,
            password=temporary,
            first_name=member.first_name,
            last_name=member.last_name,
            must_change_password=True,
        )
    tenant = Tenant.objects.get(schema_name=connection.schema_name)
    access, _ = TenantAccess.objects.get_or_create(user=user, tenant=tenant)
    if not access.is_active:
        access.is_active = True
        access.save(update_fields=["is_active"])
    Membership.objects.get_or_create(user=user, role=Role.objects.get(name="Member"))
    member.user = user
    member.save(update_fields=["user"])
    return temporary


def approve_application(application: MemberApplication, *, by, notes: str = "") -> tuple[MemberApplication, str | None]:
    """Returns (application, temporary_password). The temporary password is
    shown once to the approver to hand to the new member; it is never
    stored in plain text."""
    with transaction.atomic():
        application = MemberApplication.objects.select_for_update().get(pk=application.pk)
        if application.status != ApplicationStatus.PENDING:
            raise ValueError("This application has already been decided.")
        if application.submitted_by_id == by.pk:
            raise ValueError("You registered this applicant, so someone else must approve.")
        _assert_not_duplicate(
            id_type=application.id_type, id_number=application.id_number,
            phone_number=application.phone_number, exclude_application=application,
        )
        member = Member.objects.create(
            member_number=generate_member_number(),
            first_name=application.first_name,
            last_name=application.last_name,
            other_names=application.other_names,
            date_of_birth=application.date_of_birth,
            gender=application.gender,
            id_type=application.id_type,
            id_number=application.id_number,
            phone_number=application.phone_number,
            email=application.email,
            physical_address=application.physical_address,
            marital_status=application.marital_status,
            occupation=application.occupation,
            employer=application.employer,
            county=application.county,
            # Entered by the Secretary and checked by the approver.
            profile_status=ProfileStatus.APPROVED,
            verified_at=None,  # on probation until fee + monthly contributions
        )
        temporary = _grant_login(member)
        application.status = ApplicationStatus.APPROVED
        application.decided_by = by
        application.decided_at = timezone.now()
        application.decision_notes = notes
        application.member = member
        application.save(update_fields=["status", "decided_by", "decided_at", "decision_notes", "member"])

        if application.fee_collected > 0:
            record_registration_fee(
                member=member,
                amount=application.fee_collected,
                method=application.fee_method,
                reference=application.fee_reference,
                paid_on=application.submitted_at.date(),
                idempotency_key=f"application-{application.pk}",
                recorded_by=application.submitted_by,
            )

        from tenants.models import Tenant

        sacco = Tenant.objects.get(schema_name=connection.schema_name).name
        transaction.on_commit(lambda: queue_sms(
            member=member,
            event_type="member_admitted",
            recipient=member.phone_number,
            message=(
                f"Welcome to {sacco}! Your membership is approved. Member no. {member.member_number}. "
                f"Log in to the Inuka West app with your phone number."
            ),
        ))
        return application, temporary


# --- Registration fee & verification -----------------------------------------


def fee_paid(member: Member) -> Decimal:
    return member.registration_fees.aggregate(total=Sum("amount"))["total"] or ZERO


def record_registration_fee(
    *, member: Member, amount: Decimal, method: str, paid_on: date, idempotency_key: str,
    reference: str = "", recorded_by=None,
) -> RegistrationFeePayment:
    """Posts a registration fee: Dr Cash and Bank / Cr Registration Fee
    Income. Idempotent on idempotency_key (a retry returns the first one)."""
    if amount <= 0:
        raise ValueError("Fee amount must be positive.")
    existing = RegistrationFeePayment.objects.filter(idempotency_key=idempotency_key).first()
    if existing is not None:
        return existing
    with transaction.atomic():
        member = Member.objects.select_for_update().get(pk=member.pk)
        required = MembershipSettings.get_solo().registration_fee
        if required > 0 and fee_paid(member) + amount > required:
            raise ValueError(f"The registration fee is {required}; only {required - fee_paid(member)} is outstanding.")
        entry = post_journal_entry(
            description=f"Registration fee - {member.member_number}",
            entry_date=paid_on,
            lines=[
                LineInput(account=Account.objects.get(code=CASH_ACCOUNT_CODE), debit=amount, member=member,
                          description=f"Registration fee {reference}".strip()),
                LineInput(account=Account.objects.get(code=REGISTRATION_FEE_INCOME_CODE), credit=amount,
                          description="Registration fee income"),
            ],
            created_by=recorded_by,
        )
        payment = RegistrationFeePayment.objects.create(
            member=member, amount=amount, method=method, reference=reference, paid_on=paid_on,
            idempotency_key=idempotency_key, journal_entry=entry, recorded_by=recorded_by,
        )
    check_verification(member)
    return payment


def longest_contribution_run(member: Member) -> int:
    months = sorted(contributed_months(member))
    best = run = 0
    previous = None
    for year, month in months:
        index = year * 12 + month
        run = run + 1 if previous is not None and index == previous + 1 else 1
        best = max(best, run)
        previous = index
    return best


def verification_status(member: Member) -> dict:
    settings = MembershipSettings.get_solo()
    paid = fee_paid(member)
    return {
        "verified": member.is_verified,
        "verified_at": member.verified_at,
        "registration_fee": settings.registration_fee,
        "fee_paid": paid,
        "fee_outstanding": max(settings.registration_fee - paid, ZERO),
        "months_required": settings.verification_months,
        "months_done": min(longest_contribution_run(member), settings.verification_months),
    }


def check_verification(member: Member) -> bool:
    """Verifies the member once both conditions are met. Permanent."""
    member = Member.objects.get(pk=member.pk)
    if member.is_verified:
        return True
    status = verification_status(member)
    if status["fee_outstanding"] > 0 or status["months_done"] < status["months_required"]:
        return False
    member.verified_at = timezone.now()
    member.save(update_fields=["verified_at"])
    transaction.on_commit(lambda: queue_sms(
        member=member,
        event_type="member_verified",
        recipient=member.phone_number,
        message=f"Congratulations {member.first_name}, your membership ({member.member_number}) is now fully verified.",
    ))
    return True


def require_verified(member: Member, what: str) -> None:
    """what: e.g. 'borrow', 'guarantee loans'."""
    if not member.is_verified:
        raise ValueError(
            f"{member.full_name} is still a new member on probation, so can't {what} yet. "
            f"Membership is verified after the registration fee and "
            f"{MembershipSettings.get_solo().verification_months} consecutive monthly contributions."
        )
