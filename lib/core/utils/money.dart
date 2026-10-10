import 'package:intl/intl.dart';

/// All money in this app is stored as an integer in the currency's minor
/// unit (e.g. paisa/cents) to avoid floating-point rounding bugs on
/// financial data — per the approved multi-currency design. Amounts are
/// never auto-converted between currencies; each transaction keeps its
/// own currency code (ISO 4217).
class Money {
  final int minorUnits;
  final String currency;

  const Money(this.minorUnits, this.currency);

  static const zero = Money(0, 'PKR');

  double get asDouble => minorUnits / _minorUnitScale(currency);

  Money operator +(Money other) {
    assert(currency == other.currency, 'Cannot add different currencies');
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    assert(currency == other.currency, 'Cannot subtract different currencies');
    return Money(minorUnits - other.minorUnits, currency);
  }

  String format() {
    final symbol = _symbolFor(currency);
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: _decimalDigitsFor(currency),
      locale: 'en_US',
    );
    return formatter.format(asDouble);
  }

  static String _symbolFor(String code) {
    switch (code) {
      case 'PKR':
        return 'Rs ';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'AED':
        return 'AED ';
      case 'AUD':
        return 'A\$';
      case 'CAD':
        return 'CA\$';
      case 'JPY':
        return '¥';
      case 'INR':
        return '₹';
      case 'SAR':
        return 'SAR ';
      case 'QAR':
        return 'QAR ';
      case 'SGD':
        return 'S\$';
      default:
        return '$code ';
    }
  }

  static int _decimalDigitsFor(String code) {
    switch (code) {
      case 'JPY':
        return 0;
      case 'BHD':
      case 'KWD':
      case 'OMR':
        return 3;
      default:
        return 2;
    }
  }

  static int _minorUnitScale(String code) {
    switch (_decimalDigitsFor(code)) {
      case 0:
        return 1;
      case 3:
        return 1000;
      default:
        return 100;
    }
  }

  static int toMinorUnits(double amount, [String currency = 'PKR']) =>
      (amount * _minorUnitScale(currency)).round();
}

/// A per-currency bucket of totals — e.g. a client can be owed PKR from
/// one project and USD from another; these must never be summed into one
/// number. Used for client/stats rollups.
class MoneyByCurrency {
  final Map<String, int> _minorUnitsByCurrency;

  const MoneyByCurrency(this._minorUnitsByCurrency);

  factory MoneyByCurrency.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const MoneyByCurrency({});
    return MoneyByCurrency(
      map.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  Map<String, int> toMap() => _minorUnitsByCurrency;

  List<Money> get entries => _minorUnitsByCurrency.entries
      .map((e) => Money(e.value, e.key))
      .where((m) => m.minorUnits != 0)
      .toList();

  bool get isEmpty => entries.isEmpty;

  String formatAll() {
    if (isEmpty) return '—';
    return entries.map((m) => m.format()).join(' + ');
  }
}

const supportedCurrencies = [
  'PKR', 'USD', 'EUR', 'GBP', 'AED', 'AUD', 'CAD', 'CHF', 'JPY', 'INR',
  'SAR', 'QAR', 'SGD', 'MYR', 'TRY', 'BRL', 'NGN', 'ZAR',
];
