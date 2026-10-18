import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/date_keys.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../domain/workout.dart';
import '../../domain/diet_target.dart';
import '../../domain/meal_entry.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../../assistant/domain/assistant_contract.dart';
import '../../../assistant/presentation/widgets/assistant_entry.dart';
import '../providers/gym_providers.dart';

class GymDashboardScreen extends ConsumerStatefulWidget {
  const GymDashboardScreen({super.key});

  @override
  ConsumerState<GymDashboardScreen> createState() => _GymDashboardScreenState();
}

class _GymDashboardScreenState extends ConsumerState<GymDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recentWorkouts =
        ref.watch(recentWorkoutsProvider).valueOrNull ?? const <Workout>[];
    final todayWorkouts = recentWorkouts
        .where((workout) =>
            !workout.date.isBefore(today) &&
            workout.date.isBefore(today.add(const Duration(days: 1))))
        .toList(growable: false);
    Workout? unfinishedWorkout;
    for (final workout in recentWorkouts) {
      if (workout.completedAt == null) {
        unfinishedWorkout = workout;
        break;
      }
    }
    final streak = ref.watch(workoutStreakProvider);
    final mealsAsync = ref.watch(mealsForDateProvider(today));
    final targetAsync = ref.watch(dietTargetProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final email = ref.watch(authRepositoryProvider).currentUserEmail;
    final name =
        profile?.displayName == null || profile?.displayName == 'WorkLog User'
            ? AvatarCircle.firstNameFromEmail(email)
            : profile!.displayName.split(RegExp(r'\s+')).first;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            AvatarCircle(
              imageUrl: profile?.avatarUrl,
              initials: profile?.avatarUrl?.isNotEmpty == true
                  ? profile!.initials
                  : (AvatarCircle.initialsFromEmail(email) ?? '?'),
              seed: email,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Hey, ${name ?? 'there'}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Exercise library',
              onPressed: () => context.push('/gym/exercises'),
              icon: const Icon(Icons.search_rounded),
            ),
            const AssistantShortcutButton(agent: AssistantAgent.gym),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          AppInsets.belowNavigation(context),
        ),
        children: [
          FadeSlideIn(
            child: _GymHeroCard(
              streak: streak,
              todayWorkouts: todayWorkouts,
              recentWorkouts: recentWorkouts,
              meals: mealsAsync.valueOrNull ?? const [],
              target: targetAsync.valueOrNull ?? const DietTarget(),
              hasUnfinishedWorkout: unfinishedWorkout != null,
              onStartWorkout: () => context.push(
                unfinishedWorkout == null
                    ? '/gym/workout/start'
                    : '/gym/workout/${unfinishedWorkout.id}',
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.55,
            children: [
              _GymAction(
                  icon: Icons.fitness_center_rounded,
                  label: 'Workout',
                  onTap: () => context.push('/gym/sections?tab=0')),
              _GymAction(
                  icon: Icons.view_list_rounded,
                  label: 'Routines',
                  onTap: () => context.push('/gym/sections?tab=1')),
              _GymAction(
                  icon: Icons.insights_rounded,
                  label: 'Progress',
                  onTap: () => context.push('/gym/sections?tab=2')),
              _GymAction(
                  icon: Icons.restaurant_rounded,
                  label: 'Diet',
                  onTap: () => context.push('/gym/sections?tab=3')),
              _GymAction(
                  icon: Icons.search_rounded,
                  label: 'Exercises',
                  onTap: () => context.push('/gym/exercises')),
              _GymAction(
                  icon: Icons.history_rounded,
                  label: 'History',
                  onTap: () => context.push('/gym/history')),
            ],
          ),
        ],
      ),
    );
  }
}

class _GymAction extends StatelessWidget {
  const _GymAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                    radius: 18,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(icon, color: scheme.primary, size: 18)),
                const SizedBox(height: AppSpacing.sm),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
        ),
      ),
    );
  }
}

class _GymHeroCard extends StatelessWidget {
  final int streak;
  final List<Workout> todayWorkouts;
  final List<Workout> recentWorkouts;
  final VoidCallback onStartWorkout;
  final List<MealEntry> meals;
  final DietTarget target;
  final bool hasUnfinishedWorkout;

  const _GymHeroCard({
    required this.streak,
    required this.todayWorkouts,
    required this.recentWorkouts,
    required this.onStartWorkout,
    required this.meals,
    required this.target,
    required this.hasUnfinishedWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completedToday =
        todayWorkouts.where((workout) => workout.completedAt != null).length;
    final hasWorkoutToday = completedToday > 0;
    final calories = meals.fold(0.0, (sum, meal) => sum + meal.calories);
    final remaining =
        (target.dailyCalories - calories).clamp(0, double.infinity);
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final activeDays = <DateTime>{
      for (final workout in recentWorkouts)
        if (workout.completedAt != null &&
            !workout.date.isBefore(monday) &&
            workout.date.isBefore(monday.add(const Duration(days: 7))))
          DateTime(workout.date.year, workout.date.month, workout.date.day),
    };
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.onPrimary.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
              color: scheme.primary.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: .94),
                ],
              ),
              border:
                  Border.all(color: scheme.onPrimary.withValues(alpha: .16)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            hasUnfinishedWorkout
                                ? 'Pick up where you left off'
                                : 'Ready when you are 💪',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          hasWorkoutToday
                              ? 'Workout logged today'
                              : 'No workout logged today yet',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13),
                        ),
                      ],
                    ),
                    if (streak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded,
                                color: Colors.orangeAccent, size: 16),
                            const SizedBox(width: 4),
                            Text('$streak day${streak == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text('THIS WEEK',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                    const Spacer(),
                    Text(
                        '${activeDays.length} active day${activeDays.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 7; i++)
                      _WeekdayDot(
                        date: monday.add(Duration(days: i)),
                        isActive:
                            activeDays.contains(monday.add(Duration(days: i))),
                        isToday: DateKeys.day(monday.add(Duration(days: i))) ==
                            DateKeys.day(now),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Row(
                    key: ValueKey(
                        '${calories.toInt()}-${target.dailyCalories.toInt()}'),
                    children: [
                      const Icon(Icons.restaurant_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      Text('${calories.toStringAsFixed(0)} kcal eaten',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('${remaining.toStringAsFixed(0)} left',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onStartWorkout,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                        hasUnfinishedWorkout
                            ? 'Continue Workout'
                            : hasWorkoutToday
                                ? 'Log another workout'
                                : 'Start Workout',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}

class _WeekdayDot extends StatelessWidget {
  final DateTime date;
  final bool isActive;
  final bool isToday;

  const _WeekdayDot(
      {required this.date, required this.isActive, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final foreground =
        isActive ? Theme.of(context).colorScheme.primary : Colors.white70;
    return Column(
      children: [
        Text(DateFormat('E').format(date).substring(0, 1),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 10,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: isToday ? 0.24 : 0.12),
            border:
                isToday ? Border.all(color: Colors.white, width: 1.4) : null,
          ),
          alignment: Alignment.center,
          child: isActive
              ? Icon(Icons.check_rounded, size: 16, color: foreground)
              : Text('${date.day}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
