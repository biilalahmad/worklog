import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/workout.dart';
import '../providers/gym_providers.dart';

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Workout History')),
      body: workoutsAsync.when(
        loading: () => const LoadingIndicator(),
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
              title: 'No completed workouts yet',
              subtitle: 'Finish a workout and it will show up here.',
            );
          }
          final grouped = <String, List<Workout>>{};
          for (final workout in completed) {
            final month =
                DateFormat('MMMM yyyy').format(workout.date.toLocal());
            grouped.putIfAbsent(month, () => []).add(workout);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(entry.key,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final w in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => context.push('/gym/workout/${w.id}'),
                        leading: const Icon(Icons.fitness_center_rounded),
                        title: Text(w.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(DateFormat('EEE, MMM d, yyyy · h:mm a')
                            .format(w.date.toLocal())),
                        trailing: w.duration != null
                            ? Text('${w.duration!.inMinutes} min')
                            : null,
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
