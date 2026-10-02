from django.test import TestCase

# Create your tests here.


class InterestPeriodTests(TestCase):
    """A chama quotes 10% a month; a bank quotes 12% a year."""

    def test_a_monthly_rate_is_twelve_times_the_yearly_one(self):
        from decimal import Decimal

        from loans.services import annual_rate_from

        self.assertEqual(annual_rate_from(Decimal("0.10"), "PER_MONTH"), Decimal("1.20"))
        self.assertEqual(annual_rate_from(Decimal("0.12"), "PER_YEAR"), Decimal("0.12"))

    def test_flat_interest_follows_the_quoted_period(self):
        from datetime import date
        from decimal import Decimal

        from loans.services import annual_rate_from, generate_amortization_schedule

        # 10,000 at 10% a month, flat, over 3 months: 1,000 a month = 3,000.
        rows = generate_amortization_schedule(
            principal=Decimal("10000"), annual_rate=annual_rate_from(Decimal("0.10"), "PER_MONTH"),
            term_months=3, interest_method="FLAT", start_date=date(2026, 10, 1),
        )
        self.assertEqual(sum(r["interest_due"] for r in rows), Decimal("3000.00"))
        yearly = generate_amortization_schedule(
            principal=Decimal("10000"), annual_rate=annual_rate_from(Decimal("0.10"), "PER_YEAR"),
            term_months=3, interest_method="FLAT", start_date=date(2026, 10, 1),
        )
        self.assertEqual(sum(r["interest_due"] for r in yearly), Decimal("250.00"))
