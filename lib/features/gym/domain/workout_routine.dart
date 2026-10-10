class RoutineExercise {
  final String id;
  final String routineId;
  final String exerciseId;
  final int targetSets;
  final int targetReps;
  final int orderIndex;

  const RoutineExercise({
    required this.id,
    required this.routineId,
    required this.exerciseId,
    this.targetSets = 3,
    this.targetReps = 10,
    this.orderIndex = 0,
  });

  factory RoutineExercise.fromMap(Map<String, dynamic> data) {
    return RoutineExercise(
      id: data['id'] as String,
      routineId: data['routine_id'] as String? ?? '',
      exerciseId: data['exercise_id'] as String? ?? '',
      targetSets: (data['target_sets'] as num?)?.toInt() ?? 3,
      targetReps: (data['target_reps'] as num?)?.toInt() ?? 10,
      orderIndex: (data['order_index'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toWritableMap() => {
        'routine_id': routineId,
        'exercise_id': exerciseId,
        'target_sets': targetSets,
        'target_reps': targetReps,
        'order_index': orderIndex,
      };
}

/// A reusable workout template ("Push Day") with a fixed exercise plan
/// you can start a real workout from in one tap.
class WorkoutRoutine {
  final String id;
  final String name;
  final DateTime? createdAt;

  const WorkoutRoutine({required this.id, required this.name, this.createdAt});

  factory WorkoutRoutine.fromMap(Map<String, dynamic> data) {
    return WorkoutRoutine(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toWritableMap() => {'name': name};
}
