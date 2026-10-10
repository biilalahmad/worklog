import 'stats.dart';

abstract class StatsRepository {
  Stream<MonthStats> watchMonth(String periodKey);
  Stream<List<MonthStats>> watchMonths(List<String> periodKeys);
  Stream<List<MonthStats>> watchRanges(List<StatsRange> ranges);
}
