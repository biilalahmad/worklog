import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sembast/sembast.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide SortOrder;
import 'package:uuid/uuid.dart';
import 'local_database_factory.dart';
import '../utils/backend_connection.dart';

class OfflineWrite {
  const OfflineWrite({
    required this.key,
    required this.userId,
    required this.table,
    required this.operation,
    required this.values,
    this.recordId,
  });

  final int key;
  final String userId;
  final String table;
  final String operation;
  final Map<String, dynamic> values;
  final String? recordId;
}

/// Device-local snapshots and a persistent, user-scoped write-ahead queue.
/// Remote Supabase remains authoritative; cached rows are reconciled as soon
/// as their queued writes are acknowledged by the server.
class OfflineDataStore {
  OfflineDataStore._();
  static final OfflineDataStore instance = OfflineDataStore._();

  static const _cacheName = 'worklog_row_snapshots';
  static const _queueName = 'worklog_pending_writes';
  static const _uuid = Uuid();
  final _cache = stringMapStoreFactory.store(_cacheName);
  final _queue = intMapStoreFactory.store(_queueName);
  final pendingWritesRevision = ValueNotifier<int>(0);
  Future<Database>? _databaseFuture;
  Future<void> _syncLock = Future.value();
  final Map<String, Set<void Function()>> _listeners = {};

  Future<Database> get _database =>
      _databaseFuture ??= openWorkLogLocalDatabase();

  String? userId(SupabaseClient client) => client.auth.currentUser?.id;

  String _cacheKey(String userId, String table, String query) =>
      '$userId/$table/$query';

