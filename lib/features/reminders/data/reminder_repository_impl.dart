import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/offline_data_store.dart';
import '../../../core/utils/date_keys.dart';
import '../domain/reminder.dart';
import '../domain/reminder_repository.dart';

class ReminderRepositoryImpl implements ReminderRepository {
  final SupabaseClient _client;
  final Set<String> _expiryDeletesInFlight = {};

  ReminderRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<List<Reminder>> watchUpcoming() {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'reminders',
            queryKey: 'all',
            remote: _client
                .from('reminders')
                .stream(primaryKey: ['id']).order('date_time'))
        .map((rows) {
      final now = DateTime.now();
      final reminders = rows.map(Reminder.fromMap).toList();
      final expiredOneTime = reminders.where((reminder) =>
          !reminder.completed &&
          reminder.repeat == RepeatOption.none &&
          !reminder.dateTime.isAfter(now));
      for (final reminder in expiredOneTime) {
        if (_expiryDeletesInFlight.add(reminder.id)) {
          unawaited(OfflineDataStore.instance
              .delete(_client, 'reminders', reminder.id)
              .catchError((_) {})
              .whenComplete(() => _expiryDeletesInFlight.remove(reminder.id)));
        }
      }
      return reminders
          .where((reminder) =>
              !reminder.completed && reminder.dateTime.isAfter(now))
          .take(50)
          .toList();
    });
  }

  @override
  Stream<List<Reminder>> watchForDate(DateTime date) {
    final start = DateKeys.startOfDay(date);
    final end = DateKeys.endOfDay(date);
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'reminders',
            queryKey: 'date:${DateKeys.day(date)}',
            remote: _client
                .from('reminders')
                .stream(primaryKey: ['id']).order('date_time'))
        .map((rows) => rows
            .map(Reminder.fromMap)
            .where(
                (r) => !r.dateTime.isBefore(start) && !r.dateTime.isAfter(end))
            .toList());
  }

  @override
  Future<String> addReminder(Reminder reminder) async {
    return OfflineDataStore.instance.insert(
        _client, 'reminders', reminder.toWritableMap(),
        id: reminder.id.isEmpty ? null : reminder.id);
  }

  @override
  Future<void> updateReminder(Reminder reminder) {
    return OfflineDataStore.instance
        .update(_client, 'reminders', reminder.id, reminder.toWritableMap());
  }

  @override
  Future<void> toggleCompleted(String reminderId, bool completed) {
    return OfflineDataStore.instance
        .update(_client, 'reminders', reminderId, {'completed': completed});
  }

  @override
  Future<void> deleteReminder(String reminderId) {
    return OfflineDataStore.instance.delete(_client, 'reminders', reminderId);
  }
}
