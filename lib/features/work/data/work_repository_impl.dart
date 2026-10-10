import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/offline_data_store.dart';

import '../domain/work_entry.dart';
import '../domain/work_repository.dart';

class WorkRepositoryImpl implements WorkRepository {
  final SupabaseClient _client;

  WorkRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<List<WorkEntry>> watchEntriesForRange(DateTime start, DateTime end) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'work_entries',
            queryKey: 'all',
            remote: _client
                .from('work_entries')
                .stream(primaryKey: ['id']).order('date', ascending: false))
        .map((rows) => rows
            .map(WorkEntry.fromMap)
            .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
            .toList());
  }

  @override
  Stream<List<WorkEntry>> watchEntriesForClient(String clientId) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'work_entries',
            queryKey: 'client:$clientId',
            remote: _client
                .from('work_entries')
                .stream(primaryKey: ['id'])
                .eq('client_id', clientId)
                .order('date', ascending: false))
        .map((rows) => rows
            .where((row) => row['client_id'] == clientId)
            .map(WorkEntry.fromMap)
            .toList());
  }

  @override
  Stream<List<WorkEntry>> watchAllEntries({int limit = 100}) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'work_entries',
            queryKey: 'all-limit:$limit',
            remote: _client
                .from('work_entries')
                .stream(primaryKey: ['id'])
                .order('date', ascending: false)
                .limit(limit))
        .map((rows) => rows.map(WorkEntry.fromMap).toList());
  }

  @override
  Future<String> addEntry(WorkEntry entry) async {
    return OfflineDataStore.instance.insert(
        _client, 'work_entries', entry.toWritableMap(),
        id: entry.id.isEmpty ? null : entry.id);
  }

  @override
  Future<void> updateEntry(WorkEntry entry) {
    return OfflineDataStore.instance
        .update(_client, 'work_entries', entry.id, entry.toWritableMap());
  }

  @override
  Future<void> deleteEntry(String entryId) {
    return OfflineDataStore.instance.delete(_client, 'work_entries', entryId);
  }

  @override
  Future<void> startTimer(String entryId) async {
    final rows = await OfflineDataStore.instance.fetchRows(
      client: _client,
      table: 'work_entries',
      queryKey: 'id:$entryId',
      fetch: () async =>
          await _client.from('work_entries').select().eq('id', entryId),
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    if (row['timer_started_at'] != null) return; // already running
    await OfflineDataStore.instance.update(_client, 'work_entries', entryId,
        {'timer_started_at': DateTime.now().toUtc().toIso8601String()});
  }

  @override
  Future<void> stopTimer(String entryId) async {
    final rows = await OfflineDataStore.instance.fetchRows(
      client: _client,
      table: 'work_entries',
      queryKey: 'id:$entryId',
      fetch: () async =>
          await _client.from('work_entries').select().eq('id', entryId),
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    final startedAtRaw = row['timer_started_at'] as String?;
    if (startedAtRaw == null) return; // not running
    final startedAt = DateTime.parse(startedAtRaw);
    final elapsedHours =
        DateTime.now().toUtc().difference(startedAt).inSeconds / 3600.0;
    final currentHours = (row['hours_worked'] as num?)?.toDouble() ?? 0;
    await OfflineDataStore.instance.update(_client, 'work_entries', entryId, {
      'timer_started_at': null,
      'hours_worked': currentHours + elapsedHours,
    });
  }

  @override
  Future<List<WorkEntry>> getAllEntries() async {
    final rows = await OfflineDataStore.instance.fetchRows(
      client: _client,
      table: 'work_entries',
      queryKey: 'all',
      fetch: () async => await _client
          .from('work_entries')
          .select()
          .order('date', ascending: false),
    );
    return rows.map(WorkEntry.fromMap).toList();
  }
}