  Stream<List<Map<String, dynamic>>> watchRows({
    required SupabaseClient client,
    required String table,
    required String queryKey,
    required Stream<List<Map<String, dynamic>>> remote,
    bool seedFromAll = false,
  }) {
    void Function()? notify;
    String? listenerKey;
    String? activeUser;
    var generation = 0;
    StreamSubscription<List<Map<String, dynamic>>>? remoteSub;
    StreamSubscription<RecordSnapshot<String, Map<String, Object?>>?>? localSub;
    StreamSubscription<AuthState>? authSub;
    var canceled = false;
    return Stream.multi((controller) {
      Future<void> emitCached(
        String user,
        String key,
        int sessionGeneration, {
        required bool remoteInitialized,
      }) async {
        final db = await _database;
        var snapshot = await _cache.record(key).getSnapshot(db);
        // A local-first write can arrive before this particular filtered
        // stream has emitted its first snapshot. In that case the writer has
        // a user/table-wide `all` cache; use it as a seed and apply the
        // stream's filter so new Gym entries appear immediately instead of
        // waiting on the network's first response.
        if (snapshot == null && seedFromAll && queryKey != 'all') {
          snapshot = await _cache
              .record(_cacheKey(user, table, 'all'))
              .getSnapshot(db);
        }
        if (canceled || sessionGeneration != generation) return;
        final rows = snapshot == null
            ? <Map<String, dynamic>>[]
            : _mapRows(snapshot.value['rows']);
        final visible = await _applyPending(user, table, queryKey, rows);
        if (canceled || sessionGeneration != generation) return;
        // An empty local snapshot is not authoritative: it may be an old
        // first-run cache while the signed-in user's server rows are loading.
        // Wait for the server's initial snapshot before showing an empty state.
        if (visible.isNotEmpty || remoteInitialized) controller.add(visible);
      }

      Future<void> startForUser(String? user) async {
        final sessionGeneration = ++generation;
        final oldListenerKey = listenerKey;
        final oldNotify = notify;
        notify = null;
        listenerKey = null;
        if (oldListenerKey != null) {
          _listeners[oldListenerKey]?.remove(oldNotify);
          if (_listeners[oldListenerKey]?.isEmpty ?? false) {
            _listeners.remove(oldListenerKey);
          }
        }
        final previousRemote = remoteSub;
        remoteSub = null;
        final previousLocal = localSub;
        localSub = null;
        await previousRemote?.cancel();
        await previousLocal?.cancel();
        if (canceled || sessionGeneration != generation) return;
        activeUser = user;
        if (user == null) {
          controller.add(<Map<String, dynamic>>[]);
          return;
        }

        final key = _cacheKey(user, table, queryKey);
        final currentListenerKey = '$user/$table';
        listenerKey = currentListenerKey;
        var remoteInitialized = false;
        final db = await _database;
        if (canceled || sessionGeneration != generation) return;
        localSub = _cache.record(key).onSnapshot(db).listen((_) {
          unawaited(emitCached(user, key, sessionGeneration,
              remoteInitialized: remoteInitialized));
        });
        notify = () => unawaited(emitCached(user, key, sessionGeneration,
            remoteInitialized: remoteInitialized));
        _listeners
            .putIfAbsent(currentListenerKey, () => <void Function()>{})
            .add(notify!);
        await emitCached(user, key, sessionGeneration,
            remoteInitialized: remoteInitialized);
        if (canceled || sessionGeneration != generation) return;
        remoteSub = remote.listen(
          (rows) async {
            final currentDb = await _database;
            if (canceled || sessionGeneration != generation) return;
            BackendConnection.instance.reportAvailable();
            remoteInitialized = true;
            await _cache.record(key).put(currentDb, {
              'user': user,
              'table': table,
              'rows': rows,
            });
            if (canceled || sessionGeneration != generation) return;
            controller.add(await _applyPending(user, table, queryKey, rows));
          },
          onError: (Object error, StackTrace stack) async {
            if (canceled || sessionGeneration != generation) return;
            if (isNetworkError(error)) {
              BackendConnection.instance.reportUnavailable();
            }
            final currentDb = await _database;
            final cached = await _cache.record(key).getSnapshot(currentDb);
            if (canceled || sessionGeneration != generation) return;
            final cachedRows = cached == null
                ? <Map<String, dynamic>>[]
                : _mapRows(cached.value['rows']);
            final pending =
                await _applyPending(user, table, queryKey, cachedRows);
            if (pending.isNotEmpty) {
              controller.add(pending);
            } else if (cachedRows.isNotEmpty) {
              controller.add(cachedRows);
            } else {
              controller.addError(error, stack);
            }
          },
        );
      }

      unawaited(startForUser(userId(client)));
      authSub = client.auth.onAuthStateChange.listen((state) {
        final nextUser = state.session?.user.id;
        if (nextUser != activeUser) unawaited(startForUser(nextUser));
      });
      controller.onCancel = () {
        canceled = true;
        if (notify != null && listenerKey != null) {
          _listeners[listenerKey!]?.remove(notify);
        }
        if (listenerKey != null && _listeners[listenerKey]?.isEmpty == true) {
          _listeners.remove(listenerKey);
        }
        unawaited(remoteSub?.cancel() ?? Future<void>.value());
        unawaited(localSub?.cancel() ?? Future<void>.value());
        unawaited(authSub?.cancel() ?? Future<void>.value());
      };
    });
  }

  Future<List<Map<String, dynamic>>> fetchRows({
    required SupabaseClient client,
    required String table,
    required String queryKey,
    required Future<List<Map<String, dynamic>>> Function() fetch,
    bool seedFromAll = false,
  }) async {
    final user = userId(client);
    if (user == null) return fetch();
    final key = _cacheKey(user, table, queryKey);
    final db = await _database;
    try {
      final rows = await fetch();
      BackendConnection.instance.reportAvailable();
      await _cache.record(key).put(db, {
        'user': user,
        'table': table,
        'rows': rows,
      });
      return await _applyPending(user, table, queryKey, rows);
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      BackendConnection.instance.reportUnavailable();
      var cached = await _cache.record(key).getSnapshot(db);
      if (cached == null && seedFromAll && queryKey != 'all') {
        cached =
            await _cache.record(_cacheKey(user, table, 'all')).getSnapshot(db);
      }
      if (cached == null) rethrow;
      return _applyPending(
          user, table, queryKey, _mapRows(cached.value['rows']));
    }
  }

