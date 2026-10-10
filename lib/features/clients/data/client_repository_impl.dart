import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/offline_data_store.dart';

import '../domain/client.dart';
import '../domain/client_repository.dart';

class ClientRepositoryImpl implements ClientRepository {
  final SupabaseClient _client;

  ClientRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<List<Client>> watchClients() {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'clients',
            queryKey: 'all',
            remote: _client
                .from('clients')
                .stream(primaryKey: ['id']).order('name'))
        .map((rows) => rows.map(Client.fromMap).toList());
  }

  @override
  Stream<Client?> watchClient(String clientId) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'clients',
            queryKey: 'id:$clientId',
            remote: _client
                .from('clients')
                .stream(primaryKey: ['id']).eq('id', clientId))
        .map((rows) => rows.isEmpty ? null : Client.fromMap(rows.first));
  }

  @override
  Future<Client?> getClient(String clientId) async {
    final rows = await OfflineDataStore.instance.fetchRows(
      client: _client,
      table: 'clients',
      queryKey: 'id:$clientId',
      fetch: () async {
        final row = await _client
            .from('clients')
            .select()
            .eq('id', clientId)
            .maybeSingle();
        return row == null ? <Map<String, dynamic>>[] : [row];
      },
    );
    return rows.isEmpty ? null : Client.fromMap(rows.first);
  }

  @override
  Future<String> addClient(Client client) async {
    return OfflineDataStore.instance.insert(
        _client, 'clients', client.toWritableMap(),
        id: client.id.isEmpty ? null : client.id);
  }

  @override
  Future<void> updateClient(Client client) {
    return OfflineDataStore.instance
        .update(_client, 'clients', client.id, client.toWritableMap());
  }

  @override
  Future<void> deleteClient(String clientId) {
    return OfflineDataStore.instance.delete(_client, 'clients', clientId);
  }

  @override
  Future<int> generateDueRetainerInvoices() async {
    final result = await _client.rpc('generate_due_retainer_invoices');
    return (result as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<Client>> getAllClients() async {
    final rows = await OfflineDataStore.instance.fetchRows(
      client: _client,
      table: 'clients',
      queryKey: 'all',
      fetch: () async => await _client.from('clients').select().order('name'),
    );
    return rows.map(Client.fromMap).toList();
  }
}
