import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacco_mobile/models/admin.dart';

void main() {
  test('verification progress parses money as Decimal', () {
    final v = Verification.fromJson({
      'verified': false,
      'registration_fee': '1000.00',
      'fee_paid': '600.00',
      'fee_outstanding': '400.00',
      'months_required': 3,
      'months_done': 2,
    });
    expect(v.feeOutstanding, Decimal.parse('400'));
    expect(v.feeDone, isFalse);
    expect(v.monthsDone, 2);
  });

  test('admin user initials and positions exclude automatic roles', () {
    final u = AdminUser.fromJson({
      'id': '1', 'name': 'Rose Nduta', 'phone_number': '+254711000112',
      'roles': ['Member', 'Chairperson'], 'login_enabled': true,
    });
    expect(u.initials, 'RN');
    expect(u.positions, ['Chairperson']);
  });

  test('position is full at its holder limit', () {
    final p = Position.fromJson({
      'id': 'r', 'name': 'Chairperson', 'max_holders': 1,
      'holders': [{'membership_id': 'm', 'user_id': 'u', 'name': 'Rose'}],
    });
    expect(p.isFull, isTrue);
  });
}
