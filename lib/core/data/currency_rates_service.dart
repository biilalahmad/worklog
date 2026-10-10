import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

typedef CurrencyRatesFetcher = Future<Map<String, dynamic>> Function();

class CurrencyRates {
  const CurrencyRates({
    required this.ratesPerUsd,
    required this.updatedAt,
    required this.nextUpdateAt,
  });

  final Map<String, double> ratesPerUsd;
  final DateTime updatedAt;
  final DateTime nextUpdateAt;

  double? convert(double amount, String from, String to) {
    final sourceRate = ratesPerUsd[from];
    final targetRate = ratesPerUsd[to];
    if (sourceRate == null || targetRate == null || sourceRate == 0) {
      return null;
    }
    return amount / sourceRate * targetRate;
  }

  Map<String, Object?> toJson() => {
        'rates': ratesPerUsd,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'nextUpdateAt': nextUpdateAt.millisecondsSinceEpoch,
      };

  factory CurrencyRates.fromJson(Map<String, dynamic> json) {
    final rawRates = json['rates'];
    if (rawRates is! Map) throw const FormatException('Invalid cached rates');
    final rates = <String, double>{};
    for (final entry in rawRates.entries) {
      final value = entry.value;
      if (entry.key is String && value is num && value > 0) {
        rates[entry.key as String] = value.toDouble();
      }
    }
    rates['USD'] = 1;
    final updatedAt =
        DateTime.fromMillisecondsSinceEpoch((json['updatedAt'] as num).toInt());
    final nextUpdateAt = DateTime.fromMillisecondsSinceEpoch(
        (json['nextUpdateAt'] as num).toInt());
    return CurrencyRates(
      ratesPerUsd: rates,
      updatedAt: updatedAt,
      nextUpdateAt: nextUpdateAt,
    );
  }
}

class CurrencyRatesService {
  CurrencyRatesService({required CurrencyRatesFetcher fetchRates})
      : _fetchRates = fetchRates;

  static const _cacheKey = 'worklog_currency_rates_usd_v1';
  final CurrencyRatesFetcher _fetchRates;

  Future<CurrencyRates?> getCachedRates() async {
    final preferences = await SharedPreferences.getInstance();
    final cachedJson = preferences.getString(_cacheKey);
    if (cachedJson == null) return null;
    try {
      return CurrencyRates.fromJson(
          jsonDecode(cachedJson) as Map<String, dynamic>);
    } catch (_) {
      await preferences.remove(_cacheKey);
      return null;
    }
  }

  Future<CurrencyRates?> refreshRates({
    CurrencyRates? fallback,
    void Function(Object error)? onError,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final body = await _fetchRates().timeout(const Duration(seconds: 8));
      if (body['result'] != 'success' || body['base_code'] != 'USD') {
        throw const FormatException('Invalid exchange-rate response');
      }
      final rawRates = body['rates'];
      if (rawRates is! Map) throw const FormatException('Missing rates');
      final rates = <String, double>{};
      for (final entry in rawRates.entries) {
        if (entry.key is String && entry.value is num && entry.value > 0) {
          rates[entry.key as String] = (entry.value as num).toDouble();
        }
      }
      rates['USD'] = 1;
      final now = DateTime.now();
      final nextUpdateSeconds = body['time_next_update_unix'];
      final nextUpdate = nextUpdateSeconds is num
          ? DateTime.fromMillisecondsSinceEpoch(
              nextUpdateSeconds.toInt() * 1000)
          : now.add(const Duration(days: 1));
      final result = CurrencyRates(
        ratesPerUsd: rates,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          ((body['time_last_update_unix'] as num?)?.toInt() ??
                  now.millisecondsSinceEpoch ~/ 1000) *
              1000,
        ),
        nextUpdateAt: nextUpdate,
      );
      await preferences.setString(_cacheKey, jsonEncode(result.toJson()));
      return result;
    } catch (error) {
      // Existing cached rates remain useful offline, even after their daily
      // refresh window has passed. Never block screens on an FX provider.
      onError?.call(error);
      return fallback ?? await getCachedRates();
    }
  }

  Future<CurrencyRates?> getRates() async {
    final cached = await getCachedRates();
    if (cached != null && DateTime.now().isBefore(cached.nextUpdateAt)) {
      return cached;
    }
    return refreshRates(fallback: cached);
  }
}
