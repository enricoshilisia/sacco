import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacco_mobile/models/fines.dart';
import 'package:sacco_mobile/models/models.dart';
import 'package:sacco_mobile/screens/home_shell.dart';

void main() {
  test('a member fines payload parses money as Decimal', () {
    final f = MemberFines.fromJson({
      'member': 'm1', 'member_name': 'Diana Indasi', 'member_number': 'IW-26-00054',
      'charged': '1000.00', 'paid': '0', 'outstanding': '1000.00', 'count_outstanding': 1,
      'fines': [
        {'id': 'f1', 'offence': 'Absent without apology', 'amount': '1000.00', 'paid': '0',
         'outstanding': '1000.00', 'status': 'OUTSTANDING', 'status_label': 'Owed', 'incurred_on': '2026-09-13'},
      ],
    });
    expect(f.outstanding, Decimal.parse('1000'));
    expect(f.fines.single.isOutstanding, isTrue);
  });

  test('waived fines are not counted as owed', () {
    final fine = FineItem.fromJson({
      'id': 'f2', 'amount': '200.00', 'paid': '0', 'outstanding': '0', 'status': 'WAIVED',
      'status_label': 'Waived', 'waived_by_name': 'Faith Mary Koko', 'waived_reason': 'Bereaved',
    });
    expect(fine.isWaived, isTrue);
    expect(fine.outstanding, Decimal.zero);
  });

  test('the fines register is a tab for whoever may see it', () {
    final treasurer = TenantProfile.fromJson({
      'permissions': ['fines.view', 'fines.record_payment', 'members.view'],
    });
    expect(treasurer.hasFines, isTrue);
    expect(buildMenu(isMember: false, profile: treasurer).bar, contains(AppTab.fines));
    final member = TenantProfile.fromJson({'permissions': ['loans.apply']});
    expect(member.hasFines, isFalse);
  });
}
