class BodyStat {
  final String id;
  final DateTime date;
  final double? weight;
  final double? heightCm;
  final double? targetWeightKg;
  final double? bodyFatPct;
  final double? chestCm;
  final double? waistCm;
  final double? armCm;
  final double? thighCm;
  final String? notes;

  const BodyStat({
    required this.id,
    required this.date,
    this.weight,
    this.heightCm,
    this.targetWeightKg,
    this.bodyFatPct,
    this.chestCm,
    this.waistCm,
    this.armCm,
    this.thighCm,
    this.notes,
  });

  factory BodyStat.fromMap(Map<String, dynamic> data) {
    return BodyStat(
      id: data['id'] as String,
      date: DateTime.tryParse(data['date'] as String? ?? '') ?? DateTime.now(),
      weight: (data['weight'] as num?)?.toDouble(),
      heightCm: (data['height_cm'] as num?)?.toDouble(),
      targetWeightKg: (data['target_weight_kg'] as num?)?.toDouble(),
      bodyFatPct: (data['body_fat_pct'] as num?)?.toDouble(),
      chestCm: (data['chest_cm'] as num?)?.toDouble(),
      waistCm: (data['waist_cm'] as num?)?.toDouble(),
      armCm: (data['arm_cm'] as num?)?.toDouble(),
      thighCm: (data['thigh_cm'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toWritableMap() => {
        'date': date.toIso8601String(),
        'weight': weight,
        'height_cm': heightCm,
        'target_weight_kg': targetWeightKg,
        'body_fat_pct': bodyFatPct,
        'chest_cm': chestCm,
        'waist_cm': waistCm,
        'arm_cm': armCm,
        'thigh_cm': thighCm,
        'notes': notes,
      };
}
