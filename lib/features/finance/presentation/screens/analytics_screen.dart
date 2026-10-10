import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/data/currency_rates_service.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/money_display.dart';
import '../../../home/domain/stats.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Income and expense reporting across Day / Week / Month buckets.
/// (see get_stats_for_range in supabase/schema.sql), so this screen
/// never downloads raw rows to sum on the client.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  StatsGranularity _granularity = StatsGranularity.week;

  @override
  Widget build(BuildContext context) {
    final rangesAsync = ref.watch(rangeStatsProvider(_granularity));
    final currentPeriodAsync = ref.watch(currentPeriodStatsProvider);
    final comparisonAsync = ref.watch(monthComparisonProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          currentPeriodAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: LoadingIndicator(),
            ),
            error: (e, _) => ErrorView(message: Failure.from(e).message),
            data: (periods) => _CurrentPeriodSummary(periods: periods),
          ),
          const SizedBox(height: 20),
          comparisonAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (cmp) => _MonthComparisonCard(
                current: cmp.current, previous: cmp.previous),
          ),
          const SizedBox(height: 24),
          Text('Trend', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          SegmentedButton<StatsGranularity>(
            segments: const [
              ButtonSegment(value: StatsGranularity.day, label: Text('Daily')),
              ButtonSegment(
                  value: StatsGranularity.week, label: Text('Weekly')),
              ButtonSegment(
                  value: StatsGranularity.month, label: Text('Monthly')),
            ],
            selected: {_granularity},
            onSelectionChanged: (s) => setState(() => _granularity = s.first),
          ),
          const SizedBox(height: 20),
          rangesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: LoadingIndicator(),
            ),
            error: (e, _) => ErrorView(message: Failure.from(e).message),
            data: (periods) {
              final totalIncome = _sum(periods.map((p) => p.income));
              final totalExpenses = _sum(periods.map((p) => p.expenses));
              final hasAnyData =
                  periods.any((p) => !p.income.isEmpty || !p.expenses.isEmpty);

              if (!hasAnyData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No income or spending recorded in this period yet. Add a transaction to see your cash flow.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Income',
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 4),
                              MoneyTotalsDisplay(totalIncome,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Spending',
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 4),
                              MoneyTotalsDisplay(totalExpenses,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Income vs Spending',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Amounts are converted to your display currency for comparison. Saved transactions keep their original currency.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SectionCard(
                    child: SizedBox(
                      height: 200,
                      child: _ComparisonBarChart(
                        periods: periods,
                        currency: ref.watch(defaultCurrencyProvider),
                        rates: ref.watch(currencyRatesProvider).valueOrNull,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const _LegendDot(color: Colors.green),
                      const SizedBox(width: 4),
                      const Text('Income'),
                      const SizedBox(width: 16),
                      const _LegendDot(color: Colors.redAccent),
                      const SizedBox(width: 4),
                      const Text('Spending'),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  MoneyByCurrency _sum(Iterable<MoneyByCurrency> buckets) {
    final map = <String, int>{};
    for (final bucket in buckets) {
      for (final m in bucket.entries) {
        map[m.currency] = (map[m.currency] ?? 0) + m.minorUnits;
      }
    }
    return MoneyByCurrency(map);
  }
}

class _ComparisonBarChart extends StatelessWidget {
  final List<MonthStats> periods;
  final String currency;
  final CurrencyRates? rates;
  const _ComparisonBarChart({
    required this.periods,
    required this.currency,
    required this.rates,
  });

  @override
  Widget build(BuildContext context) {
    double displayAmount(MoneyByCurrency amounts) {
      var total = 0.0;
      for (final money in amounts.entries) {
        final converted =
            rates?.convert(money.asDouble, money.currency, currency);
        if (converted != null) {
          total += converted;
        } else if (money.currency == currency) {
          total += money.asDouble;
        }
      }
      return total;
    }

    final maxY = periods
        .map((p) => [displayAmount(p.income), displayAmount(p.expenses)]
            .reduce((a, b) => a > b ? a : b))
        .fold(0.0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxY * 1.2).clamp(10, double.infinity),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= periods.length)
                  return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(periods[i].periodKey,
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < periods.length; i++)
            BarChartGroupData(x: i, barsSpace: 3, barRods: [
              BarChartRodData(
                toY: displayAmount(periods[i].income),
                width: 8,
                borderRadius: BorderRadius.circular(3),
                color: Colors.green,
              ),
              BarChartRodData(
                toY: displayAmount(periods[i].expenses),
                width: 8,
                borderRadius: BorderRadius.circular(3),
                color: Colors.redAccent,
              ),
            ]),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _CurrentPeriodSummary extends StatelessWidget {
  final ({MonthStats today, MonthStats week, MonthStats month}) periods;
  const _CurrentPeriodSummary({required this.periods});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This Period', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _PeriodCard(label: 'Today', stats: periods.today)),
            const SizedBox(width: 10),
            Expanded(
                child: _PeriodCard(label: 'This Week', stats: periods.week)),
            const SizedBox(width: 10),
            Expanded(
                child: _PeriodCard(label: 'This Month', stats: periods.month)),
          ],
        ),
      ],
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final String label;
  final MonthStats stats;
  const _PeriodCard({required this.label, required this.stats});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyTotalsDisplay(stats.income,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.green)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyTotalsDisplay(stats.expenses,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _MonthComparisonCard extends StatelessWidget {
  final MonthStats current;
  final MonthStats previous;
  const _MonthComparisonCard({required this.current, required this.previous});

  int _pkr(MoneyByCurrency m) => m.toMap()['PKR'] ?? 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final incomeDelta = _pkr(current.income) - _pkr(previous.income);
    final expenseDelta = _pkr(current.expenses) - _pkr(previous.expenses);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Month vs Last Month',
              style: Theme.of(context).textTheme.titleSmall),
          Text('(same number of days into each month)',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          _ComparisonRow(
            label: 'Income',
            currentValue: current.income,
            deltaMinor: incomeDelta,
            goodWhenPositive: true,
          ),
          const SizedBox(height: 10),
          _ComparisonRow(
            label: 'Spending',
            currentValue: current.expenses,
            deltaMinor: expenseDelta,
            goodWhenPositive: false,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final MoneyByCurrency currentValue;
  final int deltaMinor; // in minor units, PKR-only comparison
  final bool goodWhenPositive;
  const _ComparisonRow({
    required this.label,
    required this.currentValue,
    required this.deltaMinor,
    required this.goodWhenPositive,
  });

  @override
  Widget build(BuildContext context) {
    final isGood = goodWhenPositive ? deltaMinor >= 0 : deltaMinor <= 0;
    final color = deltaMinor == 0
        ? Colors.grey
        : (isGood ? Colors.green : Colors.redAccent);
    final arrow = deltaMinor == 0
        ? Icons.remove_rounded
        : (deltaMinor > 0
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded);
    final deltaAbs = Money(deltaMinor.abs(), 'PKR').format();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              MoneyTotalsDisplay(currentValue,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Row(
          children: [
            Icon(arrow, size: 16, color: color),
            const SizedBox(width: 2),
            Text(deltaAbs,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}
