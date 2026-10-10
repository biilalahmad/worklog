import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/offline_data_store.dart';

import '../domain/body_stat.dart';
import '../domain/gym_repositories.dart';

class BodyStatRepositoryImpl implements BodyStatRepository {
  final SupabaseClient _client;
  BodyStatRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<List<BodyStat>> watchBodyStats({int limit = 200}) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'body_stats',
            queryKey: 'limit:$limit',
            seedFromAll: true,
            remote: _client
                .from('body_stats')
                .stream(primaryKey: ['id'])
                .order('date', ascending: false)
                .limit(limit))
        .map((rows) => rows.map(BodyStat.fromMap).toList());
  }

  @override
  Future<String> addBodyStat(BodyStat stat) async {
    return OfflineDataStore.instance.insert(
        _client, 'body_stats', stat.toWritableMap(),
        id: stat.id.isEmpty ? null : stat.id, localFirst: true);
  }

  @override
  Future<void> deleteBodyStat(String id) {
    return OfflineDataStore.instance
        .delete(_client, 'body_stats', id, localFirst: true);
  }
}