  Future<Map<String, dynamic>?> fetchMap({
    required SupabaseClient client,
    required String cacheKey,
    required Future<Map<String, dynamic>?> Function() fetch,
  }) async {
    final user = userId(client);
    if (user == null) return fetch();
    final key = '$user/rpc/$cacheKey';
    final db = await _database;
    try {
      final value = await fetch();
      BackendConnection.instance.reportAvailable();
      if (value != null) {
        await _cache.record(key).put(db, {'user': user, 'value': value});
      }
      return value;
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      BackendConnection.instance.reportUnavailable();
      final cached = await _cache.record(key).getSnapshot(db);
      if (cached == null) rethrow;
      return Map<String, dynamic>.from(cached.value['value'] as Map);
    }
  }

  Future<String> insert(
      SupabaseClient client, String table, Map<String, dynamic> values,
      {String? id, bool localFirst = false}) async {
    final uid = userId(client);
    if (uid == null) throw StateError('Sign in to save changes.');
    final recordId = id ?? _newId();
    final row = <String, dynamic>{...values, 'id': recordId, 'user_id': uid};
    if (localFirst) {
      await _queueAndApply(client, uid, table, 'insert', row, recordId);
      return recordId;
    }
    var committedRow = row;
    try {
      if (table == 'projects') {
        // The server creates the public invoice token. Return it with the
        // insert so the newly-created project can show its copy-link action
        // without waiting for a Realtime event.
        final created =
            await client.from(table).insert(row).select('share_token').single();
        committedRow = {...row, ...Map<String, dynamic>.from(created)};
      } else if (table == 'income') {
        final created = await client.from(table).insert(row).select().single();
        committedRow = {...row, ...Map<String, dynamic>.from(created)};
      } else {
        await client.from(table).insert(row);
      }
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      await _enqueue(uid, table, 'insert', row, recordId);
    }
    await _applyToCachedRows(uid, table, 'insert', committedRow, recordId);
    _notify(uid, table);
    if (table == 'income') {
      unawaited(_refreshIncomeEffects(client, uid, committedRow));
    }
    return recordId;
  }

  Future<void> update(SupabaseClient client, String table, String id,
      Map<String, dynamic> values,
      {bool localFirst = false}) async {
    final uid = userId(client);
    if (uid == null) throw StateError('Sign in to save changes.');
    final row = <String, dynamic>{...values, 'id': id, 'user_id': uid};
    if (localFirst) {
      await _queueAndApply(client, uid, table, 'update', row, id);
      return;
    }
    var committedRow = row;
    try {
      if (table == 'income') {
        final updated = await client
            .from(table)
            .update(values)
            .eq('id', id)
            .select()
            .maybeSingle();
        if (updated == null) {
          throw StateError(
              'Income record was not found or could not be updated.');
        }
        committedRow = {...row, ...Map<String, dynamic>.from(updated)};
      } else {
        await client.from(table).update(values).eq('id', id);
      }
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      await _enqueue(uid, table, 'update', row, id);
    }
    await _applyToCachedRows(uid, table, 'update', committedRow, id);
    _notify(uid, table);
    if (table == 'income') {
      unawaited(_refreshIncomeEffects(client, uid, committedRow));
    }
  }

