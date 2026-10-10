import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/offline_data_store.dart';
import '../domain/gym_repositories.dart';
import '../domain/gym_stats.dart';

class GymStatsRepositoryImpl implements GymStatsRepository {
  final SupabaseClient _client;
  GymStatsRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<GymStats> watchGymStats(DateTime start, DateTime end) {
    late final StreamController<GymStats> controller;
    final subs = <StreamSubscription>[];
    var active = true;

    Future<void> refresh() async {
      try {
        final result = await OfflineDataStore.instance.fetchMap(
          client: _client,
          cacheKey:
              'gym-stats:${start.toIso8601String()}:${end.toIso8601String()}',
          fetch: () async {
            final result = await _client.rpc('get_gym_stats', params: {
              'p_start': start.toIso8601String(),
              'p_end': end.toIso8601String(),
            });
            return result == null
                ? null
                : Map<String, dynamic>.from(result as Map);
          },
        );
        if (active && controller.hasListener) {
          controller.add(GymStats.fromMap(result));
        }
      } catch (error, stack) {
        if (active && controller.hasListener) controller.addError(error, stack);
      }
    }

    controller = StreamController<GymStats>(
      onListen: () {
        refresh();
        subs.add(_client.from('workouts').stream(primaryKey: ['id']).listen(
            (_) => refresh(),
            onError: (Object _, StackTrace __) {}));
        subs.add(_client.from('workout_sets').stream(primaryKey: ['id']).listen(
            (_) => refresh(),
            onError: (Object _, StackTrace __) {}));
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
}
