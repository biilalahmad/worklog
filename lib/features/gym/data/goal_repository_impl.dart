import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/offline_data_store.dart';

import '../domain/gym_goal.dart';
import '../domain/gym_repositories.dart';

class GoalRepositoryImpl implements GoalRepository {
  final SupabaseClient _client;
  GoalRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<List<GymGoal>> watchGoals() {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'gym_goals',
            queryKey: 'all',
            seedFromAll: true,
            remote: _client.from('gym_goals').stream(
                primaryKey: ['id']).order('created_at', ascending: false))
        .map((rows) => rows.map(GymGoal.fromMap).toList());
  }

  @override
  Future<String> addGoal(GymGoal goal) async {
    return OfflineDataStore.instance.insert(
        _client, 'gym_goals', goal.toWritableMap(),
        id: goal.id.isEmpty ? null : goal.id, localFirst: true);
  }

  @override
  Future<void> updateGoal(GymGoal goal) {
    return OfflineDataStore.instance.update(
        _client, 'gym_goals', goal.id, goal.toWritableMap(),
        localFirst: true);
  }

  @override
  Future<void> deleteGoal(String id) {
    return OfflineDataStore.instance
        .delete(_client, 'gym_goals', id, localFirst: true);
  }

  @override
  Future<void> setAchieved(String id, bool achieved) {
    return OfflineDataStore.instance.update(
      _client,
      'gym_goals',
      id,
      {
        'achieved': achieved,
        'achieved_at': achieved ? DateTime.now().toIso8601String() : null,
      },
      localFirst: true,
    );
  }
}
