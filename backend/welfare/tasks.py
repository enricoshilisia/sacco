import logging

from celery import shared_task
from django_tenants.utils import schema_context

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=5, default_retry_delay=30)
def levy_welfare_case_task(self, case_id: str, tenant_schema: str):
    """Levies every active member for an approved welfare case. Safe to
    retry: members already levied are skipped (see services.levy_members)."""
    with schema_context(tenant_schema):
        from .models import WelfareCase
        from .services import levy_members

        case = WelfareCase.objects.get(id=case_id)
        try:
            count = levy_members(case)
        except Exception as exc:
            logger.exception("Welfare levy failed for case %s", case_id)
            raise self.retry(exc=exc)
        logger.info("Welfare levy for case %s: %s members levied", case_id, count)


@shared_task(bind=True, max_retries=5, default_retry_delay=30)
def close_welfare_year_task(self, year_close_id: int, tenant_schema: str):
    """Moves unused yearly welfare balances into the Welfare Fund. Safe to
    retry: members already swept for the year are skipped."""
    with schema_context(tenant_schema):
        from .models import WelfareYearClose
        from .services import run_year_close

        year_close = WelfareYearClose.objects.get(id=year_close_id)
        try:
            count = run_year_close(year_close)
        except Exception as exc:
            logger.exception("Welfare year close failed for %s", year_close.year)
            raise self.retry(exc=exc)
        logger.info("Welfare year close %s: %s members swept", year_close.year, count)
