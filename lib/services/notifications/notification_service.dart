import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../app/theme/app_tokens.dart';

enum RepeatInterval { daily, weekly, monthly }

enum ReminderScheduleOutcome { exact, approximate, notificationsDisabled }

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
  String? _launchPayload;

  String? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
    } catch (_) {
      // Keep startup resilient if the OS timezone plugin is unavailable.
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _launchPayload = launchDetails?.notificationResponse?.payload;
    }

    const channelGroup = AndroidNotificationChannelGroup(
      'worklog_alerts',
      'WorkLog alerts',
      description: 'Notifications created by WorkLog',
    );
    const channel = AndroidNotificationChannel(
      // Android locks sound/vibration preferences once a channel is created.
      'reminders_channel_v3',
      'Reminders',
      description: 'Scheduled reminders you created in WorkLog',
      groupId: 'worklog_alerts',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    const overdueChannel = AndroidNotificationChannel(
      'overdue_channel_v2',
      'Overdue Invoices',
      description: 'Alerts when a client invoice becomes overdue',
      groupId: 'worklog_alerts',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannelGroup(channelGroup);
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

  /// Checks notification visibility and asks for Android's special exact
  /// alarm access only when a user schedules a reminder. If declined, we can
  /// still schedule a best-effort inexact alarm rather than losing it.
  Future<ReminderScheduleOutcome> prepareReminderSchedule() async {
    if (!await areNotificationsEnabled()) {
      return ReminderScheduleOutcome.notificationsDisabled;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return ReminderScheduleOutcome.exact;

    final canScheduleExact =
        await androidPlugin.canScheduleExactNotifications() ?? true;
    if (canScheduleExact) return ReminderScheduleOutcome.exact;

    final granted = await androidPlugin.requestExactAlarmsPermission() ?? false;
    return granted
        ? ReminderScheduleOutcome.exact
        : ReminderScheduleOutcome.approximate;
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
    AndroidScheduleMode androidScheduleMode =
        AndroidScheduleMode.exactAllowWhileIdle,
  }) async {
    if (dateTime.isBefore(DateTime.now())) return;
    final scheduledDate = tz.TZDateTime.from(dateTime, tz.local);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders_channel_v3',
        'Reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: 'ic_stat_worklog',
        color: AppColors.forestLight,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(body),
        groupKey: 'worklog_reminders',
        showWhen: true,
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
      androidScheduleMode: androidScheduleMode,
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
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'overdue_channel_v2',
        'Overdue Invoices',
        channelDescription: 'Alerts when a client invoice becomes overdue',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: 'ic_stat_worklog',
        color: AppColors.forestLight,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(body),
        groupKey: 'worklog_overdue',
        showWhen: true,
      ),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }
}
