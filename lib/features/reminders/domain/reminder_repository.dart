import 'reminder.dart';

abstract class ReminderRepository {
  Stream<List<Reminder>> watchUpcoming();
  Stream<List<Reminder>> watchForDate(DateTime date);
  Future<String> addReminder(Reminder reminder);
  Future<void> updateReminder(Reminder reminder);
  Future<void> toggleCompleted(String reminderId, bool completed);
  Future<void> deleteReminder(String reminderId);
}
