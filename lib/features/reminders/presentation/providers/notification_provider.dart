import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidScheduleMode;

import '../../../../services/notifications/notification_service.dart';
import '../../domain/reminder.dart';

/// Single app-wide NotificationService instance, initialized once in
/// main.dart. Reminder screens read this to schedule/cancel alerts
/// whenever a reminder is created, edited, completed or deleted.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

extension ReminderNotificationScheduling on NotificationService {
  Future<ReminderScheduleOutcome> scheduleForReminder(Reminder reminder) async {
    final permissionOutcome = await prepareReminderSchedule();
    if (permissionOutcome == ReminderScheduleOutcome.notificationsDisabled) {
      return permissionOutcome;
    }

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
    Future<void> scheduleAll(AndroidScheduleMode mode) async {
      final body = reminder.description?.trim().isNotEmpty == true
          ? reminder.description!.trim()
          : 'Your reminder is due.';
      final schedules = <Future<void>>[
        schedule(
          id: reminder.notificationId,
          title: reminder.title,
          body: body,
          dateTime: reminder.dateTime,
          repeat: repeat,
          payload: reminder.id,
          androidScheduleMode: mode,
        ),
      ];
      if (reminder.priority == ReminderPriority.high) {
        for (var followUp = 1; followUp <= 2; followUp++) {
          schedules.add(schedule(
            id: reminder.notificationId + followUp,
            title: reminder.title,
            body: body,
            dateTime: reminder.dateTime.add(Duration(minutes: followUp * 5)),
            repeat: repeat,
            payload: reminder.id,
            androidScheduleMode: mode,
          ));
        }
      }
      await Future.wait(schedules);
    }

    if (permissionOutcome == ReminderScheduleOutcome.exact) {
      try {
        await scheduleAll(AndroidScheduleMode.exactAllowWhileIdle);
        return ReminderScheduleOutcome.exact;
      } catch (error, stackTrace) {
        // OEMs can report exact-alarm access inaccurately. Retry with the
        // inexact API so unsupported exact alarms do not lose the reminder.
        debugPrint(
            'WorkLog exact reminder scheduling failed; retrying inexact: $error');
        debugPrintStack(stackTrace: stackTrace);
        await scheduleAll(AndroidScheduleMode.inexactAllowWhileIdle);
        return ReminderScheduleOutcome.approximate;
      }
    }

    await scheduleAll(AndroidScheduleMode.inexactAllowWhileIdle);
    return ReminderScheduleOutcome.approximate;
  }

  Future<void> cancelReminderNotifications(Reminder reminder) async {
    await cancel(reminder.notificationId);
    await cancel(reminder.notificationId + 1);
    await cancel(reminder.notificationId + 2);
  }
}
