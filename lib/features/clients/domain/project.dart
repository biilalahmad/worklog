enum ProjectStatus { unpaid, partiallyPaid, paid, overdue }

extension ProjectStatusX on ProjectStatus {
  String get label {
    switch (this) {
      case ProjectStatus.unpaid:
        return 'Unpaid';
      case ProjectStatus.partiallyPaid:
        return 'Partially Paid';
      case ProjectStatus.paid:
        return 'Paid';
      case ProjectStatus.overdue:
        return 'Overdue';
    }
  }

  static ProjectStatus fromString(String? value) {
    switch (value) {
      case 'partiallyPaid':
        return ProjectStatus.partiallyPaid;
      case 'paid':
        return ProjectStatus.paid;
      case 'overdue':
        return ProjectStatus.overdue;
      default:
        return ProjectStatus.unpaid;
    }
  }

  String get asString => toString().split('.').last;
}

/// A project/invoice under a client. `amountPaid`, `amountRemaining`
/// and `status` are maintained by a Postgres trigger on `income` (see
/// supabase/schema.sql) — never computed client-side, so "Remaining =
/// Total - Paid" can never drift from actual payment records.
class Project {
  final String id;
  final String clientId;
  final String title;
  final int totalAmountMinor;
  final int subtotalAmountMinor;
  final int taxAmountMinor;
  final int taxRateBps;
  final String taxLabel;
  final String currency;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int amountPaidMinor;
  final int amountRemainingMinor;
  final ProjectStatus status;
  final String? shareToken;

  const Project({
    required this.id,
    required this.clientId,
    required this.title,
    required this.totalAmountMinor,
    int? subtotalAmountMinor,
    this.taxAmountMinor = 0,
    this.taxRateBps = 0,
    this.taxLabel = 'Tax',
    required this.currency,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
    this.amountPaidMinor = 0,
    this.amountRemainingMinor = 0,
    this.status = ProjectStatus.unpaid,
    this.shareToken,
  }) : subtotalAmountMinor = subtotalAmountMinor ?? totalAmountMinor;

  double get taxRatePercent => taxRateBps / 100;

  /// Status as it should be *displayed*: the stored status becomes
  /// "overdue" once the due date has passed and the project still
  /// isn't fully paid — computed live instead of needing a daily
  /// server-side sweep job.
  ProjectStatus get displayStatus {
    if (status != ProjectStatus.paid &&
        dueDate != null &&
        dueDate!.isBefore(DateTime.now())) {
      return ProjectStatus.overdue;
    }
    return status;
  }

  factory Project.fromMap(Map<String, dynamic> data) {
    final totalAmountMinor = (data['total_amount'] as num?)?.toInt() ?? 0;
    final amountPaidMinor = (data['amount_paid'] as num?)?.toInt() ?? 0;
    return Project(
      id: data['id'] as String,
      clientId: data['client_id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      totalAmountMinor: totalAmountMinor,
      subtotalAmountMinor:
          (data['subtotal_amount'] as num?)?.toInt() ?? totalAmountMinor,
      taxAmountMinor: (data['tax_amount'] as num?)?.toInt() ?? 0,
      taxRateBps: (data['tax_rate_bps'] as num?)?.toInt() ?? 0,
      taxLabel: data['tax_label'] as String? ?? 'Tax',
      currency: data['currency'] as String? ?? 'PKR',
      dueDate: data['due_date'] != null
          ? DateTime.tryParse(data['due_date'] as String)
          : null,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'] as String)
          : null,
      amountPaidMinor: amountPaidMinor,
      amountRemainingMinor: (totalAmountMinor - amountPaidMinor)
          .clamp(0, totalAmountMinor)
          .toInt(),
      status: ProjectStatusX.fromString(data['status'] as String?),
      shareToken: data['share_token'] as String?,
    );
  }

  Map<String, dynamic> toWritableMap() {
    return {
      'client_id': clientId,
      'title': title,
      'total_amount': totalAmountMinor,
      'subtotal_amount': subtotalAmountMinor,
      'tax_rate_bps': taxRateBps,
      'tax_label': taxLabel,
      'currency': currency,
      'due_date': dueDate?.toIso8601String(),
    };
  }
}
