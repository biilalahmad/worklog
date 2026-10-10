import 'body_stat.dart';
import 'exercise.dart';
import 'food.dart';
import 'gym_goal.dart';
import 'gym_stats.dart';
import 'meal_entry.dart';
import 'diet_target.dart';
import 'workout.dart';
import 'workout_routine.dart';
import 'water_log.dart';

abstract class ExerciseRepository {
  Stream<List<Exercise>> watchExercises();
  Future<String> addExercise(Exercise exercise);

  /// Returns the id of an existing exercise matching [name]
  /// case-insensitively, or creates one if none exists — used when
  /// logging a set with a freshly-typed exercise name.
  Future<String> findOrCreateByName(
    String name, {
    MuscleGroup muscleGroup = MuscleGroup.other,
    String equipment = '',
  });
}

abstract class RoutineRepository {
  Stream<List<WorkoutRoutine>> watchRoutines();
  Stream<List<RoutineExercise>> watchRoutineExercises(String routineId);
  Future<String> addRoutine(WorkoutRoutine routine);
  Future<void> deleteRoutine(String routineId);
  Future<void> addRoutineExercise(RoutineExercise re);
  Future<void> deleteRoutineExercise(String id);
}

abstract class WorkoutRepository {
  Stream<List<Workout>> watchRecentWorkouts({int limit = 30});
  Stream<List<Workout>> watchWorkoutsForRange(DateTime start, DateTime end);
  Stream<Workout?> watchWorkout(String workoutId);
  Future<String> addWorkout(Workout workout);
  Future<void> updateWorkout(Workout workout);
  Future<void> deleteWorkout(String workoutId);
  Future<void> discardExpiredEmptyWorkouts();

  Future<String> addSet(WorkoutSet set);
  Future<void> updateSet(WorkoutSet set);
  Future<void> deleteSet(String setId);

  /// Most recent sets logged for this exercise (across any workout) —
  /// powers "previous performance" shown while logging.
  Future<List<WorkoutSet>> lastSetsForExercise(String exerciseId,
      {int limit = 5});
  Future<double?> personalRecord(String exerciseId);
}

abstract class BodyStatRepository {
  Stream<List<BodyStat>> watchBodyStats({int limit = 200});
  Future<String> addBodyStat(BodyStat stat);
  Future<void> deleteBodyStat(String id);
}

abstract class GoalRepository {
  Stream<List<GymGoal>> watchGoals();
  Future<String> addGoal(GymGoal goal);
  Future<void> updateGoal(GymGoal goal);
  Future<void> deleteGoal(String id);
  Future<void> setAchieved(String id, bool achieved);
}

abstract class DietRepository {
  Stream<List<Food>> watchFoods();
  Future<String> addFood(Food food);
  Stream<List<MealEntry>> watchMealsForDate(DateTime date);
  Future<String> addMeal(MealEntry meal);
  Future<void> deleteMeal(String id);
  Stream<DietTarget> watchDietTarget();
  Future<void> saveDietTarget(DietTarget target);
  Future<List<WaterLog>> getWaterLogsForDate(DateTime date);
  Future<String> addWaterLog(int milliliters, DateTime date);
  Future<void> deleteWaterLog(String id);
}

abstract class GymStatsRepository {
  Stream<GymStats> watchGymStats(DateTime start, DateTime end);
}
