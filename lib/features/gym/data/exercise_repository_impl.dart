import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/offline_data_store.dart';

import '../domain/exercise.dart';
import '../domain/gym_repositories.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  final SupabaseClient _client;
  ExerciseRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<List<Exercise>> watchExercises() {
    return OfflineDataStore.instance
        .watchRows(
          client: _client,
          table: 'exercises',
          queryKey: 'all',
          seedFromAll: true,
          remote: _client
              .from('exercises')
              .stream(primaryKey: ['id']).order('name'),
        )
        .map((rows) => rows.map(Exercise.fromMap).toList());
  }

  @override
  Future<String> addExercise(Exercise exercise) async {
    return OfflineDataStore.instance.insert(
      _client,
      'exercises',
      exercise.toWritableMap(),
      id: exercise.id.isEmpty ? null : exercise.id,
      localFirst: true,
    );
  }

  @override
  Future<String> findOrCreateByName(
    String name, {
    MuscleGroup muscleGroup = MuscleGroup.other,
    String equipment = '',
  }) async {
    final trimmed = name.trim();
    try {
      final existing = await _client
          .from('exercises')
          .select('id')
          .ilike('name', trimmed)
          .limit(1)
          .maybeSingle();
      if (existing != null) return existing['id'] as String;
    } catch (error) {
      if (!OfflineDataStore.instance.isNetworkError(error)) rethrow;
    }
    return addExercise(Exercise(
      id: '',
      name: trimmed,
      muscleGroup: muscleGroup,
      equipment: equipment,
    ));
  }
}
