import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/gym/domain/workout_routine.dart';

void main() {
  test('routine exercise preserves target sets and reps for daily logs', () {
    const exercise = RoutineExercise(
      id: 'entry-1',
      routineId: 'routine-1',
      exerciseId: 'exercise-1',
      targetSets: 4,
      targetReps: 12,
      orderIndex: 2,
    );

    final restored = RoutineExercise.fromMap({
      'id': exercise.id,
      ...exercise.toWritableMap(),
    });

    expect(restored.routineId, exercise.routineId);
    expect(restored.exerciseId, exercise.exerciseId);
    expect(restored.targetSets, 4);
    expect(restored.targetReps, 12);
    expect(restored.orderIndex, 2);
  });
}
