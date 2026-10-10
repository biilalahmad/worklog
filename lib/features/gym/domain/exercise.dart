enum MuscleGroup { chest, back, legs, shoulders, arms, core, cardio, other }

extension MuscleGroupX on MuscleGroup {
  String get asString => toString().split('.').last;
  String get label {
    switch (this) {
      case MuscleGroup.chest:
        return 'Chest';
      case MuscleGroup.back:
        return 'Back';
      case MuscleGroup.legs:
        return 'Legs';
      case MuscleGroup.shoulders:
        return 'Shoulders';
      case MuscleGroup.arms:
        return 'Arms';
      case MuscleGroup.core:
        return 'Core';
      case MuscleGroup.cardio:
        return 'Cardio';
      case MuscleGroup.other:
        return 'Other';
    }
  }

  static MuscleGroup fromString(String? v) => MuscleGroup.values
      .firstWhere((m) => m.asString == v, orElse: () => MuscleGroup.other);
}

/// A reusable exercise — typed once (like a client), suggested from
/// then on via type-ahead.
class Exercise {
  final String id;
  final String name;
  final MuscleGroup muscleGroup;
  final String equipment;
  final DateTime? createdAt;

  const Exercise({
    required this.id,
    required this.name,
    this.muscleGroup = MuscleGroup.other,
    this.equipment = '',
    this.createdAt,
  });

  factory Exercise.fromMap(Map<String, dynamic> data) {
    return Exercise(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      muscleGroup: MuscleGroupX.fromString(data['muscle_group'] as String?),
      equipment: data['equipment'] as String? ?? '',
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toWritableMap() => {
        'name': name,
        'muscle_group': muscleGroup.asString,
        'equipment': equipment,
      };
}
