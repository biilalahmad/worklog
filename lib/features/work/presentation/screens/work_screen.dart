import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/date_keys.dart';
import '../../../../core/utils/local_day_provider.dart';
import '../../../../core/utils/search_match.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../clients/presentation/providers/client_providers.dart';
import '../../domain/work_entry.dart';
import '../providers/work_providers.dart';
import '../../../assistant/domain/assistant_contract.dart';
import '../../../assistant/presentation/widgets/assistant_entry.dart';
import '../../../../core/errors/failure.dart';

enum _WorkRangeFilter { all, today, week, month }

class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key});

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  final _searchCtrl = TextEditingController();
  _WorkRangeFilter _filter = _WorkRangeFilter.all;
  String? _clientFilter;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateRange? get _range {
    final now = DateTime.now();
    switch (_filter) {
      case _WorkRangeFilter.all:
        return null;
      case _WorkRangeFilter.today:
        return DateRange(DateKeys.startOfDay(now), DateKeys.endOfDay(now));
      case _WorkRangeFilter.week:
        return DateRange(DateKeys.startOfWeek(now), DateKeys.endOfDay(now));
      case _WorkRangeFilter.month:
        return DateRange(DateKeys.startOfMonth(now), DateKeys.endOfDay(now));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localCalendarDayProvider);
    final range = _range;
    final entriesAsync = range == null
        ? ref.watch(recentWorkEntriesProvider)
        : ref.watch(workEntriesForRangeProvider(range));
    final clientsAsync = ref.watch(clientsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Work stats',
            onPressed: () => context.push('/work/video-stats'),
          ),
          const AssistantShortcutButton(agent: AssistantAgent.work),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/work/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<_WorkRangeFilter>(
                    segments: const [
                      ButtonSegment(
                          value: _WorkRangeFilter.all, label: Text('All')),
                      ButtonSegment(
                          value: _WorkRangeFilter.today, label: Text('Today')),
                      ButtonSegment(
                          value: _WorkRangeFilter.week, label: Text('Week')),
                      ButtonSegment(
                          value: _WorkRangeFilter.month, label: Text('Month')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (s) =>
                        setState(() => _filter = s.first),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) => setState(() => _searchQuery = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search work or client',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          clientsAsync.maybeWhen(
            data: (clients) {
              final query = _searchQuery.trim();
              final visibleClients = query.isEmpty
                  ? clients
                  : clients
                      .where((client) => matchesSearch(client.name, query))
                      .toList();
              return clients.isEmpty || visibleClients.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _clientChip(
                                label: 'All clients',
                                selected: _clientFilter == null,
                                onTap: () =>
                                    setState(() => _clientFilter = null)),
                            const SizedBox(width: 8),
                            ...visibleClients.map((c) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _clientChip(
                                    label: c.name,
                                    selected: _clientFilter == c.id,
                                    onTap: () =>
                                        setState(() => _clientFilter = c.id),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () => const AppListSkeleton(),
              error: (e, _) => ErrorView(message: Failure.from(e).message),
              data: (entries) {
                final clientsById = {
                  for (final client in clientsAsync.valueOrNull ?? const [])
                    client.id: client.name,
                };
                final query = _searchQuery.trim();
                final filtered = entries.where((entry) {
                  if (_clientFilter != null &&
                      entry.clientId != _clientFilter) {
                    return false;
                  }
                  if (query.isEmpty) return true;
                  final clientName = clientsById[entry.clientId] ?? '';
                  return matchesSearch(entry.taskName, query) ||
                      matchesSearch(entry.workType, query) ||
                      matchesSearch(entry.status.label, query) ||
                      matchesSearch(entry.notes ?? '', query) ||
                      matchesSearch(clientName, query);
                }).toList();
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.work_outline,
                    title: query.isEmpty
                        ? 'No work entries found'
                        : 'No search results found',
                    subtitle: query.isEmpty
                        ? 'Tap + to add a work entry'
                        : 'Try another work or client name.',
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    96 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _WorkTile(entry: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientChip(
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimary : scheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      selectedColor: scheme.primary,
      backgroundColor: scheme.surfaceContainerHigh,
      side:
          BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
      checkmarkColor: scheme.onPrimary,
    );
  }
}

class _WorkTile extends ConsumerWidget {
  final WorkEntry entry;
  const _WorkTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientProvider(entry.clientId));
    final tone = switch (entry.status) {
      WorkStatus.completed || WorkStatus.delivered => StatusTone.good,
      WorkStatus.inProgress => StatusTone.warning,
      WorkStatus.revisionRequired => StatusTone.bad,
      WorkStatus.pending => StatusTone.neutral,
    };
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Card(
          margin: EdgeInsets.zero,
          color: scheme.surface.withValues(alpha: .82),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side:
                BorderSide(color: scheme.outlineVariant.withValues(alpha: .72)),
          ),
          child: ListTile(
            onTap: () => context.push('/work/${entry.id}/edit', extra: entry),
            title: Text(
              entry.workType.trim().isEmpty ? 'General Work' : entry.workType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${clientAsync.valueOrNull?.name ?? '...'}  ·  '
                    '${DateFormat('MMM d, yyyy').format(entry.date.toLocal())}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.hoursWorked > 0 ||
                      entry.otherTaskCount > 0 ||
                      entry.workType.trim().toLowerCase() ==
                          'video editing') ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (entry.hoursWorked > 0)
                          Text('${entry.hoursWorked.toStringAsFixed(1)} hr'),
                        if (entry.otherTaskCount > 0)
                          Text('${entry.otherTaskCount} tasks'),
                        if (entry.workType.trim().toLowerCase() ==
                            'video editing')
                          Text('${entry.videoCount} videos'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.timerStartedAt != null) ...[
                  const Icon(Icons.timer_rounded,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: StatusChip(
                    key: ValueKey(entry.status),
                    label: entry.status.label,
                    tone: tone,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
