enum GoalType { exerciseWeight, bodyWeight, workoutFrequency, custom }

extension GoalTypeX on GoalType {
  String get asString => toString().split('.').last;
  static GoalType fromString(String? v) => GoalType.values
      .firstWhere((g) => g.asString == v, orElse: () => GoalType.custom);
}

class GymGoal {
  final String id;
  final String title;
  final GoalType goalType;
  final String? exerciseId;
  final double targetValue;
  final double startValue;
  final String unit;
  final DateTime? targetDate;
  final bool achieved;
  final DateTime? achievedAt;

  const GymGoal({
    required this.id,
    required this.title,
    this.goalType = GoalType.custom,
    this.exerciseId,
    required this.targetValue,
    this.startValue = 0,
    this.unit = '',
    this.targetDate,
    this.achieved = false,
    this.achievedAt,
  });

  factory GymGoal.fromMap(Map<String, dynamic> data) {
    return GymGoal(
      id: data['id'] as String,
      title: data['title'] as String? ?? '',
      goalType: GoalTypeX.fromString(data['goal_type'] as String?),
      exerciseId: data['exercise_id'] as String?,
      targetValue: (data['target_value'] as num?)?.toDouble() ?? 0,
      startValue: (data['start_value'] as num?)?.toDouble() ?? 0,
      unit: data['unit'] as String? ?? '',
      targetDate: data['target_date'] != null
          ? DateTime.tryParse(data['target_date'] as String)
          : null,
      achieved: data['achieved'] as bool? ?? false,
      achievedAt: data['achieved_at'] != null
          ? DateTime.tryParse(data['achieved_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toWritableMap() => {
        'title': title,
        'goal_type': goalType.asString,
        'exercise_id': exerciseId,
        'target_value': targetValue,
        'start_value': startValue,
        'unit': unit,
        'target_date': targetDate?.toIso8601String(),
      };
}