  Future<void> delete(SupabaseClient client, String table, String id,
      {bool localFirst = false}) async {
    final uid = userId(client);
    if (uid == null) throw StateError('Sign in to save changes.');
    var previousRow = await _cachedRow(uid, table, id) ?? const {};
    if (localFirst) {
      await _queueAndApply(client, uid, table, 'delete', previousRow, id);
      return;
    }
    try {
      if (table == 'income' && previousRow.isEmpty) {
        final existing =
            await client.from(table).select().eq('id', id).maybeSingle();
        if (existing != null) {
          previousRow = Map<String, dynamic>.from(existing);
        }
      }
      await client.from(table).delete().eq('id', id);
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      await _enqueue(uid, table, 'delete', previousRow, id);
    }
    await _applyToCachedRows(uid, table, 'delete', const {}, id);
    _notify(uid, table);
    if (table == 'income') {
      unawaited(_refreshIncomeEffects(client, uid, previousRow));
    }
  }

  Future<void> upsert(
      SupabaseClient client, String table, Map<String, dynamic> values,
      {required String conflictColumn, bool localFirst = false}) async {
    final uid = userId(client);
    if (uid == null) throw StateError('Sign in to save changes.');
    final row = <String, dynamic>{...values, 'user_id': uid};
    final id = row[conflictColumn]?.toString();
    if (localFirst) {
      await _queueAndApply(
          client, uid, table, 'upsert:$conflictColumn', row, id);
      return;
    }
    try {
      await client.from(table).upsert(row, onConflict: conflictColumn);
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      await _enqueue(uid, table, 'upsert:$conflictColumn', row, id);
    }
    await _applyToCachedRows(uid, table, 'upsert:$conflictColumn', row, id);
    _notify(uid, table);
  }

  Future<bool> syncPendingWrites(SupabaseClient client) async {
    final uid = userId(client);
    if (uid == null) return true;
    final previous = _syncLock;
    final completer = Completer<void>();
    _syncLock = completer.future;
    await previous;
    var synced = true;
    try {
      final db = await _database;
      final pending = await _queue.find(db,
          finder: Finder(
              filter: Filter.equals('userId', uid),
              sortOrders: [SortOrder('createdAt')]));
      for (final snapshot in pending) {
        final write = _decodeWrite(snapshot);
        try {
          switch (write.operation) {
            case 'insert':
              await client.from(write.table).upsert(write.values,
                  onConflict: 'id', ignoreDuplicates: true);
              break;
            case 'update':
              await client
                  .from(write.table)
                  .update(write.values
                    ..remove('id')
                    ..remove('user_id'))
                  .eq('id', write.recordId!);
              break;
            case 'delete':
              await client.from(write.table).delete().eq('id', write.recordId!);
              break;
            default:
              if (write.operation.startsWith('upsert:')) {
                await client.from(write.table).upsert(write.values,
                    onConflict: write.operation.substring('upsert:'.length));
              } else {
                throw StateError('Unsupported queued change');
              }
          }
          if (write.table == 'projects' &&
              write.operation == 'insert' &&
              write.recordId != null) {
            final savedProject = await client
                .from('projects')
                .select('share_token')
                .eq('id', write.recordId!)
                .maybeSingle();
            if (savedProject != null) {
              await _applyToCachedRows(
                uid,
                'projects',
                'update',
                {...write.values, ...Map<String, dynamic>.from(savedProject)},
                write.recordId,
              );
            }
          }
          if (write.table == 'income') {
            unawaited(_refreshIncomeEffects(client, uid, write.values));
          }
          await _queue.record(write.key).delete(db);
          pendingWritesRevision.value++;
          _notify(uid, write.table);
        } catch (error) {
          synced = false;
          if (isNetworkError(error)) {
            BackendConnection.instance.reportUnavailable();
          }
          if (!isNetworkError(error)) {
            await _queue.record(write.key).update(db, {
              'lastError': 'Sync needs attention',
              'attempts': ((snapshot.value['attempts'] as int?) ?? 0) + 1,
            });
          }
          break;
        }
      }
      if (synced) BackendConnection.instance.reportAvailable();
    } finally {
      completer.complete();
    }
    return synced;
  }

  Future<int> pendingCount(SupabaseClient client) async {
    final uid = userId(client);
    if (uid == null) return 0;
    final db = await _database;
    return _queue.count(db, filter: Filter.equals('userId', uid));
  }

