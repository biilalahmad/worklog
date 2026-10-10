import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/date_keys.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/workout.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_loading_placeholder.dart';

class WorkoutTab extends ConsumerWidget {
  const WorkoutTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final todayRange =
        GymDateRange(DateKeys.startOfDay(today), DateKeys.endOfDay(today));
    final todayWorkoutsAsync = ref.watch(workoutsForRangeProvider(todayRange));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        Text("Today's Workout", style: Theme.of(context).textTheme.titleMedium),
        Text(
            'Log exercises and sets; unfinished sessions stay available to resume.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        todayWorkoutsAsync.when(
          loading: () => const GymLoadingPlaceholder(rows: 1),
          error: (e, _) => ErrorView(message: Failure.from(e).message),
          data: (workouts) {
            if (workouts.isEmpty) {
              return const EmptyState(
                icon: Icons.fitness_center_outlined,
                title: 'No workout logged today',
                subtitle: 'Tap Start Workout above to begin.',
              );
            }
            return Column(
              children: workouts
                  .map((w) => _WorkoutCard(
                      workout: w,
                      onTap: () => context.push('/gym/workout/${w.id}')))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        Text('Explore your training',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _QuickLinkTile(
          icon: Icons.history_rounded,
          title: 'Workout History',
          subtitle: 'Every past session',
          onTap: () => context.push('/gym/history'),
        ),
        const SizedBox(height: 8),
        _QuickLinkTile(
          icon: Icons.menu_book_rounded,
          title: 'Exercise Library',
          subtitle: 'Browse and filter exercises',
          onTap: () => context.push('/gym/exercises'),
        ),
      ],
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;
  const _WorkoutCard({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Icon(Icons.fitness_center_rounded,
                color: scheme.primary, size: 18),
          ),
          title: Text(workout.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            workout.completedAt == null
                ? 'In progress · ${DateFormat('h:mm a').format(workout.date)}'
                : '${DateFormat('h:mm a').format(workout.date)}${workout.duration != null ? ' · ${workout.duration!.inMinutes} min' : ''}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickLinkTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          child: Icon(icon, color: scheme.primary, size: 18),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
