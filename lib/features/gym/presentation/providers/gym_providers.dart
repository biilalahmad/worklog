import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/body_stat_repository_impl.dart';
import '../../data/diet_repository_impl.dart';
import '../../data/exercise_repository_impl.dart';
import '../../data/goal_repository_impl.dart';
import '../../data/gym_stats_repository_impl.dart';
import '../../data/routine_repository_impl.dart';
import '../../data/workout_repository_impl.dart';
import '../../data/wger_exercise_service.dart';
import '../../data/food_lookup_service.dart';
import '../../domain/body_stat.dart';
import '../../domain/diet_target.dart';
import '../../domain/exercise.dart';
import '../../domain/food.dart';
import '../../domain/gym_goal.dart';
import '../../domain/gym_repositories.dart';
import '../../domain/gym_stats.dart';
import '../../domain/meal_entry.dart';
import '../../domain/workout.dart';
import '../../domain/workout_routine.dart';
import '../../domain/water_log.dart';

final exerciseRepositoryProvider =
    Provider<ExerciseRepository>((ref) => ExerciseRepositoryImpl());
final wgerExerciseServiceProvider = Provider<WgerExerciseService>((ref) {
  final service = WgerExerciseService();
  ref.onDispose(service.dispose);
  return service;
});
final wgerExerciseSearchProvider =
    FutureProvider.family<List<WgerExerciseSuggestion>, String>((ref, query) {
  return ref.watch(wgerExerciseServiceProvider).search(query);
});
final foodLookupServiceProvider = Provider<FoodLookupService>((ref) {
  final service = FoodLookupService();
  ref.onDispose(service.dispose);
  return service;
});
final foodNameSearchProvider =
    FutureProvider.family<List<FoodLookupResult>, String>((ref, query) {
  return ref.watch(foodLookupServiceProvider).searchByName(query);
});
final routineRepositoryProvider =
    Provider<RoutineRepository>((ref) => RoutineRepositoryImpl());
final workoutRepositoryProvider =
    Provider<WorkoutRepository>((ref) => WorkoutRepositoryImpl());
final bodyStatRepositoryProvider =
    Provider<BodyStatRepository>((ref) => BodyStatRepositoryImpl());
final goalRepositoryProvider =
    Provider<GoalRepository>((ref) => GoalRepositoryImpl());
final dietRepositoryProvider =
    Provider<DietRepository>((ref) => DietRepositoryImpl());
final gymStatsRepositoryProvider =
    Provider<GymStatsRepository>((ref) => GymStatsRepositoryImpl());

final exercisesListProvider = StreamProvider<List<Exercise>>((ref) {
  return ref.watch(exerciseRepositoryProvider).watchExercises();
});

final routinesListProvider = StreamProvider<List<WorkoutRoutine>>((ref) {
  return ref.watch(routineRepositoryProvider).watchRoutines();
});

final routineExercisesProvider =
    StreamProvider.family<List<RoutineExercise>, String>((ref, routineId) {
  return ref.watch(routineRepositoryProvider).watchRoutineExercises(routineId);
});

final recentWorkoutsProvider = StreamProvider<List<Workout>>((ref) {
  return ref.watch(workoutRepositoryProvider).watchRecentWorkouts();
});

/// A broader window for the browsable workout history; dashboard and streak
/// consumers keep the smaller recent list for faster updates.
final workoutHistoryProvider = StreamProvider<List<Workout>>((ref) {
  return ref.watch(workoutRepositoryProvider).watchRecentWorkouts(limit: 500);
});

final workoutDetailProvider =
    StreamProvider.family<Workout?, String>((ref, workoutId) {
  return ref.watch(workoutRepositoryProvider).watchWorkout(workoutId);
});

class GymDateRange {
  final DateTime start;
  final DateTime end;
  const GymDateRange(this.start, this.end);
  @override
  bool operator ==(Object other) =>
      other is GymDateRange && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
}

final workoutsForRangeProvider =
    StreamProvider.family<List<Workout>, GymDateRange>((ref, range) {
  return ref
      .watch(workoutRepositoryProvider)
      .watchWorkoutsForRange(range.start, range.end);
});

final gymStatsForRangeProvider =
    StreamProvider.family<GymStats, GymDateRange>((ref, range) {
  return ref
      .watch(gymStatsRepositoryProvider)
      .watchGymStats(range.start, range.end);
});

final bodyStatsListProvider = StreamProvider<List<BodyStat>>((ref) {
  return ref.watch(bodyStatRepositoryProvider).watchBodyStats();
});

final goalsListProvider = StreamProvider<List<GymGoal>>((ref) {
  return ref.watch(goalRepositoryProvider).watchGoals();
});

final foodsListProvider = StreamProvider<List<Food>>((ref) {
  return ref.watch(dietRepositoryProvider).watchFoods();
});

final mealsForDateProvider =
    StreamProvider.family<List<MealEntry>, DateTime>((ref, date) {
  return ref.watch(dietRepositoryProvider).watchMealsForDate(date);
});

final dietTargetProvider = StreamProvider<DietTarget>((ref) {
  return ref.watch(dietRepositoryProvider).watchDietTarget();
});

final waterLogsForDateProvider =
    FutureProvider.family<List<WaterLog>, DateTime>((ref, date) {
  return ref.watch(dietRepositoryProvider).getWaterLogsForDate(date);
});

/// Personal record for one exercise — a plain Future (not a live
/// stream) since it's cheap to refetch and only needed on demand
/// (exercise detail / workout logging screens).
final exercisePrProvider =
    FutureProvider.family<double?, String>((ref, exerciseId) {
  return ref.watch(workoutRepositoryProvider).personalRecord(exerciseId);
});

final lastSetsForExerciseProvider =
    FutureProvider.family<List<WorkoutSet>, String>((ref, exerciseId) {
  return ref.watch(workoutRepositoryProvider).lastSetsForExercise(exerciseId);
});

/// Current workout streak — consecutive days (working backward from
/// today) that have at least one completed workout. Derived from the
/// already-loaded recent-workouts list rather than a separate query.
final workoutStreakProvider = Provider<int>((ref) {
  final workoutsAsync = ref.watch(recentWorkoutsProvider);
  return workoutsAsync.maybeWhen(
    data: (workouts) {
      final days = workouts
          .where((workout) => workout.completedAt != null)
          .map((w) => DateTime(w.date.year, w.date.month, w.date.day))
          .toSet();
      var streak = 0;
      var cursor = DateTime.now();
      cursor = DateTime(cursor.year, cursor.month, cursor.day);
      // Today doesn't have to have a workout yet for the streak to
      // still be "alive" — only break once a full day is skipped.
      if (!days.contains(cursor)) {
        cursor = cursor.subtract(const Duration(days: 1));
      }
      while (days.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return streak;
    },
    orElse: () => 0,
  );
});
