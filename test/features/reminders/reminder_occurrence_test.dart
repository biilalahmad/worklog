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
}
