import 'package:flutter_test/flutter_test.dart';
import 'package:sacco_mobile/models/models.dart';
import 'package:sacco_mobile/screens/home_shell.dart';
import 'package:sacco_mobile/screens/profile/id_scan.dart';

void main() {
  group('reading the ID number from a scanned card', () {
    const kenyanCard = '''
REPUBLIC OF KENYA
SERIAL NUMBER: 238471923
ID NUMBER: 12345678
FULL NAMES MARY WANJIRU KAMAU
DATE OF BIRTH 12.03.1990
''';

    test('finds the Kenyan ID number that matches the record', () {
      expect(extractIdNumber(kenyanCard, expected: '12345678'), '12345678');
    });

    test('prefers the 8-digit ID over the 9-digit serial when nothing is typed', () {
      expect(extractIdNumber(kenyanCard), '12345678');
    });

    test('accepts a number printed with spaces when it matches the record', () {
      expect(extractIdNumber('ID No. 12 345 678', expected: '12345678'), '12345678');
    });

    test('reads a Tanzanian NIDA number with dashes', () {
      const nida = 'JAMHURI YA MUUNGANO WA TANZANIA\nNIN 19900312-12345-00001-27\nJINA: JUMA';
      expect(extractIdNumber(nida), '19900312123450000127');
    });

    test('returns nothing when there is no number', () {
      expect(extractIdNumber('blurry photo, no digits'), isNull);
    });
  });

  test('the Secretary gets Approvals in the bottom menu', () {
    final secretary = TenantProfile.fromJson({
      'permissions': ['members.view', 'members.kyc_verify', 'members.approve_changes', 'welfare.view'],
    });
    final menu = buildMenu(isMember: true, profile: secretary);
    expect(menu.bar[1], AppTab.approvals);
  });
}