  Future<void> _enqueue(String user, String table, String operation,
      Map<String, dynamic> values, String? id) async {
    final db = await _database;
    await _queue.add(db, {
      'userId': user,
      'table': table,
      'operation': operation,
      'values': values,
      'recordId': id,
      'createdAt': DateTime.now().microsecondsSinceEpoch,
      'attempts': 0,
    });
    pendingWritesRevision.value++;
  }

  Future<void> _queueAndApply(SupabaseClient client, String user, String table,
      String operation, Map<String, dynamic> values, String? id) async {
    await _enqueue(user, table, operation, values, id);
    await _applyToCachedRows(user, table, operation, values, id);
    _notify(user, table);
    // Gym writes are visible immediately; the persistent queue retries in the
    // background. Inserts are idempotent by id, so startup sync is safe too.
    unawaited(syncPendingWrites(client));
  }

  Future<void> _applyToCachedRows(String user, String table, String operation,
      Map<String, dynamic> values, String? id) async {
    final db = await _database;
    // Batch all snapshots into one local commit. On slower phones, updating
    // many watched filtered caches sequentially made an offline-first save
    // appear to hang even though it was not waiting for the network.
    await db.transaction((transaction) async {
      final snapshots = await _cache.find(transaction,
          finder: Finder(
              filter: Filter.custom((record) =>
                  record.key.toString().startsWith('$user/$table/'))));
      if (snapshots.isEmpty &&
          (operation == 'insert' || operation.startsWith('upsert:'))) {
        await _cache.record(_cacheKey(user, table, 'all')).put(transaction, {
          'user': user,
          'table': table,
          'rows': [values],
        });
        return;
      }
      for (final snapshot in snapshots) {
        final record = _cache.record(snapshot.key);
        final queryKey =
            snapshot.key.toString().substring('$user/$table/'.length);
        final rows = _mapRows(snapshot.value['rows']);
        final column = operation.startsWith('upsert:')
            ? operation.substring('upsert:'.length)
            : 'id';
        final index = rows.indexWhere((row) => row[column]?.toString() == id);
        if (operation == 'delete') {
          if (index >= 0) rows.removeAt(index);
        } else if ((operation == 'insert' || operation.startsWith('upsert:')) &&
            index < 0) {
          if (_filterRowsForQuery(queryKey, [values]).isNotEmpty) {
            rows.add(values);
          }
        } else if (index >= 0) {
          final updated = {...rows[index], ...values};
          if (_filterRowsForQuery(queryKey, [updated]).isEmpty) {
            rows.removeAt(index);
          } else {
            rows[index] = updated;
          }
        }
        await record.update(transaction, {'rows': rows});
      }
    });
  }

  Future<Map<String, dynamic>?> _cachedRow(
      String user, String table, String id) async {
    final db = await _database;
    final snapshots = await _cache.find(
      db,
      finder: Finder(
        filter: Filter.custom(
          (record) => record.key.toString().startsWith('$user/$table/'),
        ),
      ),
    );
    for (final snapshot in snapshots) {
      for (final row in _mapRows(snapshot.value['rows'])) {
        if (row['id']?.toString() == id) return row;
      }
    }
    return null;
  }

