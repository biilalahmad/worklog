import 'client.dart';

abstract class ClientRepository {
  Stream<List<Client>> watchClients();
  Stream<Client?> watchClient(String clientId);
  Future<Client?> getClient(String clientId);
  Future<String> addClient(Client client);
  Future<void> updateClient(Client client);
  Future<void> deleteClient(String clientId);

  /// Creates a new invoice/project for every retainer client whose
  /// billing day has arrived and hasn't already been billed this
  /// month. Safe to call anytime (idempotent per calendar month) —
  /// called once automatically on Home launch, and available as a
  /// manual "Generate Now" button on Client Detail. Returns how many
  /// invoices were created.
  Future<int> generateDueRetainerInvoices();

  /// Full list (no stream) — used for CSV export/backup.
  Future<List<Client>> getAllClients();
}
