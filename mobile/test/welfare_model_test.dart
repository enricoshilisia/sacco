import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacco_mobile/models/models.dart';
import 'package:sacco_mobile/models/welfare.dart';

void main() {
  test('welfare summary parses money exactly and works out what is left for the year', () {
    final s = WelfareSummary.fromJson({
      'balance': '350.00',
      'owed': '50.00',
      'yearly_contribution': '1000.00',
      'paid_this_year': '650.00',
      'year': 2026,
    });
    expect(s.balance, Decimal.parse('350'));
    expect(s.owed, Decimal.parse('50'));
    expect(s.yearlyRemaining, Decimal.parse('350'));
  });

  test('yearly remaining never goes negative when a member overpays', () {
    final s = WelfareSummary.fromJson({'yearly_contribution': '1000.00', 'paid_this_year': '1500.00'});
    expect(s.yearlyRemaining, Decimal.zero);
  });

  test('welfare case totals come through as Decimal', () {
    final c = WelfareCase.fromJson({
      'id': 'c1',
      'status': 'APPROVED',
      'case_type_name': 'Member sick',
      'beneficiary': {'id': 'm1', 'member_number': 'M-00001', 'full_name': 'Jane'},
      'contribution_per_member': '200.00',
      'members_levied': 3,
      'total_levied': '600.00',
      'collected': '350.00',
      'outstanding': '250.00',
      'paid_out': '200.00',
      'available_to_pay': '150.00',
      'payouts': [],
    });
    expect(c.isOpen, isTrue);
    expect(c.availableToPay, Decimal.parse('150'));
    expect(c.collected + c.outstanding, c.totalLevied);
  });

  test('staff tools are detected from welfare permissions', () {
    final staff = TenantProfile.fromJson({'permissions': ['welfare.view', 'welfare.create_case']});
    final member = TenantProfile.fromJson({'permissions': ['loans.apply']});
    expect(staff.hasStaffTools, isTrue);
    expect(member.hasStaffTools, isFalse);
  });
}
