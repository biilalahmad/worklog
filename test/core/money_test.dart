import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/core/utils/money.dart';

void main() {
  test('converts and formats standard two-decimal values consistently', () {
    const cases = <(double, String)>[
      (100, '\$100.00'),
      (0.50, '\$0.50'),
      (1999.99, '\$1,999.99'),
      (1000000, '\$1,000,000.00'),
    ];

    for (final (major, expected) in cases) {
      final minor = Money.toMinorUnits(major, 'USD');
      expect(Money(minor, 'USD').format(), expected);
    }
  });

  test('handles zero-decimal currencies without scaling by one hundred', () {
    final minor = Money.toMinorUnits(10000, 'JPY');

    expect(minor, 10000);
    expect(Money(minor, 'JPY').format(), '¥10,000');
  });
}
