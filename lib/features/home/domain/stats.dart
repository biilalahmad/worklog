import '../../../core/utils/money.dart';

/// One bucket of time to aggregate stats over — a day, a week, a
/// month, whatever the caller builds. `key` is just a display label
/// for charts/axes.
class StatsRange {
  final String key;
  final DateTime start;
  final DateTime end;
  const StatsRange({required this.key, required this.start, required this.end});
}

enum StatsGranularity { day, week, month }


/// A period's aggregate stats (e.g. one calendar month), computed
/// server-side by the `get_stats_for_range` Postgres function (see
/// supabase/schema.sql) — a single efficient aggregate query instead
/// of downloading every work/income/expense row to sum on the client.
class MonthStats {
  final String periodKey;
  final int videosEdited;
  final int videosDelivered;
  final int tasksCompleted;
  final double hoursWorked;
  final MoneyByCurrency income;
  final MoneyByCurrency expenses;

  const MonthStats({
    required this.periodKey,
    this.videosEdited = 0,
    this.videosDelivered = 0,
    this.tasksCompleted = 0,
    this.hoursWorked = 0,
    this.income = const MoneyByCurrency({}),
    this.expenses = const MoneyByCurrency({}),
  });

  factory MonthStats.empty(String periodKey) => MonthStats(periodKey: periodKey);

  factory MonthStats.fromMap(String periodKey, Map<String, dynamic>? data) {
    if (data == null) return MonthStats.empty(periodKey);
    return MonthStats(
      periodKey: periodKey,
      videosEdited: (data['videosEdited'] as num?)?.toInt() ?? 0,
      videosDelivered: (data['videosDelivered'] as num?)?.toInt() ?? 0,
      tasksCompleted: (data['tasksCompleted'] as num?)?.toInt() ?? 0,
      hoursWorked: (data['hoursWorked'] as num?)?.toDouble() ?? 0,
      income: MoneyByCurrency.fromMap(data['income'] as Map<String, dynamic>?),
      expenses: MoneyByCurrency.fromMap(data['expenses'] as Map<String, dynamic>?),
    );
  }
}
