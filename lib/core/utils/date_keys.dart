import 'package:intl/intl.dart';

/// Canonical date-key helpers. All "day" and "month" document IDs
/// (daily_notes, stats_cache) and calendar bucketing use these so the
/// format is consistent everywhere instead of ad-hoc string formatting.
class DateKeys {
  DateKeys._();

  static String day(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static String month(DateTime date) => DateFormat('yyyy-MM').format(date);

  /// Finance dates represent a calendar day, even though the existing
  /// Supabase columns are timestamptz. Anchor writes at UTC noon and read
  /// only the stored UTC calendar components so device/server timezones
  /// cannot shift an entry across a daily or monthly boundary.
  static String toStorageCalendarDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day, 12).toIso8601String();

  static DateTime? fromStorageCalendarDate(String? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  static DateTime startOfWeek(DateTime date) {
    final d = startOfDay(date);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime startOfYear(DateTime date) => DateTime(date.year, 1, 1);
}
