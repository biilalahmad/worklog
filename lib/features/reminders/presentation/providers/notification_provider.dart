import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/notifications/notification_service.dart';
import '../../domain/reminder.dart';

/// Single app-wide NotificationService instance, initialized once in
/// main.dart. Reminder screens read this to schedule/cancel alerts
/// whenever a reminder is created, edited, completed or deleted.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

extension ReminderNotificationScheduling on NotificationService {
  Future<void> scheduleForReminder(Reminder reminder) {
    RepeatInterval? repeat;
    switch (reminder.repeat) {
      case RepeatOption.daily:
        repeat = RepeatInterval.daily;
        break;
      case RepeatOption.weekly:
        repeat = RepeatInterval.weekly;
        break;
      case RepeatOption.monthly:
        repeat = RepeatInterval.monthly;
        break;
      case RepeatOption.none:
        repeat = null;
    }
    final schedules = <Future<void>>[
      schedule(
        id: reminder.notificationId,
        title: reminder.title,
        body: reminder.description?.trim().isNotEmpty == true
            ? reminder.description!.trim()
            : 'Your reminder is due.',
        dateTime: reminder.dateTime,
        repeat: repeat,
        payload: reminder.id,
      ),
    ];
    if (reminder.priority == ReminderPriority.high) {
      for (var followUp = 1; followUp <= 2; followUp++) {
        schedules.add(schedule(
          id: reminder.notificationId + followUp,
          title: reminder.title,
          body: reminder.description?.trim().isNotEmpty == true
              ? reminder.description!.trim()
              : 'Your reminder is due.',
          dateTime: reminder.dateTime.add(Duration(minutes: followUp * 5)),
          repeat: repeat,
          payload: reminder.id,
        ));
      }
    }
    return Future.wait(schedules).then((_) {});
  }

  Future<void> cancelReminderNotifications(Reminder reminder) async {
    await cancel(reminder.notificationId);
    await cancel(reminder.notificationId + 1);
    await cancel(reminder.notificationId + 2);
  }
}
