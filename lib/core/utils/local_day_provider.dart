import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits the current local calendar day and refreshes at the next local
/// midnight. Date based dashboards can watch this so their day/month
/// ranges roll over even when the app stays open overnight.
final localCalendarDayProvider =
    StreamProvider.autoDispose<DateTime>((ref) => _localCalendarDays());

Stream<DateTime> _localCalendarDays() async* {
  while (true) {
    final now = DateTime.now();
    yield DateTime(now.year, now.month, now.day);
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    await Future<void>.delayed(nextMidnight.difference(now));
  }
}
