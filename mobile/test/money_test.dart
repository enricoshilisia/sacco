import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacco_mobile/core/money.dart';

void main() {
  group('Money.parse', () {
    test('parses API decimal strings exactly', () {
      expect(Money.parse('1500.00'), Decimal.parse('1500'));
      expect(Money.parse('0.10') + Money.parse('0.20'), Decimal.parse('0.30'));
    });

    test('treats null and garbage as zero', () {
      expect(Money.parse(null), Decimal.zero);
      expect(Money.parse('abc'), Decimal.zero);
    });

    test('sum of many small amounts has no float drift', () {
      final total = Money.sum(List.filled(1000, Money.parse('0.10')));
      expect(total, Decimal.parse('100'));
    });
  });

  group('Money.format', () {
    test('groups thousands and pads to 2dp', () {
      expect(Money.format(Decimal.parse('1234567.5')), '1,234,567.50');
      expect(Money.format(Decimal.parse('999')), '999.00');
      expect(Money.format(Decimal.parse('1000')), '1,000.00');
      expect(Money.format(Decimal.zero), '0.00');
    });

    test('handles negatives', () {
      expect(Money.format(Decimal.parse('-2500.75')), '-2,500.75');
    });

    test('large balances stay exact', () {
      expect(Money.format(Decimal.parse('98765432109876.54')), '98,765,432,109,876.54');
    });
  });

  group('Money.parseUserInput', () {
    test('accepts positive amounts with up to 2dp', () {
      expect(Money.parseUserInput('100'), Decimal.parse('100'));
      expect(Money.parseUserInput('1,000.5'), Decimal.parse('1000.5'));
      expect(Money.parseUserInput(' 25.75 '), Decimal.parse('25.75'));
    });

    test('rejects zero, negatives, too many decimals and junk', () {
      for (final bad in ['0', '0.00', '-5', '1.234', '', 'abc', '1e3', '.5']) {
        expect(Money.parseUserInput(bad), isNull, reason: bad);
      }
    });
  });

  group('Money.percent', () {
    test('shows a stored fraction as a trimmed percentage', () {
      expect(Money.percent(Decimal.parse('0.1200')), '12');
      expect(Money.percent(Decimal.parse('0.0125')), '1.25');
      expect(Money.percent(Decimal.parse('0.1')), '10');
    });
  });
}
