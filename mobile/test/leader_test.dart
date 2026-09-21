import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacco_mobile/core/money.dart';
import 'package:sacco_mobile/models/leader.dart';
import 'package:sacco_mobile/models/models.dart';

TenantProfile profile(List<String> permissions) => TenantProfile.fromJson({'permissions': permissions});

void main() {
  group('leader modules follow permissions', () {
    test('treasurer gets finance, reports, loan desk (disburse), members, distributions', () {
      final p = profile([
        'accounting.view_trial_balance', 'accounting.view_ledger', 'loans.view', 'loans.disburse',
        'members.view', 'distributions.view', 'welfare.view',
      ]);
      expect(p.hasFinance, isTrue);
      expect(p.hasReports, isTrue);
      expect(p.hasLoanDesk, isTrue);
      expect(p.hasMembers, isTrue);
      expect(p.hasDistributions, isTrue);
      expect(p.hasStaffTools, isTrue);
    });

    test('credit committee gets the loan desk but no finance', () {
      final p = profile(['loans.view', 'loans.approve', 'loans.reject', 'reports.view']);
      expect(p.hasLoanDesk, isTrue);
      expect(p.hasFinance, isFalse);
    });

    test('an ordinary member has no leader tools', () {
      final p = profile(['loans.apply', 'members.edit_own', 'payments.initiate_own_collection', 'governance.vote']);
      expect(p.hasStaffTools, isFalse);
    });
  });

  test('dividend rate typed as a percent becomes the exact fraction the API stores', () {
    expect(Money.percentToFraction(Decimal.parse('10')), Decimal.parse('0.1'));
    expect(Money.percentToFraction(Decimal.parse('7.5')), Decimal.parse('0.075'));
  });

  test('report JSON parses into the generic viewer shape', () {
    final r = Report.fromJson({
      'key': 'trial_balance',
      'title': 'Trial balance',
      'period': 'As at 2026-09-21',
      'summary': [],
      'sections': [
        {
          'title': 'Accounts',
          'columns': [
            {'key': 'code', 'label': 'Code', 'kind': 'text'},
            {'key': 'debit', 'label': 'Debit', 'kind': 'money'},
          ],
          'rows': [
            ['1000', '500.00'],
          ],
          'totals': ['Total', '500.00'],
        },
      ],
      'checks': [
        {'label': 'Debits equal credits', 'ok': true, 'detail': '500.00 / 500.00'},
      ],
    });
    expect(r.sections.single.columns[1].isNumeric, isTrue);
    expect(r.sections.single.rows.single, ['1000', '500.00']);
    expect(r.checks.single.ok, isTrue);
  });
}
