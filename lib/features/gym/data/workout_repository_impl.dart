import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/offline_data_store.dart';

import '../domain/gym_repositories.dart';
import '../domain/workout.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final SupabaseClient _client;
  WorkoutRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<List<Workout>> watchRecentWorkouts({int limit = 30}) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'workouts',
            queryKey: 'recent:$limit',
            seedFromAll: true,
            remote: _client
                .from('workouts')
                .stream(primaryKey: ['id'])
                .order('date', ascending: false)
                .limit(limit))
        .map((rows) => rows.map((r) => Workout.fromMap(r)).toList());
  }

  @override
  Stream<List<Workout>> watchWorkoutsForRange(DateTime start, DateTime end) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'workouts',
            queryKey: 'all',
            seedFromAll: true,
            remote: _client
                .from('workouts')
                .stream(primaryKey: ['id']).order('date', ascending: false))
        .map((rows) => rows
            .map((r) => Workout.fromMap(r))
            .where((w) => !w.date.isBefore(start) && !w.date.isAfter(end))
            .toList());
  }

  @override
  Stream<Workout?> watchWorkout(String workoutId) {
    late final StreamController<Workout?> controller;
    final subs = <StreamSubscription>[];
    var active = true;

    Future<void> refresh() async {
      try {
        final rows = await OfflineDataStore.instance.fetchRows(
          client: _client,
          table: 'workouts',
          queryKey: 'id:$workoutId',
          fetch: () async {
            final row = await _client
                .from('workouts')
                .select()
                .eq('id', workoutId)
                .maybeSingle();
            return row == null ? <Map<String, dynamic>>[] : [row];
          },
        );
        if (!active || !controller.hasListener) return;
        if (rows.isEmpty) {
          controller.add(null);
          return;
        }
        final setsRows = await OfflineDataStore.instance.fetchRows(
          client: _client,
          table: 'workout_sets',
          queryKey: 'workout:$workoutId',
          fetch: () async => await _client
              .from('workout_sets')
              .select()
              .eq('workout_id', workoutId)
              .order('set_number'),
        );
        final sets = setsRows.map(WorkoutSet.fromMap).toList();
        if (active && controller.hasListener) {
          controller.add(Workout.fromMap(rows.first, sets: sets));
        }
      } catch (error, stack) {
        if (active && controller.hasListener) controller.addError(error, stack);
      }
    }

    controller = StreamController<Workout?>(
      onListen: () {
        refresh();
        subs.add(_client
            .from('workouts')
            .stream(primaryKey: ['id'])
            .eq('id', workoutId)
            .listen((_) => refresh(), onError: (Object _, StackTrace __) {}));
        subs.add(_client
            .from('workout_sets')
            .stream(primaryKey: ['id'])
            .eq('workout_id', workoutId)
            .listen((_) => refresh(), onError: (Object _, StackTrace __) {}));
      },
      onCancel: () {
        active = false;
        for (final s in subs) {
          unawaited(s.cancel());
        }
      },
    );
    return controller.stream;
  }

  @override
  Future<String> addWorkout(Workout workout) async {
    return OfflineDataStore.instance.insert(
        _client, 'workouts', workout.toWritableMap(),
        id: workout.id.isEmpty ? null : workout.id);
  }

  @override
  Future<void> updateWorkout(Workout workout) {
    return OfflineDataStore.instance
        .update(_client, 'workouts', workout.id, workout.toWritableMap());
  }

  @override
  Future<void> deleteWorkout(String workoutId) {
    return OfflineDataStore.instance.delete(_client, 'workouts', workoutId);
  }

  @override
  Future<void> discardExpiredEmptyWorkouts() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final stale = await _client
        .from('workouts')
        .select('id')
        .isFilter('completed_at', null)
        .lt('date', cutoff.toIso8601String());
    for (final row in stale) {
      final id = row['id'] as String;
      try {
        final sets = await OfflineDataStore.instance.fetchRows(
          client: _client,
          table: 'workout_sets',
          queryKey: 'workout:$id',
          fetch: () async => await _client
              .from('workout_sets')
              .select('id')
              .eq('workout_id', id),
        );
        if (sets.isEmpty) await deleteWorkout(id);
      } catch (_) {
        // If set state cannot be confirmed, preserve the workout for resume.
      }
    }
  }

  @override
  Future<String> addSet(WorkoutSet set) async {
    return OfflineDataStore.instance.insert(
        _client, 'workout_sets', set.toWritableMap(),
        id: set.id.isEmpty ? null : set.id);
  }

  @override
  Future<void> updateSet(WorkoutSet set) {
    return OfflineDataStore.instance
        .update(_client, 'workout_sets', set.id, set.toWritableMap());
  }

  @override
  Future<void> deleteSet(String setId) {
    return OfflineDataStore.instance.delete(_client, 'workout_sets', setId);
  }

  @override
  Future<List<WorkoutSet>> lastSetsForExercise(String exerciseId,
      {int limit = 5}) async {
    final rows = await OfflineDataStore.instance.fetchRows(
      client: _client,
      table: 'workout_sets',
      queryKey: 'exercise:$exerciseId:$limit',
      fetch: () async => await _client
          .from('workout_sets')
          .select()
          .eq('exercise_id', exerciseId)
          .order('created_at', ascending: false)
          .limit(limit),
    );
    return rows.map(WorkoutSet.fromMap).toList();
  }

  @override
  Future<double?> personalRecord(String exerciseId) async {
    final result = await _client
        .rpc('get_exercise_pr', params: {'p_exercise_id': exerciseId});
    if (result == null) return null;
    return (result as num).toDouble();
  }
}
