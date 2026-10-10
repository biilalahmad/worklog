import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/currency_rates_service.dart';
import '../errors/failure.dart';
import '../utils/money.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';

final currencyRatesIssueProvider = StateProvider<String?>((ref) => null);

final currencyRatesProvider = FutureProvider<CurrencyRates?>((ref) async {
  final supabase = Supabase.instance.client;
  final ratesService = CurrencyRatesService(fetchRates: () async {
    final response = await supabase.functions.invoke('exchange-rates');
    if (response.status != 200 || response.data is! Map) {
      throw StateError('Rates unavailable');
    }
    return (response.data as Map).cast<String, dynamic>();
  });
  var disposed = false;
  ref.onDispose(() => disposed = true);
  void recordIssue(Object error) {
    if (!disposed) {
      ref.read(currencyRatesIssueProvider.notifier).state =
          Failure.from(error).message;
    }
  }

  Future<CurrencyRates?> refresh({CurrencyRates? fallback}) async {
    final result = await ratesService.refreshRates(
      fallback: fallback,
      onError: recordIssue,
    );
    if (result != null && !disposed) {
      ref.read(currencyRatesIssueProvider.notifier).state = null;
    }
    return result;
  }

  final cached = await ratesService.getCachedRates();
  final CurrencyRates? rates;
  if (cached != null) {
    rates = cached;
    if (DateTime.now().isAfter(cached.nextUpdateAt)) {
      unawaited(refresh(fallback: cached).then((fresh) {
        if (!disposed && fresh != null && fresh.updatedAt != cached.updatedAt) {
          ref.invalidateSelf();
        }
      }));
    }
  } else {
    rates = await refresh();
  }
  if (rates != null) {
    final refreshIn = rates.nextUpdateAt.difference(DateTime.now());
    if (refreshIn > Duration.zero) {
      final timer = Timer(refreshIn, ref.invalidateSelf);
      ref.onDispose(timer.cancel);
    }
  }
  return rates;
});

/// Displays an amount in the user's selected display currency when rates are
/// available, while leaving the persisted transaction currency untouched.
class MoneyDisplay extends ConsumerWidget {
  const MoneyDisplay(
    this.money, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final Money money;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider).valueOrNull;
    final converted = rates?.convert(money.asDouble, money.currency, target);
    final display = converted == null
        ? money.format()
        : Money(Money.toMinorUnits(converted, target), target).format();
    return _AnimatedMoneyText(
      display,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class MoneyTotalsDisplay extends ConsumerWidget {
  const MoneyTotalsDisplay(
    this.amounts, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final MoneyByCurrency amounts;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(defaultCurrencyProvider);
    final rates = ref.watch(currencyRatesProvider).valueOrNull;
    final entries = amounts.entries;
    String display;
    if (entries.isEmpty) {
      display = '—';
    } else if (entries.every((entry) => entry.currency == target)) {
      display = amounts.toMap().containsKey(target)
          ? Money(amounts.toMap()[target]!, target).format()
          : '—';
    } else if (rates != null) {
      final converted = <double>[];
      for (final entry in entries) {
        final value = rates.convert(entry.asDouble, entry.currency, target);
        if (value == null) {
          converted.clear();
          break;
        }
        converted.add(value);
      }
      display = converted.length == entries.length
          ? Money(
                  Money.toMinorUnits(
                      converted.fold<double>(0, (sum, value) => sum + value),
                      target),
                  target)
              .format()
          : amounts.formatAll();
    } else {
      display = amounts.formatAll();
    }
    return _AnimatedMoneyText(
      display,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class _AnimatedMoneyText extends StatelessWidget {
  const _AnimatedMoneyText(
    this.value, {
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Text(
          value,
          key: ValueKey(value),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        ),
      );
}
