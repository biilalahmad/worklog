import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/offline_data_store.dart';

import '../domain/gym_repositories.dart';
import '../domain/workout_routine.dart';

class RoutineRepositoryImpl implements RoutineRepository {
  final SupabaseClient _client;
  RoutineRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<List<WorkoutRoutine>> watchRoutines() {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'workout_routines',
            queryKey: 'all',
            seedFromAll: true,
            remote: _client.from('workout_routines').stream(
                primaryKey: ['id']).order('created_at', ascending: false))
        .map((rows) => rows.map(WorkoutRoutine.fromMap).toList());
  }

  @override
  Stream<List<RoutineExercise>> watchRoutineExercises(String routineId) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'routine_exercises',
            queryKey: 'routine:$routineId',
            seedFromAll: true,
            remote: _client
                .from('routine_exercises')
                .stream(primaryKey: ['id'])
                .eq('routine_id', routineId)
                .order('order_index'))
        .map((rows) => rows
            .where((row) => row['routine_id'] == routineId)
            .map(RoutineExercise.fromMap)
            .toList());
  }

  @override
  Future<String> addRoutine(WorkoutRoutine routine) async {
    return OfflineDataStore.instance.insert(
        _client, 'workout_routines', routine.toWritableMap(),
        id: routine.id.isEmpty ? null : routine.id, localFirst: true);
  }

  @override
  Future<void> deleteRoutine(String routineId) {
    return OfflineDataStore.instance
        .delete(_client, 'workout_routines', routineId, localFirst: true);
  }

  @override
  Future<void> addRoutineExercise(RoutineExercise re) {
    return OfflineDataStore.instance
        .insert(_client, 'routine_exercises', re.toWritableMap(),
            id: re.id.isEmpty ? null : re.id, localFirst: true)
        .then((_) {});
  }

  @override
  Future<void> deleteRoutineExercise(String id) {
    return OfflineDataStore.instance
        .delete(_client, 'routine_exercises', id, localFirst: true);
  }
}
