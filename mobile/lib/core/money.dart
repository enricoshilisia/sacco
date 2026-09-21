import 'package:decimal/decimal.dart';

/// Money is Decimal, never double (CLAUDE.md rule 1). The API sends
/// amounts as strings ("1500.00"); they are parsed straight into Decimal
/// and formatted from Decimal, never passing through a floating-point
/// value on the way.
class Money {
  static final zero = Decimal.zero;

  static Decimal parse(Object? value) {
    if (value == null) return Decimal.zero;
    if (value is String) return Decimal.tryParse(value.trim()) ?? Decimal.zero;
    // Defensive only: every money field is expected to arrive as a string.
    // An int is exact; anything else is converted from its shortest
    // round-trip text, which is the best available once it's a number.
    return Decimal.tryParse(value.toString()) ?? Decimal.zero;
  }

  static Decimal sum(Iterable<Decimal> values) => values.fold(Decimal.zero, (a, b) => a + b);

  /// "12,345.50" - grouping done on the decimal string itself.
  static String format(Decimal amount) {
    final negative = amount < Decimal.zero;
    final fixed = (negative ? -amount : amount).toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    return '${negative ? '-' : ''}$buffer.${parts[1]}';
  }

  /// An annual rate stored as a fraction (0.1200) shown as "12" - exact,
  /// with trailing zeros trimmed.
  static String percent(Decimal fraction) {
    final text = (fraction * Decimal.fromInt(100)).toString();
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }

  /// "10" (typed percent) -> 0.1 (the fraction the API stores), exactly.
  static Decimal percentToFraction(Decimal percent) =>
      (percent / Decimal.fromInt(100)).toDecimal(scaleOnInfinitePrecision: 6);

  static String withCurrency(Decimal amount, String currency) => '$currency ${format(amount)}';

  /// Validates user-typed amounts without parsing through double: positive,
  /// at most 2 decimal places, matching the API's DecimalField(decimal_places=2).
  static Decimal? parseUserInput(String text) {
    final cleaned = text.replaceAll(',', '').trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(cleaned)) return null;
    final value = Decimal.parse(cleaned);
    return value > Decimal.zero ? value : null;
  }
}
