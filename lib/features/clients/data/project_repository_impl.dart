import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/offline_data_store.dart';

import '../domain/project.dart';
import '../domain/project_repository.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final SupabaseClient _client;

  ProjectRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<List<Project>> watchProjectsForClient(String clientId) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'projects',
            queryKey: 'client:$clientId',
            remote: _client
                .from('projects')
                .stream(primaryKey: ['id'])
                .eq('client_id', clientId)
                .order('created_at', ascending: false))
        .map((rows) => rows.map(Project.fromMap).toList());
  }

  @override
  Stream<Project?> watchProject(String projectId) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'projects',
            queryKey: 'id:$projectId',
            remote: _client
                .from('projects')
                .stream(primaryKey: ['id']).eq('id', projectId))
        .map((rows) => rows.isEmpty ? null : Project.fromMap(rows.first));
  }

  @override
  Future<String> addProject(Project project) async {
    final map = project.toWritableMap();
    map['amount_paid'] = 0;
    map['amount_remaining'] = project.totalAmountMinor;
    map['status'] = 'unpaid';
    return OfflineDataStore.instance.insert(_client, 'projects', map,
        id: project.id.isEmpty ? null : project.id);
  }

  @override
  Future<void> updateProject(Project project) {
    // Only title/dueDate/totalAmount are user-editable after creation;
    // amountPaid/amountRemaining/status stay trigger-owned.
    return OfflineDataStore.instance.update(_client, 'projects', project.id, {
      'title': project.title,
      'total_amount': project.totalAmountMinor,
      'due_date': project.dueDate?.toIso8601String(),
    });
  }

  @override
  Future<void> deleteProject(String projectId) {
    return OfflineDataStore.instance.delete(_client, 'projects', projectId);
  }

  @override
  Future<List<OverdueProject>> getNewlyOverdueProjects() async {
    final rows =
        await _client.rpc('get_newly_overdue_projects') as List<dynamic>;
    return rows
        .map((r) => OverdueProject.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markOverdueNotified(String projectId) {
    return _client
        .rpc('mark_overdue_notified', params: {'p_project_id': projectId});
  }
}
