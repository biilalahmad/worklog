import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidScheduleMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:worklog/features/clients/presentation/providers/client_providers.dart';
import 'package:worklog/features/reminders/domain/reminder.dart';
import 'package:worklog/features/reminders/domain/reminder_repository.dart';
import 'package:worklog/features/reminders/presentation/providers/notification_provider.dart';
import 'package:worklog/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:worklog/features/reminders/presentation/screens/reminder_form_screen.dart';
import 'package:worklog/services/notifications/notification_service.dart';

void main() {
  testWidgets(
      'returns to the previous screen while notification permission is pending',
      (tester) async {
    final repository = _FakeReminderRepository();
    final notifications = _DelayedNotificationService();
    final router = GoRouter(
      initialLocation: '/home/reminders/new',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Home screen')),
          ),
          routes: [
            GoRoute(
              path: 'reminders/new',
              builder: (context, state) => const ReminderFormScreen(),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderRepositoryProvider.overrideWithValue(repository),
          notificationServiceProvider.overrideWithValue(notifications),
          clientsListProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Send proposal');
    await tester.tap(find.text('Add Reminder'));
    await tester.pumpAndSettle();

    expect(repository.savedReminder?.title, 'Send proposal');
    expect(notifications.permissionCheckStarted, isTrue);
    expect(find.text('Home screen'), findsOneWidget);
    expect(tester.takeException(), isNull);

    notifications.permissionCompleter.complete(ReminderScheduleOutcome.exact);
  });
}

class _FakeReminderRepository implements ReminderRepository {
  Reminder? savedReminder;

  @override
  Future<String> addReminder(Reminder reminder) async {
    savedReminder = reminder;
    return 'reminder-1';
  }

  @override
  Future<void> deleteReminder(String reminderId) async {}

  @override
  Future<void> toggleCompleted(String reminderId, bool completed) async {}

  @override
  Future<void> updateReminder(Reminder reminder) async {
    savedReminder = reminder;
  }

  @override
  Stream<List<Reminder>> watchForDate(DateTime date) => Stream.value([]);

  @override
  Stream<List<Reminder>> watchUpcoming() => Stream.value([]);
}

class _DelayedNotificationService extends NotificationService {
  final permissionCompleter = Completer<ReminderScheduleOutcome>();
  bool permissionCheckStarted = false;

  @override
  Future<ReminderScheduleOutcome> prepareReminderSchedule() {
    permissionCheckStarted = true;
    return permissionCompleter.future;
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    RepeatInterval? repeat,
    String? payload,
    AndroidScheduleMode androidScheduleMode =
        AndroidScheduleMode.exactAllowWhileIdle,
  }) async {}
}
