import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/reminders/domain/reminder.dart';

void main() {
  final daily = Reminder(
    id: 'daily',
    title: 'Daily',
    dateTime: DateTime(2026, 10, 10, 9),
    repeat: RepeatOption.daily,
  );
  final monthly = Reminder(
    id: 'monthly',
    title: 'Monthly',
    dateTime: DateTime(2026, 1, 31, 9),
    repeat: RepeatOption.monthly,
  );

  test('daily reminder resolves to its next future local occurrence', () {
    expect(
      daily.nextOccurrence(DateTime(2026, 10, 12, 9)),
      DateTime(2026, 10, 13, 9),
    );
  });

  test('monthly reminder clamps month-end dates safely', () {
    expect(
      monthly.nextOccurrence(DateTime(2026, 2, 1)),
      DateTime(2026, 2, 28, 9),
    );
  });

  test('one-time reminders keep their original due time', () {
    final oneTime = Reminder(
      id: 'once',
      title: 'Once',
      dateTime: DateTime(2026, 10, 10, 10),
    );
    expect(oneTime.nextOccurrence(DateTime(2026, 10, 11)), oneTime.dateTime);
  });

  test('reminder timestamps round-trip through Supabase as UTC instants', () {
    final selectedLocalTime = DateTime(2026, 10, 12, 16, 5);
    final reminder = Reminder(
      id: 'timezone-round-trip',
      title: 'Timezone check',
      dateTime: selectedLocalTime,
    );

    final writable = reminder.toWritableMap();
    expect(writable['date_time'], endsWith('Z'));

    final loaded = Reminder.fromMap({
      'id': reminder.id,
      'title': reminder.title,
      ...writable,
    });
    expect(loaded.dateTime.isUtc, isFalse);
    expect(loaded.dateTime.isAtSameMomentAs(selectedLocalTime), isTrue);
  });
}
