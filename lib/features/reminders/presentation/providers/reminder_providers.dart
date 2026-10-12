import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reminder_repository_impl.dart';
import '../../domain/reminder.dart';
import '../../domain/reminder_repository.dart';

final reminderRepositoryProvider =
    Provider<ReminderRepository>((ref) => ReminderRepositoryImpl());

final upcomingRemindersProvider =
    StreamProvider.autoDispose<List<Reminder>>((ref) {
  return ref.watch(reminderRepositoryProvider).watchUpcoming();
});

final remindersForDateProvider =
    StreamProvider.autoDispose.family<List<Reminder>, DateTime>((ref, date) {
  return ref.watch(reminderRepositoryProvider).watchForDate(date);
});

// -- Notification service wiring -------------------------------------
