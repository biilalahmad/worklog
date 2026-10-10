import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_keys.dart';
import '../../../../core/utils/local_day_provider.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../clients/presentation/providers/client_providers.dart';
import '../../domain/work_entry.dart';
import '../providers/work_providers.dart';
import '../../../../core/errors/failure.dart';

class VideoStatsScreen extends ConsumerWidget {
  const VideoStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localCalendarDayProvider);
    final now = DateTime.now();
    final todayRange =
        DateRange(DateKeys.startOfDay(now), DateKeys.endOfDay(now));
    final weekRange =
        DateRange(DateKeys.startOfWeek(now), DateKeys.endOfDay(now));
    final monthRange =
        DateRange(DateKeys.startOfMonth(now), DateKeys.endOfDay(now));

    final todayAsync = ref.watch(workEntriesForRangeProvider(todayRange));
    final weekAsync = ref.watch(workEntriesForRangeProvider(weekRange));
    final monthAsync = ref.watch(workEntriesForRangeProvider(monthRange));

    return Scaffold(
      appBar: AppBar(title: const Text('Work Stats')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'A clear view of your workload and time.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Row(
            children: [
              Expanded(child: _PeriodCard(label: 'Today', async: todayAsync)),
              const SizedBox(width: 12),
              Expanded(
                  child: _PeriodCard(label: 'This Week', async: weekAsync)),
            ],
          ),
          const SizedBox(height: 12),
          _PeriodCard(label: 'This Month', async: monthAsync),
          const SizedBox(height: 20),
          Text('By work type (this month)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          monthAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => ErrorView(message: Failure.from(e).message),
            data: (entries) {
              final byType = <String, List<WorkEntry>>{};
              for (final entry in entries) {
                final type = entry.workType.trim().isEmpty
                    ? 'General Work'
                    : entry.workType.trim();
                byType.putIfAbsent(type, () => []).add(entry);
              }
              if (byType.isEmpty) {
                return const Text('No work logged this month.');
              }
              final types = byType.entries.toList()
                ..sort((a, b) => b.value.length.compareTo(a.value.length));
              return Column(
                children: [
                  for (final item in types)
                    _WorkTypeRow(type: item.key, entries: item.value),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('By client (this month)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          monthAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => ErrorView(message: Failure.from(e).message),
            data: (entries) {
              final byClient = <String, List<WorkEntry>>{};
              for (final entry in entries) {
                byClient.putIfAbsent(entry.clientId, () => []).add(entry);
              }
              if (byClient.isEmpty) {
                return const Text('No work logged this month.');
              }
              final clients = byClient.entries.toList()
                ..sort((a, b) => b.value.length.compareTo(a.value.length));
              return Column(
                children: [
                  for (final item in clients)
                    _ClientWorkRow(clientId: item.key, entries: item.value),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final String label;
  final AsyncValue<List<WorkEntry>> async;

  const _PeriodCard({required this.label, required this.async});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => const Text('Something went wrong.'),
        data: (entries) {
          final completed = entries
              .where((e) =>
                  e.status == WorkStatus.completed ||
                  e.status == WorkStatus.delivered)
              .length;
          final pending = entries
              .where((e) =>
                  e.status == WorkStatus.pending ||
                  e.status == WorkStatus.inProgress)
              .length;
          final hours =
              entries.fold<double>(0, (sum, e) => sum + e.hoursWorked);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.work_outline_rounded,
                        color: Theme.of(context).colorScheme.primary, size: 18),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(label,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('${entries.length}',
                  style: Theme.of(context).textTheme.headlineSmall),
              Text('work entries',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Divider(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.6)),
              const SizedBox(height: 7),
              Text(
                  '$completed completed · $pending open · ${hours.toStringAsFixed(1)} hours',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ],
          );
        },
      ),
    );
  }
}

class _WorkTypeRow extends StatelessWidget {
  final String type;
  final List<WorkEntry> entries;

  const _WorkTypeRow({required this.type, required this.entries});

  @override
  Widget build(BuildContext context) {
    final completed = entries
        .where((e) =>
            e.status == WorkStatus.completed ||
            e.status == WorkStatus.delivered)
        .length;
    final hours = entries.fold<double>(0, (sum, e) => sum + e.hoursWorked);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                      '$completed completed · ${hours.toStringAsFixed(1)} hours'),
                ],
              ),
            ),
            Text(
                '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ClientWorkRow extends ConsumerWidget {
  final String clientId;
  final List<WorkEntry> entries;

  const _ClientWorkRow({required this.clientId, required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientProvider(clientId));
    final completed = entries
        .where((e) =>
            e.status == WorkStatus.completed ||
            e.status == WorkStatus.delivered)
        .length;
    final hours = entries.fold<double>(0, (sum, e) => sum + e.hoursWorked);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.person_outline_rounded,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clientAsync.valueOrNull?.name ?? 'Loading client…',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                      '$completed completed · ${hours.toStringAsFixed(1)} hours'),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                  '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
