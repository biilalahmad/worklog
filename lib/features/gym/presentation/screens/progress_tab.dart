import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/date_keys.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/body_stat.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_loading_placeholder.dart';

class ProgressTab extends ConsumerStatefulWidget {
  const ProgressTab({super.key});

  @override
  ConsumerState<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<ProgressTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get _previousMonth => DateTime(_month.year, _month.month - 1);

  bool get _isCurrentMonth =>
      _month.year == DateTime.now().year &&
      _month.month == DateTime.now().month;

  List<BodyStat> _inMonth(List<BodyStat> stats, DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final result = stats
        .where((stat) => !stat.date.isBefore(start) && stat.date.isBefore(end))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  double? _latestValue(List<BodyStat> stats, double? Function(BodyStat) read) {
    for (final stat in stats) {
      final value = read(stat);
      if (value != null) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bodyStatsAsync = ref.watch(bodyStatsListProvider);
    final start = DateTime(_month.year, _month.month);
    final end = DateTime(_month.year, _month.month + 1)
        .subtract(const Duration(microseconds: 1));
    final statsRange = GymDateRange(DateKeys.startOfDay(start), end);
    final gymStatsAsync = ref.watch(gymStatsForRangeProvider(statsRange));

    final allStats = bodyStatsAsync.valueOrNull ?? const <BodyStat>[];
    final currentMonth = _inMonth(allStats, _month);
    final previousMonth = _inMonth(allStats, _previousMonth);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        Text('Training progress',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        gymStatsAsync.when(
          loading: () => const GymLoadingPlaceholder(rows: 2),
          error: (error, _) => ErrorView(
            message: Failure.from(error).message,
            onRetry: () => ref.invalidate(gymStatsForRangeProvider(statsRange)),
          ),
          data: (stats) => GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.25,
            children: [
              _TrainingStatCard(
                  icon: Icons.event_available_rounded,
                  label: 'Workouts',
                  value: '${stats.workoutsCompleted}'),
              _TrainingStatCard(
                  icon: Icons.fitness_center_rounded,
                  label: 'Volume',
                  value: '${stats.totalVolume.toStringAsFixed(0)} kg'),
              _TrainingStatCard(
                  icon: Icons.repeat_rounded,
                  label: 'Sets',
                  value: '${stats.totalSets}'),
              _TrainingStatCard(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Streak',
                  value: '${ref.watch(workoutStreakProvider)} days'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your progress',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Add measurements to compare changes by month.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => context.push('/gym/body-stat/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text('Monthly comparison',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Semantics(
              label: 'Selected month',
              child: Text(DateFormat('MMMM yyyy').format(_month),
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: _isCurrentMonth
                  ? null
                  : () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Text(
          '${DateFormat('MMM yyyy').format(_month)} compared with ${DateFormat('MMM yyyy').format(_previousMonth)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        if (bodyStatsAsync.isLoading)
          const GymLoadingPlaceholder(rows: 2)
        else if (bodyStatsAsync.hasError)
          ErrorView(
            message: Failure.from(bodyStatsAsync.error!).message,
            onRetry: () => ref.invalidate(bodyStatsListProvider),
          )
        else if (currentMonth.isEmpty && previousMonth.isEmpty)
          const EmptyState(
            icon: Icons.monitor_weight_outlined,
            title: 'No measurements for these months',
            subtitle:
                'Log your weight, height, or other measurements to start a comparison.',
          )
        else
          SectionCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(flex: 2, child: SizedBox.shrink()),
                    Expanded(
                      child: Text(DateFormat('MMM').format(_month),
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                    Expanded(
                      child: Text(DateFormat('MMM').format(_previousMonth),
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                    const SizedBox(width: 80),
                  ],
                ),
                for (final metric in _progressMetrics)
                  _MetricComparisonRow(
                    label: metric.label,
                    unit: metric.unit,
                    current: _latestValue(currentMonth, metric.read),
                    previous: _latestValue(previousMonth, metric.read),
                    format: metric.format,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProgressMetric {
  const _ProgressMetric(this.label, this.unit, this.read, this.format);
  final String label;
  final String unit;
  final double? Function(BodyStat) read;
  final String Function(double) format;
}

String _oneDecimal(double value) => value.toStringAsFixed(1);

final _progressMetrics = <_ProgressMetric>[
  _ProgressMetric('Weight', 'kg', (stat) => stat.weight, _oneDecimal),
  _ProgressMetric('Height', 'cm', (stat) => stat.heightCm, _oneDecimal),
  _ProgressMetric('Body fat', '%', (stat) => stat.bodyFatPct, _oneDecimal),
  _ProgressMetric('Waist', 'cm', (stat) => stat.waistCm, _oneDecimal),
  _ProgressMetric('Chest', 'cm', (stat) => stat.chestCm, _oneDecimal),
  _ProgressMetric('Arm', 'cm', (stat) => stat.armCm, _oneDecimal),
  _ProgressMetric('Thigh', 'cm', (stat) => stat.thighCm, _oneDecimal),
];

class _MetricComparisonRow extends StatelessWidget {
  const _MetricComparisonRow({
    required this.label,
    required this.unit,
    required this.current,
    required this.previous,
    required this.format,
  });

  final String label;
  final String unit;
  final double? current;
  final double? previous;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final difference =
        current != null && previous != null ? current! - previous! : null;
    final changeLabel = difference == null
        ? '—'
        : '${difference > 0 ? '+' : ''}${format(difference)} $unit';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          Expanded(
            child: Text(
              current == null ? '—' : '${format(current!)} $unit',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              previous == null ? '—' : '${format(previous!)} $unit',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (difference != null)
                  Icon(
                    difference > 0
                        ? Icons.trending_up_rounded
                        : difference < 0
                            ? Icons.trending_down_rounded
                            : Icons.trending_flat_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                Flexible(
                  child: Text(changeLabel,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelSmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingStatCard extends StatelessWidget {
  const _TrainingStatCard(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Text(label,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
