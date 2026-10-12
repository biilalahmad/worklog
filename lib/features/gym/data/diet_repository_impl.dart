import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/offline_data_store.dart';

import '../domain/diet_target.dart';
import '../domain/food.dart';
import '../domain/gym_repositories.dart';
import '../domain/meal_entry.dart';
import '../domain/water_log.dart';
import '../../../core/utils/date_keys.dart';

class DietRepositoryImpl implements DietRepository {
  final SupabaseClient _client;
  DietRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<List<Food>> watchFoods() {
    return OfflineDataStore.instance
        .watchRows(
          client: _client,
          table: 'foods',
          queryKey: 'all',
          seedFromAll: true,
          remote:
              _client.from('foods').stream(primaryKey: ['id']).order('name'),
        )
        .map((rows) => rows.map(Food.fromMap).toList());
  }

  @override
  Future<String> addFood(Food food) async {
    return OfflineDataStore.instance.insert(
        _client, 'foods', food.toWritableMap(),
        id: food.id.isEmpty ? null : food.id);
  }

  @override
  Stream<List<MealEntry>> watchMealsForDate(DateTime date) {
    final start = DateKeys.startOfDay(date);
    final end = DateKeys.endOfDay(date);
    return OfflineDataStore.instance
        .watchRows(
          client: _client,
          table: 'meal_entries',
          queryKey: 'all',
          seedFromAll: true,
          remote: _client
              .from('meal_entries')
              .stream(primaryKey: ['id']).order('date'),
        )
        .map((rows) => rows
            .map(MealEntry.fromMap)
            .where((m) => !m.date.isBefore(start) && !m.date.isAfter(end))
            .toList());
  }

  @override
  Future<String> addMeal(MealEntry meal) async {
    return OfflineDataStore.instance.insert(
        _client, 'meal_entries', meal.toWritableMap(),
        id: meal.id.isEmpty ? null : meal.id);
  }

  @override
  Future<void> deleteMeal(String id) {
    return OfflineDataStore.instance.delete(_client, 'meal_entries', id);
  }

  @override
  Stream<DietTarget> watchDietTarget() {
    // RLS ensures this only ever returns the current user's own row.
    return OfflineDataStore.instance
        .watchRows(
          client: _client,
          table: 'diet_targets',
          queryKey: 'user',
          seedFromAll: true,
          remote: _client.from('diet_targets').stream(primaryKey: ['id']),
        )
        .map((rows) =>
            rows.isEmpty ? const DietTarget() : DietTarget.fromMap(rows.first));
  }

  @override
  Future<void> saveDietTarget(DietTarget target) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in to save your nutrition targets.');
    }
    final map = target.toWritableMap();
    map['user_id'] = userId;
    await OfflineDataStore.instance
        .upsert(_client, 'diet_targets', map, conflictColumn: 'user_id');
  }

  @override
  Future<List<WaterLog>> getWaterLogsForDate(DateTime date) async {
    final day = DateKeys.day(date);
    final rows = await OfflineDataStore.instance.fetchRows(
      client: _client,
      table: 'water_logs',
      queryKey: 'water-date:$day',
      seedFromAll: true,
      fetch: () async => await _client
          .from('water_logs')
          .select()
          .eq('date', day)
          .order('created_at', ascending: false),
    );
    return rows.map((row) => WaterLog.fromMap(row)).toList();
  }

  @override
  Future<String> addWaterLog(int milliliters, DateTime date) async {
    return OfflineDataStore.instance.insert(
      _client,
      'water_logs',
      WaterLog(id: '', date: date, milliliters: milliliters).toWritableMap(),
    );
  }

  @override
  Future<void> deleteWaterLog(String id) async {
    await OfflineDataStore.instance.delete(_client, 'water_logs', id);
  }
}
