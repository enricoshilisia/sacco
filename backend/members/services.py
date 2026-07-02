from django.db import transaction

from configuration.models import TenantConfig


def generate_member_number() -> str:
    """
    Atomically claim the next member number in this tenant's configured
    style (see configuration.TenantConfig.member_number_*). Locks the
    config row for the duration of the transaction so two concurrent member
    creations can never be handed the same number.
    """
    with transaction.atomic():
        config = TenantConfig.objects.select_for_update().first()
        if config is None:
            config = TenantConfig.objects.create()
        sequence = config.member_number_next_sequence
        config.member_number_next_sequence = sequence + 1
        config.save(update_fields=["member_number_next_sequence"])

    return f"{config.member_number_prefix}{sequence:0{config.member_number_padding}d}"
