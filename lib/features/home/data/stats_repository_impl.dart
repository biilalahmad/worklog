import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/offline_data_store.dart';
import '../../../core/utils/backend_connection.dart';
import '../domain/stats.dart';
import '../domain/stats_repository.dart';

class StatsRepositoryImpl implements StatsRepository {
  final SupabaseClient _client;

  StatsRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<MonthStats> _fetchRange(StatsRange r) async {
    final result = await OfflineDataStore.instance.fetchMap(
      client: _client,
      cacheKey: 'stats:${r.key}',
      fetch: () async {
        final result = await _client.rpc('get_stats_for_range', params: {
          'p_start': r.start.toIso8601String(),
          'p_end': r.end.toIso8601String(),
        });
        return result == null ? null : Map<String, dynamic>.from(result as Map);
      },
    );
    return MonthStats.fromMap(r.key, result);
  }

  StatsRange _rangeForMonth(String periodKey) {
    final parts = periodKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final start = DateTime(year, month, 1);
    final end =
        DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));
    return StatsRange(key: periodKey, start: start, end: end);
  }

  /// Re-runs the aggregate(s) whenever a relevant table changes, so
  /// screens stay live without polling on a timer.
  Stream<List<MonthStats>> _watchAll(List<StatsRange> ranges) {
    late final StreamController<List<MonthStats>> controller;
    final subs = <StreamSubscription>[];
    Timer? refreshTimer;
    var active = true;
    var refreshGeneration = 0;

    Future<void> refresh() async {
      final requestGeneration = ++refreshGeneration;
      try {
        final values = await Future.wait(ranges.map(_fetchRange));
        if (active &&
            requestGeneration == refreshGeneration &&
            controller.hasListener) {
          controller.add(values);
        }
      } catch (error, stack) {
        if (active &&
            requestGeneration == refreshGeneration &&
            controller.hasListener) {
          controller.addError(error, stack);
        }
      }
    }

    void scheduleRefresh() {
      refreshTimer?.cancel();
      refreshTimer = Timer(const Duration(milliseconds: 120), refresh);
    }

    void watchTables() {
      for (final subscription in subs) {
        unawaited(subscription.cancel());
      }
      subs.clear();
      for (final table in ['work_entries', 'income', 'expenses']) {
        subs.add(OfflineDataStore.instance
            .watchRows(
          client: _client,
          table: table,
          queryKey: 'all',
          remote: _client.from(table).stream(primaryKey: ['id']),
        )
            .listen((_) => scheduleRefresh(),
                onError: (Object error, StackTrace stack) {
          debugPrint('Stats subscription for $table failed: $error');
          if (OfflineDataStore.instance.isNetworkError(error)) {
            BackendConnection.instance.reportUnavailable();
          }
          scheduleRefresh();
        }));
      }
    }

    controller = StreamController<List<MonthStats>>(
      onListen: () {
        watchTables();
        refresh();
      },
      onCancel: () {
        active = false;
        refreshTimer?.cancel();
        refreshGeneration++;
        for (final s in subs) {
          unawaited(s.cancel());
        }
      },
    );
    return controller.stream;
  }

  @override
  Stream<MonthStats> watchMonth(String periodKey) {
    return _watchAll([_rangeForMonth(periodKey)]).map((list) => list.first);
  }

  @override
  Stream<List<MonthStats>> watchMonths(List<String> periodKeys) {
    if (periodKeys.isEmpty) return Stream.value(const []);
    return _watchAll(periodKeys.map(_rangeForMonth).toList());
  }

  @override
  Stream<List<MonthStats>> watchRanges(List<StatsRange> ranges) {
    if (ranges.isEmpty) return Stream.value(const []);
    return _watchAll(ranges);
  }
}
