import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/date_keys.dart';
import '../../data/stats_repository_impl.dart';
import '../../domain/stats.dart';
import '../../domain/stats_repository.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) => StatsRepositoryImpl());

final monthStatsProvider = StreamProvider.family<MonthStats, String>((ref, periodKey) {
  return ref.watch(statsRepositoryProvider).watchMonth(periodKey);
});

final monthsStatsProvider =
    StreamProvider.family<List<MonthStats>, List<String>>((ref, periodKeys) {
  return ref.watch(statsRepositoryProvider).watchMonths(periodKeys);
});

/// "Today" / "This week" / "This month so far" totals — distinct from
/// rangeStatsProvider's rolling buckets (which are for the trend
/// chart): these three always represent the CURRENT period measured
/// from its natural start (midnight today, Monday of this week, the
/// 1st of this month) up to now, so "This month" is always genuine
/// month-to-date and naturally resets to 0 the moment a new month
/// begins — no special reset logic needed, it falls out of the date
/// math itself.
final currentPeriodStatsProvider = StreamProvider<({MonthStats today, MonthStats week, MonthStats month})>((ref) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final endOfToday = DateKeys.endOfDay(now);
  final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1)); // Monday
  final startOfMonth = DateTime(now.year, now.month, 1);

  final repo = ref.watch(statsRepositoryProvider);
  final combined = repo.watchRanges([
    StatsRange(key: 'today', start: startOfToday, end: endOfToday),
    StatsRange(key: 'week', start: startOfWeek, end: endOfToday),
    StatsRange(key: 'month', start: startOfMonth, end: endOfToday),
  ]);
  return combined.map((list) => (today: list[0], week: list[1], month: list[2]));
});

/// This month (month-to-date) vs the same number of days into last
/// month — a fair apples-to-apples comparison rather than comparing a
/// partial current month against a full previous one.
final monthComparisonProvider = StreamProvider<({MonthStats current, MonthStats previous})>((ref) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final dayOfMonth = now.day;

  final prevMonthDate = DateTime(now.year, now.month - 1, 1);
  final startOfPrevMonth = DateTime(prevMonthDate.year, prevMonthDate.month, 1);
  // Clamp so e.g. "up to the 31st" of a shorter previous month doesn't
  // overflow into the month after it.
  final daysInPrevMonth = DateTime(prevMonthDate.year, prevMonthDate.month + 1, 0).day;
  final endOfPrevMonth = DateTime(
    prevMonthDate.year,
    prevMonthDate.month,
    dayOfMonth > daysInPrevMonth ? daysInPrevMonth : dayOfMonth,
    23,
    59,
    59,
  );

  final repo = ref.watch(statsRepositoryProvider);
  final combined = repo.watchRanges([
    StatsRange(key: 'current', start: startOfMonth, end: DateKeys.endOfDay(now)),
    StatsRange(key: 'previous', start: startOfPrevMonth, end: endOfPrevMonth),
  ]);
  return combined.map((list) => (current: list[0], previous: list[1]));
});
/// builds the right set of buckets for the chosen granularity and lets
/// the repository fetch + live-update them.
final rangeStatsProvider =
    StreamProvider.family<List<MonthStats>, StatsGranularity>((ref, granularity) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  List<StatsRange> ranges;

  switch (granularity) {
    case StatsGranularity.day:
      ranges = List.generate(7, (i) {
        final d = today.subtract(Duration(days: 6 - i));
        return StatsRange(key: DateFormat('EEE').format(d), start: d, end: DateKeys.endOfDay(d));
      });
      break;
    case StatsGranularity.week:
      ranges = List.generate(6, (i) {
        final end = today.subtract(Duration(days: 7 * (5 - i)));
        final start = end.subtract(const Duration(days: 6));
        return StatsRange(
          key: DateFormat('MMM d').format(start),
          start: start,
          end: DateKeys.endOfDay(end),
        );
      });
      break;
    case StatsGranularity.month:
      ranges = List.generate(6, (i) {
        final d = DateTime(now.year, now.month - (5 - i), 1);
        final start = DateTime(d.year, d.month, 1);
        final end = DateTime(d.year, d.month + 1, 1).subtract(const Duration(milliseconds: 1));
        return StatsRange(key: DateFormat('MMM').format(d), start: start, end: end);
      });
      break;
  }

  return ref.watch(statsRepositoryProvider).watchRanges(ranges);
});
