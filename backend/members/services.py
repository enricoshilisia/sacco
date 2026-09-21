from datetime import date

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
        year = date.today().year
        if config.member_number_include_year and config.member_number_sequence_year != year:
            config.member_number_sequence_year = year
            config.member_number_next_sequence = 1  # new year, new run
        sequence = config.member_number_next_sequence
        config.member_number_next_sequence = sequence + 1
        config.save(update_fields=["member_number_next_sequence", "member_number_sequence_year"])

    return format_member_number(config, sequence, year)


def format_member_number(config, sequence: int, year: int) -> str:
    """e.g. M-00001, or with the year style IW-26-00123."""
    year_part = f"{year % 100:02d}{config.member_number_year_separator}" if config.member_number_include_year else ""
    return (
        f"{config.member_number_prefix}{year_part}"
        f"{sequence:0{config.member_number_padding}d}"
        f"{config.member_number_suffix}"
    )
