import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum RepeatInterval { daily, weekly, monthly }

/// Thin wrapper around flutter_local_notifications for every local,
/// on-device notification the app schedules — currently Reminders.
/// Everything here is local scheduling; there is no server/FCM
/// involved, so notifications fire even with the app closed as long
/// as the OS lets scheduled alarms through (handled by
/// AndroidScheduleMode.exactAllowWhileIdle below).
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Called when the user taps a delivered notification — set once
  /// from main.dart/router wiring so a tap can navigate straight to
  /// the relevant reminder.
  void Function(String? payload)? onNotificationTap;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );

    const channel = AndroidNotificationChannel(
      'reminders_channel',
      'Reminders',
      description: 'Scheduled reminders you created in WorkLog',
      importance: Importance.high,
    );
    const overdueChannel = AndroidNotificationChannel(
      'overdue_channel',
      'Overdue Invoices',
      description: 'Alerts when a client invoice becomes overdue',
      importance: Importance.high,
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(overdueChannel);
  }

  /// Prompts for permission if not already decided. Returns whether
  /// notifications are allowed after the prompt.
  Future<bool> requestPermissions() async {
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return androidGranted ?? false;
  }

  /// Checks current permission status without prompting — used to
  /// show a clear "notifications are off" banner instead of silently
  /// failing to schedule anything.
  Future<bool> areNotificationsEnabled() async {
    final androidEnabled = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    if (androidEnabled != null) return androidEnabled;
    // Fall back to permission_handler if the notification plugin cannot
    // determine Android's current permission state.
    final status = await ph.Permission.notification.status;
    return status.isGranted;
  }

  /// Opens the device's app-settings screen so the user can turn
  /// notifications on manually after having denied them once (the OS
  /// won't show the in-app prompt again).
  Future<void> openNotificationSettings() async {
    await ph.openAppSettings();
  }

  /// Schedules (or re-schedules, if [id] already has a pending
  /// notification — flutter_local_notifications replaces same-id
  /// notifications automatically) a one-off or repeating local
  /// notification. [payload] is handed back on tap so the app can
  /// navigate to the right screen.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    RepeatInterval? repeat,
    String? payload,
  }) async {
    if (dateTime.isBefore(DateTime.now())) return;
    final scheduledDate = tz.TZDateTime.from(dateTime, tz.local);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders_channel',
        'Reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      ),
    );

    DateTimeComponents? matchComponents;
    switch (repeat) {
      case RepeatInterval.daily:
        matchComponents = DateTimeComponents.time;
        break;
      case RepeatInterval.weekly:
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
        break;
      case RepeatInterval.monthly:
        matchComponents = DateTimeComponents.dayOfMonthAndTime;
        break;
      case null:
        matchComponents = null;
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchComponents,
      payload: payload,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  /// Shows a notification immediately (no scheduling) — used for
  /// overdue-invoice alerts, which fire the moment the app detects a
  /// newly-overdue project rather than at some pre-planned time.
  Future<void> showNow(
      {required int id,
      required String title,
      required String body,
      String? payload}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'overdue_channel',
        'Overdue Invoices',
        channelDescription: 'Alerts when a client invoice becomes overdue',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }
}
