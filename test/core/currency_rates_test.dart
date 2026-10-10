import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worklog/core/data/currency_rates_service.dart';

void main() {
  test('converts between currencies without changing the source values', () {
    final rates = CurrencyRates(
      ratesPerUsd: const {'USD': 1, 'PKR': 280, 'EUR': 0.92},
      updatedAt: DateTime.utc(2026, 10, 8),
      nextUpdateAt: DateTime.utc(2026, 10, 9),
    );

    expect(rates.convert(100, 'USD', 'PKR'), 28000);
    expect(rates.convert(28000, 'PKR', 'USD'), 100);
    expect(rates.convert(10, 'USD', 'EUR'), closeTo(9.2, 0.000001));
    expect(rates.convert(10, 'XYZ', 'USD'), isNull);
  });

  test('fetches the daily USD rates and retains their refresh window',
      () async {
    SharedPreferences.setMockInitialValues({});
    final result = await CurrencyRatesService(fetchRates: () async {
      return {
        'result': 'success',
        'base_code': 'USD',
        'time_last_update_unix': 1791417600,
        'time_next_update_unix': 1791504000,
        'rates': {'USD': 1, 'PKR': 280, 'EUR': 0.92},
      };
    }).getRates();

    expect(result?.ratesPerUsd['PKR'], 280);
    expect(result?.convert(1, 'USD', 'EUR'), 0.92);
    expect(result?.nextUpdateAt,
        DateTime.fromMillisecondsSinceEpoch(1791504000 * 1000));
  });

  test('uses no network data when offline and no cached rates exist', () async {
    SharedPreferences.setMockInitialValues({});
    final service = CurrencyRatesService(
        fetchRates: () async => throw StateError('offline'));
    expect(await service.getRates(), isNull);
  });

  test('returns cached rates immediately without waiting for the network',
      () async {
    final stale = CurrencyRates(
      ratesPerUsd: const {'USD': 1, 'PKR': 280},
      updatedAt: DateTime.utc(2026, 10, 8),
      nextUpdateAt: DateTime.utc(2026, 10, 9),
    );
    SharedPreferences.setMockInitialValues({
      'worklog_currency_rates_usd_v1': jsonEncode(stale.toJson()),
    });
    var requests = 0;
    final service = CurrencyRatesService(fetchRates: () async {
      requests++;
      throw StateError('network unavailable');
    });

    final cached = await service.getCachedRates();
    expect(cached?.ratesPerUsd['PKR'], 280);
    expect(requests, 0);
  });
}
