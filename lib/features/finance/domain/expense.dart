import '../../../core/utils/date_keys.dart';

class Expense {
  final String id;
  final int amountMinor;
  final String currency;
  final DateTime date;
  final String category;
  final String? description;
  final String? notes;
  final DateTime? createdAt;

  const Expense({
    required this.id,
    required this.amountMinor,
    required this.currency,
    required this.date,
    required this.category,
    this.description,
    this.notes,
    this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> data) {
    return Expense(
      id: data['id'] as String,
      // Expenses are stored as positive amounts; summaries subtract them
      // from cash flow instead of encoding the direction in the amount.
      amountMinor: ((data['amount'] as num?)?.toInt() ?? 0).abs(),
      currency: data['currency'] as String? ?? 'PKR',
      date: DateKeys.fromStorageCalendarDate(data['date'] as String?) ??
          DateTime.now(),
      category: data['category'] as String? ?? '',
      description: data['description'] as String?,
      notes: data['notes'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toWritableMap() {
    return {
      'amount': amountMinor.abs(),
      'currency': currency,
      'date': DateKeys.toStorageCalendarDate(date),
      'category': category,
      'description': description,
      'notes': notes,
    };
  }
}
