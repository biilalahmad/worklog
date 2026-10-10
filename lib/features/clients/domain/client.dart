import '../../../core/utils/money.dart';

/// A client profile. `totalEarned`, `totalPending`, `totalVideosCompleted`
/// and `lastActivityAt` are rollups maintained by Postgres triggers
/// (see supabase/schema.sql) — never written directly by the app, so
/// they can't drift from the underlying work/payment records.
class Client {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? email;
  final String? phone;
  final String? notes;
  final DateTime? createdAt;
  final MoneyByCurrency totalEarned;
  final MoneyByCurrency totalPending;
  final int totalVideosCompleted;
  final DateTime? lastActivityAt;
  final bool isRetainer;
  final int? retainerAmountMinor;
  final String? retainerCurrency;
  final int? retainerDayOfMonth;
  final String? retainerLastGeneratedMonth;

  const Client({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.email,
    this.phone,
    this.notes,
    this.createdAt,
    this.totalEarned = const MoneyByCurrency({}),
    this.totalPending = const MoneyByCurrency({}),
    this.totalVideosCompleted = 0,
    this.lastActivityAt,
    this.isRetainer = false,
    this.retainerAmountMinor,
    this.retainerCurrency,
    this.retainerDayOfMonth,
    this.retainerLastGeneratedMonth,
  });

  factory Client.fromMap(Map<String, dynamic> data) {
    return Client(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      avatarUrl: data['avatar_url'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      notes: data['notes'] as String?,
      createdAt: data['created_at'] != null ? DateTime.tryParse(data['created_at'] as String) : null,
      totalEarned: MoneyByCurrency.fromMap(data['total_earned'] as Map<String, dynamic>?),
      totalPending: MoneyByCurrency.fromMap(data['total_pending'] as Map<String, dynamic>?),
      totalVideosCompleted: (data['total_videos_completed'] as num?)?.toInt() ?? 0,
      lastActivityAt:
          data['last_activity_at'] != null ? DateTime.tryParse(data['last_activity_at'] as String) : null,
      isRetainer: (data['is_retainer'] as bool?) ?? false,
      retainerAmountMinor: (data['retainer_amount'] as num?)?.toInt(),
      retainerCurrency: data['retainer_currency'] as String?,
      retainerDayOfMonth: (data['retainer_day_of_month'] as num?)?.toInt(),
      retainerLastGeneratedMonth: data['retainer_last_generated_month'] as String?,
    );
  }

  /// Fields the app is allowed to write directly. Rollup fields are
  /// intentionally excluded — only the database triggers touch those.
  Map<String, dynamic> toWritableMap() {
    return {
      'name': name,
      'avatar_url': avatarUrl,
      'email': email,
      'phone': phone,
      'notes': notes,
      'is_retainer': isRetainer,
      'retainer_amount': isRetainer ? retainerAmountMinor : null,
      'retainer_currency': isRetainer ? retainerCurrency : null,
      'retainer_day_of_month': isRetainer ? retainerDayOfMonth : null,
    };
  }

  Client copyWith({
    String? name,
    String? avatarUrl,
    String? email,
    String? phone,
    String? notes,
    bool? isRetainer,
    int? retainerAmountMinor,
    String? retainerCurrency,
    int? retainerDayOfMonth,
  }) {
    return Client(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      totalEarned: totalEarned,
      totalPending: totalPending,
      totalVideosCompleted: totalVideosCompleted,
      lastActivityAt: lastActivityAt,
      isRetainer: isRetainer ?? this.isRetainer,
      retainerAmountMinor: retainerAmountMinor ?? this.retainerAmountMinor,
      retainerCurrency: retainerCurrency ?? this.retainerCurrency,
      retainerDayOfMonth: retainerDayOfMonth ?? this.retainerDayOfMonth,
      retainerLastGeneratedMonth: retainerLastGeneratedMonth,
    );
  }
}
