import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/section_card.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_loading_placeholder.dart';

class RoutinesTab extends ConsumerWidget {
  const RoutinesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesListProvider);
    final historyAsync = ref.watch(workoutHistoryProvider);
    return Stack(children: [
      ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          Text('Routine plans', style: Theme.of(context).textTheme.titleMedium),
          Text(
              'Reusable exercise plans. Start one to log today’s sets and reps.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          routinesAsync.when(
            loading: () => const GymLoadingPlaceholder(rows: 3),
            error: (e, _) => ErrorView(
              message: Failure.from(e).message,
              onRetry: () => ref.invalidate(routinesListProvider),
            ),
            data: (routines) {
              if (routines.isEmpty) {
                return SectionCard(
                  child: Column(
                    children: [
                      const EmptyState(
                        icon: Icons.list_alt_rounded,
                        title: 'No routine plans yet',
                        subtitle:
                            'Create a plan such as “Push Day”, then reuse it whenever you train.',
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/gym/workout/start'),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Log a workout without a plan'),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final r in routines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SectionCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.list_alt_rounded),
                          title: Text(r.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(r.createdAt == null
                              ? 'Reusable workout plan'
                              : 'Created ${DateFormat('MMM d, yyyy').format(r.createdAt!.toLocal())}'),
                          onTap: () => context.push('/gym/routines/${r.id}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow_rounded),
                                tooltip: 'Start this routine',
                                onPressed: () => context.push(
                                    '/gym/workout/start?routineId=${r.id}'),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 20),
                                tooltip: 'Delete routine',
                                onPressed: () => ref
                                    .read(routineRepositoryProvider)
                                    .deleteRoutine(r.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily workout history',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Completed sessions, grouped by their saved date.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/gym/history'),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          historyAsync.when(
            loading: () => const GymLoadingPlaceholder(rows: 2),
            error: (e, _) => ErrorView(
              message: Failure.from(e).message,
              onRetry: () => ref.invalidate(workoutHistoryProvider),
            ),
            data: (workouts) {
              final completed =
                  workouts.where((w) => w.completedAt != null).toList();
              if (completed.isEmpty) {
                return const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No saved workout days yet',
                  subtitle:
                      'Finish a session to keep its exercises, sets, reps, and date in your history.',
                );
              }
              return Column(
                children: completed.take(6).map((workout) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SectionCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => context.push('/gym/workout/${workout.id}'),
                        leading: const Icon(Icons.fitness_center_rounded),
                        title: Text(workout.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(DateFormat('MMM d, yyyy · h:mm a')
                            .format(workout.date.toLocal())),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
      Positioned(
        right: 16,
        bottom: 24,
        child: FloatingActionButton.extended(
          heroTag: 'newRoutine',
          onPressed: () => context.push('/gym/routines/new'),
          icon: const Icon(Icons.add),
          label: const Text('New Routine'),
        ),
      ),
    ]);
  }
}
