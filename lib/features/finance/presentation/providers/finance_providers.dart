import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../work/presentation/providers/work_providers.dart'
    show DateRange;
import '../../data/finance_repository_impl.dart';
import '../../domain/expense.dart';
import '../../domain/finance_repository.dart';
import '../../domain/income.dart';

final financeRepositoryProvider =
    Provider<FinanceRepository>((ref) => FinanceRepositoryImpl());

final financeRecentToggleProvider =
    StateProvider<bool>((ref) => true); // true = Income, false = Spending

/// Finance activity cards are derived from transactions, not stored as
/// separate notification rows. This per-user tombstone keeps a dismissed card
/// out of the feed across refreshes/devices while leaving its transaction
/// intact for totals, history, and reports. Removing the tombstone would make
/// the same transaction appear in the feed again.
final deletedFinanceActivityProvider = StateNotifierProvider.family<
    DeletedFinanceActivityNotifier, Set<String>, String>(
  (ref, userId) => DeletedFinanceActivityNotifier(userId),
);

class DeletedFinanceActivityNotifier extends StateNotifier<Set<String>> {
  DeletedFinanceActivityNotifier(this.userId) : super(<String>{}) {
    unawaited(_load());
  }

  final String userId;
  bool isLoaded = false;
  SupabaseClient? get _remoteClient {
    try {
      final client = Supabase.instance.client;
      return client.auth.currentUser?.id == userId ? client : null;
    } catch (_) {
      return null;
    }
  }

  String get _storageKey => 'worklog.finance.deleted_activity.$userId';
  String get _legacyStorageKey => 'worklog.finance.hidden_activity.$userId';
  Future<void> _writeQueue = Future<void>.value();

  Future<void> _load() => _enqueue(() async {
        try {
          final preferences = await SharedPreferences.getInstance();
          final saved = preferences.getStringList(_storageKey);
          final legacy = preferences.getStringList(_legacyStorageKey);
          final localDismissals = {...?saved, ...?legacy};
          var allDeleted = {...state, ...localDismissals};
          var remoteReconciled = false;

          final client = _remoteClient;
          if (client != null) {
            try {
              final rows = await client
                  .from('finance_activity_dismissals')
                  .select('activity_type, transaction_id, is_dismissed')
                  .eq('user_id', userId);
              final serverDismissals = <String>{};
              final knownKeys = <String>{};
              for (final row in rows) {
                final key = '${row['activity_type']}:${row['transaction_id']}';
                knownKeys.add(key);
                if (row['is_dismissed'] == true) serverDismissals.add(key);
              }

              // Migrate old device-local dismissals once. Server rows (including
              // restored false values) are authoritative on later logins/devices.
              final legacyKeys = localDismissals.difference(knownKeys);
              for (final key in legacyKeys) {
                await _setRemoteDismissed(client, key, dismissed: true);
              }
              allDeleted = {...serverDismissals, ...legacyKeys};
              remoteReconciled = true;
            } catch (_) {
              // Retain this device's cached state while offline; a successful
              // later login will reconcile it against the server.
            }
          }

          if (remoteReconciled ||
              (allDeleted.isNotEmpty && (saved == null || legacy != null))) {
            await preferences.setStringList(
              _storageKey,
              allDeleted.toList(),
            );
            await preferences.remove(_legacyStorageKey);
          }
          if (mounted && allDeleted != state) state = allDeleted;
        } finally {
          // Do not briefly show dismissed transaction activity while the
          // saved per-user dismissal state is still being restored.
          if (mounted) {
            isLoaded = true;
            state = {...state};
          }
        }
      });

  Future<void> delete(String id) => _enqueue(() async {
        final preferences = await SharedPreferences.getInstance();
        final client = _remoteClient;
        if (client != null) {
          await _setRemoteDismissed(client, id, dismissed: true);
        }
        final updated = {
          ...state,
          ...?preferences.getStringList(_storageKey),
          id
        };
        final saved = await preferences.setStringList(
          _storageKey,
          updated.toList(),
        );
        if (!saved) throw StateError('Could not save deleted activity');
        if (mounted) state = updated;
      });

  /// Persist the delete before the swipe animation finishes, but defer the
  /// feed update until Dismissible calls [markDeleted] on dismissal.
  Future<void> stageDelete(String id) => _enqueue(() async {
        final preferences = await SharedPreferences.getInstance();
        final client = _remoteClient;
        if (client != null) {
          await _setRemoteDismissed(client, id, dismissed: true);
        }
        final updated = {
          ...state,
          ...?preferences.getStringList(_storageKey),
          id
        };
        final saved = await preferences.setStringList(
          _storageKey,
          updated.toList(),
        );
        if (!saved) throw StateError('Could not save deleted activity');
      });

  void markDeleted(String id) {
    if (mounted && !state.contains(id)) state = {...state, id};
  }

  /// Reverses the optimistic feed update if persisting a dismissal fails.
  Future<void> rollbackStage(String id) => _enqueue(() async {
        final preferences = await SharedPreferences.getInstance();
        final updated = {
          ...state,
          ...?preferences.getStringList(_storageKey),
        }..remove(id);
        await preferences.setStringList(_storageKey, updated.toList());
        if (mounted) state = updated;
        final client = _remoteClient;
        if (client != null) {
          try {
            await _setRemoteDismissed(client, id, dismissed: false);
          } catch (_) {
            // The original write may not have reached Supabase. The local
            // feed is restored either way and the transaction is untouched.
          }
        }
      });

  Future<void> restore(String id) => _enqueue(() async {
        final preferences = await SharedPreferences.getInstance();
        final client = _remoteClient;
        if (client != null) {
          await _setRemoteDismissed(client, id, dismissed: false);
        }
        final updated = {
          ...state,
          ...?preferences.getStringList(_storageKey),
        }..remove(id);
        final saved = await preferences.setStringList(
          _storageKey,
          updated.toList(),
        );
        if (!saved) throw StateError('Could not restore deleted activity');
        if (mounted) state = updated;
      });

  Future<void> _setRemoteDismissed(
    SupabaseClient client,
    String key, {
    required bool dismissed,
  }) async {
    final separator = key.indexOf(':');
    if (separator <= 0 || separator == key.length - 1) {
      throw const FormatException('Invalid finance activity key');
    }
    final type = key.substring(0, separator);
    final transactionId = key.substring(separator + 1);
    if (!const {'income', 'expense'}.contains(type)) {
      throw const FormatException('Invalid finance activity type');
    }
    await client.from('finance_activity_dismissals').upsert(
      {
        'user_id': userId,
        'activity_type': type,
        'transaction_id': transactionId,
        'is_dismissed': dismissed,
      },
      onConflict: 'user_id,activity_type,transaction_id',
    );
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final queued = _writeQueue.then((_) => operation());
    _writeQueue = queued.catchError((Object _) {});
    return queued;
  }
}

final incomeForRangeProvider =
    StreamProvider.autoDispose.family<List<Income>, DateRange>((ref, range) {
  return ref
      .watch(financeRepositoryProvider)
      .watchIncomeForRange(range.start, range.end);
});

final incomeForClientProvider =
    StreamProvider.autoDispose.family<List<Income>, String>((ref, clientId) {
  return ref.watch(financeRepositoryProvider).watchIncomeForClient(clientId);
});

final expensesForRangeProvider =
    StreamProvider.autoDispose.family<List<Expense>, DateRange>((ref, range) {
  return ref
      .watch(financeRepositoryProvider)
      .watchExpensesForRange(range.start, range.end);
});
