import '../../../core/utils/date_keys.dart';

/// An incoming payment from a client. Recording this triggers the
/// Postgres trigger that updates the linked project's amount_paid/
/// status and the client's total_earned/total_pending — see
/// supabase/schema.sql.
class Income {
  final String id;
  final String clientId;
  final String? projectId;
  final int amountMinor;
  final String currency;
  final DateTime date;
  final String method;
  final String? description;
  final String? notes;
  final DateTime? createdAt;

  const Income({
    required this.id,
    required this.clientId,
    this.projectId,
    required this.amountMinor,
    required this.currency,
    required this.date,
    required this.method,
    this.description,
    this.notes,
    this.createdAt,
  });

  factory Income.fromMap(Map<String, dynamic> data) {
    return Income(
      id: data['id'] as String,
      clientId: data['client_id'] as String? ?? '',
      projectId: data['project_id'] as String?,
      // Older/manual entries may contain a negative sign. Income is an
      // inflow; normalize it for display, totals, reports, and rollups.
      amountMinor: ((data['amount'] as num?)?.toInt() ?? 0).abs(),
      currency: data['currency'] as String? ?? 'PKR',
      date: DateKeys.fromStorageCalendarDate(data['date'] as String?) ??
          DateTime.now(),
      method: data['method'] as String? ?? '',
      description: data['description'] as String?,
      notes: data['notes'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toWritableMap() {
    return {
      'client_id': clientId,
      'project_id': projectId,
      'amount': amountMinor.abs(),
      'currency': currency,
      'date': DateKeys.toStorageCalendarDate(date),
      'method': method,
      'description': description,
      'notes': notes,
    };
  }
}