  Future<void> _refreshIncomeEffects(
    SupabaseClient client,
    String user,
    Map<String, dynamic> income,
  ) async {
    final projectId = income['project_id']?.toString();
    final clientId = income['client_id']?.toString();
    for (final (table, id) in <(String, String?)>[
      ('projects', projectId),
      ('clients', clientId),
    ]) {
      if (id == null || id.isEmpty) continue;
      try {
        final row =
            await client.from(table).select().eq('id', id).maybeSingle();
        if (row == null) continue;
        BackendConnection.instance.reportAvailable();
        await _applyToCachedRows(
          user,
          table,
          'update',
          Map<String, dynamic>.from(row),
          id,
        );
        _notify(user, table);
      } catch (error) {
        if (isNetworkError(error)) {
          BackendConnection.instance.reportUnavailable();
        } else {
          debugPrint(
              'Could not refresh linked $table data after an income save.');
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _applyPending(String user, String table,
      String queryKey, List<Map<String, dynamic>> source) async {
    final db = await _database;
    final pending = await _queue.find(db,
        finder: Finder(
            filter: Filter.and([
              Filter.equals('userId', user),
              Filter.equals('table', table),
            ]),
            sortOrders: [SortOrder('createdAt')]));
    final rows = source.map((row) => Map<String, dynamic>.from(row)).toList();
    for (final snapshot in pending) {
      final write = _decodeWrite(snapshot);
      final id = write.recordId;
      final column = write.operation.startsWith('upsert:')
          ? write.operation.substring('upsert:'.length)
          : 'id';
      final index = rows.indexWhere((row) => row[column]?.toString() == id);
      if (write.operation == 'delete') {
        if (index >= 0) rows.removeAt(index);
      } else if ((write.operation == 'insert' ||
              write.operation.startsWith('upsert:')) &&
          index < 0) {
        rows.add(write.values);
      } else if (index >= 0) {
        rows[index] = {...rows[index], ...write.values};
      }
    }
    return _filterRowsForQuery(queryKey, rows);
  }

  List<Map<String, dynamic>> _filterRowsForQuery(
      String queryKey, List<Map<String, dynamic>> rows) {
    if (queryKey == 'all' ||
        queryKey.startsWith('all-') ||
        queryKey.startsWith('recent:') ||
        queryKey.startsWith('limit:')) {
      return rows;
    }
    final parts = queryKey.split(':');
    if (parts.length < 2) return rows;
    final value = parts[1];
    switch (parts.first) {
      case 'id':
        return rows.where((row) => row['id']?.toString() == value).toList();
      case 'client':
        return rows
            .where((row) => row['client_id']?.toString() == value)
            .toList();
      case 'routine':
        return rows
            .where((row) => row['routine_id']?.toString() == value)
            .toList();
      case 'workout':
        return rows
            .where((row) => row['workout_id']?.toString() == value)
            .toList();
      case 'exercise':
        return rows
            .where((row) => row['exercise_id']?.toString() == value)
            .toList();
      case 'date':
        return rows
            .where((row) =>
                row['date_time']?.toString().startsWith(value) ?? false)
            .toList();
      case 'water-date':
        return rows
            .where((row) => row['date']?.toString().startsWith(value) ?? false)
            .toList();
      default:
        return rows;
    }
  }

  void _notify(String user, String table) {
    for (final listener
        in List<void Function()>.from(_listeners['$user/$table'] ?? const {})) {
      listener();
    }
  }

  OfflineWrite _decodeWrite(RecordSnapshot<int, Map<String, Object?>> row) =>
      OfflineWrite(
        key: row.key,
        userId: row.value['userId'] as String,
        table: row.value['table'] as String,
        operation: row.value['operation'] as String,
        values: Map<String, dynamic>.from(row.value['values'] as Map),
        recordId: row.value['recordId'] as String?,
      );

  List<Map<String, dynamic>> _mapRows(Object? value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  String _newId() => _uuid.v4();

  bool isNetworkError(Object error) =>
      error is TimeoutException ||
      error is http.ClientException ||
      error.toString().toLowerCase().contains('socketexception') ||
      error.toString().toLowerCase().contains('failed to fetch') ||
      error.toString().toLowerCase().contains('network is unreachable') ||
      error.toString().toLowerCase().contains('connection refused') ||
      error.toString().toLowerCase().contains('connection reset') ||
      error.toString().toLowerCase().contains('timed out') ||
      (error is PostgrestException &&
          (error.code == '08000' ||
              error.code == '08003' ||
              error.code == '08006' ||
              error.message.toLowerCase().contains('fetch')));
}
