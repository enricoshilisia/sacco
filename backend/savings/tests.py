from decimal import Decimal

from django_tenants.test.cases import TenantTestCase

from accounting.models import Account
from members.models import Member

from .models import SavingsProduct
from .services import contribute_shares, deposit_savings, get_or_open_savings_account, withdraw_savings


class ContributionsAsSharesTests(TenantTestCase):
    """A group whose monthly contribution is ownership money, never withdrawn."""

    @classmethod
    def setup_tenant(cls, tenant):
        tenant.name = "Test SACCO"
        tenant.country = "KE"
        tenant.currency = "KES"

    def setUp(self):
        super().setUp()
        from configuration.models import TenantConfig

        self.config = TenantConfig.get_solo()
        self.config.monthly_contribution_target = TenantConfig.MONTHLY_TO_SHARES
        self.config.loan_security_base = "SHARES"
        self.config.withdrawals_enabled = False
        self.config.save()
        self.member = Member.objects.create(
            member_number="IW-26-00001", first_name="Odilia", last_name="K",
            id_type="NATIONAL_ID", id_number="1", phone_number="",
        )

    def test_a_contribution_to_shares_counts_for_its_month(self):
        from datetime import date

        from members.activity import contributed_months

        contribute_shares(member=self.member, amount=Decimal("500"), transaction_date=date(2026, 9, 27),
                          for_month=date(2026, 10, 1))
        self.assertEqual(contributed_months(self.member), {(2026, 10)})
        self.assertEqual(Account.objects.get(code="3000").balance(member=self.member), Decimal("500"))

    def test_loans_are_secured_against_share_capital(self):
        from datetime import date

        from loans.services import get_available_deposits

        contribute_shares(member=self.member, amount=Decimal("3500"), transaction_date=date(2026, 9, 1))
        self.assertEqual(get_available_deposits(self.member), Decimal("3500"))

    def test_no_withdrawals_while_they_are_switched_off(self):
        from datetime import date

        product = SavingsProduct.objects.create(name="Monthly", code="m2", product_type="MANDATORY_MONTHLY")
        account = get_or_open_savings_account(self.member, product)
        deposit_savings(savings_account=account, amount=Decimal("1000"), transaction_date=date(2026, 9, 1))
        with self.assertRaisesMessage(ValueError, "switched off"):
            withdraw_savings(savings_account=account, amount=Decimal("100"), transaction_date=date(2026, 9, 2))
