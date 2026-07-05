import logging

from celery import shared_task
from django_tenants.utils import schema_context

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=3, default_retry_delay=30)
def run_distribution_payouts_task(self, run_id: str, tenant_schema: str, created_by_id: str | None):
    """
    Bulk payout fan-out for one approved DistributionRun - the "dividend
    runs" case CLAUDE.md rule 7 calls out explicitly ("money math runs in
    Celery, is retryable, and is logged"). Deliberately NOT wrapped in one
    atomic block across members, unlike approve_distribution_run: one
    member's payout failing (bad phone number, provider decline) must not
    block or stop everyone else's - same per-item independence as
    payments/tasks.py:reconcile_pending_collections. Each entry's own
    initiate_distribution_payout call is still individually idempotent.
    """
    with schema_context(tenant_schema):
        from identity.models import User

        from .models import DistributionEntryStatus, DistributionRun
        from .services import initiate_distribution_payout

        run = DistributionRun.objects.get(id=run_id)
        created_by = User.objects.filter(id=created_by_id).first() if created_by_id else None
        pending_entries = run.entries.filter(status=DistributionEntryStatus.POSTED)
        for entry in pending_entries:
            try:
                initiate_distribution_payout(
                    entry=entry, phone_number=entry.member.phone_number, created_by=created_by,
                )
            except Exception:
                # Logged, not raised - one member's failure must not stop
                # the batch for everyone else.
                logger.exception("Distribution payout failed for entry %s (run %s)", entry.id, run_id)
                continue
