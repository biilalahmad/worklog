enum SetType { normal, warmup, drop, failure, superset }

extension SetTypeX on SetType {
  String get asString => toString().split('.').last;
  String get label {
    switch (this) {
      case SetType.normal:
        return 'Normal';
      case SetType.warmup:
        return 'Warm-up';
      case SetType.drop:
        return 'Drop set';
      case SetType.failure:
        return 'Failure';
      case SetType.superset:
        return 'Superset';
    }
  }

  static SetType fromString(String? v) => SetType.values
      .firstWhere((s) => s.asString == v, orElse: () => SetType.normal);
}

class WorkoutSet {
  final String id;
  final String workoutId;
  final String exerciseId;
  final int setNumber;
  final int reps;
  final double weight;
  final String weightUnit; // kg | lbs
  final SetType setType;
  final double? rpe;
  final String? notes;
  final DateTime? createdAt;

  const WorkoutSet({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    this.setNumber = 1,
    this.reps = 0,
    this.weight = 0,
    this.weightUnit = 'kg',
    this.setType = SetType.normal,
    this.rpe,
    this.notes,
    this.createdAt,
  });

  factory WorkoutSet.fromMap(Map<String, dynamic> data) {
    return WorkoutSet(
      id: data['id'] as String,
      workoutId: data['workout_id'] as String? ?? '',
      exerciseId: data['exercise_id'] as String? ?? '',
      setNumber: (data['set_number'] as num?)?.toInt() ?? 1,
      reps: (data['reps'] as num?)?.toInt() ?? 0,
      weight: (data['weight'] as num?)?.toDouble() ?? 0,
      weightUnit: data['weight_unit'] as String? ?? 'kg',
      setType: SetTypeX.fromString(data['set_type'] as String?),
      rpe: (data['rpe'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toWritableMap() => {
        'workout_id': workoutId,
        'exercise_id': exerciseId,
        'set_number': setNumber,
        'reps': reps,
        'weight': weight,
        'weight_unit': weightUnit,
        'set_type': setType.asString,
        'rpe': rpe,
        'notes': notes,
      };
}

/// A logged workout session. `sets` is populated by the repository
/// when fetching a single workout's detail — it isn't stored on the
/// row itself.
class Workout {
  final String id;
  final String? routineId;
  final String name;
  final DateTime date;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  final DateTime? createdAt;
  final List<WorkoutSet> sets;

  const Workout({
    required this.id,
    this.routineId,
    this.name = 'Workout',
    required this.date,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.createdAt,
    this.sets = const [],
  });

  Duration? get duration => (startedAt != null && completedAt != null)
      ? completedAt!.difference(startedAt!)
      : null;

  double get totalVolume => sets.fold(0, (sum, s) => sum + (s.reps * s.weight));

  factory Workout.fromMap(Map<String, dynamic> data,
      {List<WorkoutSet> sets = const []}) {
    return Workout(
      id: data['id'] as String,
      routineId: data['routine_id'] as String?,
      name: data['name'] as String? ?? 'Workout',
      date: DateTime.tryParse(data['date'] as String? ?? '') ?? DateTime.now(),
      startedAt: data['started_at'] != null
          ? DateTime.tryParse(data['started_at'] as String)
          : null,
      completedAt: data['completed_at'] != null
          ? DateTime.tryParse(data['completed_at'] as String)
          : null,
      notes: data['notes'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
      sets: sets,
    );
  }

  Map<String, dynamic> toWritableMap() => {
        'routine_id': routineId,
        'name': name,
        'date': date.toIso8601String(),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'notes': notes,
      };
}
