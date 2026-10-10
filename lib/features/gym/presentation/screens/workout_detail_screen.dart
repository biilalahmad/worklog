import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/workout.dart';
import '../providers/gym_providers.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  final String workoutId;
  const WorkoutDetailScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutAsync = ref.watch(workoutDetailProvider(workoutId));
    final exercisesAsync = ref.watch(exercisesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: workoutAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(message: Failure.from(e).message),
        data: (workout) {
          if (workout == null)
            return const Center(child: Text('Workout not found.'));
          final exerciseNames = exercisesAsync.valueOrNull ?? const [];
          String nameFor(String id) {
            final match = exerciseNames.where((e) => e.id == id);
            return match.isEmpty ? 'Exercise' : match.first.name;
          }

          final byExercise = <String, List<WorkoutSet>>{};
          for (final s in workout.sets) {
            byExercise.putIfAbsent(s.exerciseId, () => []).add(s);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE, MMM d, yyyy').format(workout.date),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (workout.duration != null)
                          Text('${workout.duration!.inMinutes} min  ·  '),
                        Text(
                            'Volume: ${workout.totalVolume.toStringAsFixed(0)} kg'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final entry in byExercise.entries) ...[
                Text(nameFor(entry.key),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 6),
                SectionCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: entry.value
                        .map((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  SizedBox(
                                      width: 28, child: Text('${s.setNumber}')),
                                  Expanded(child: Text('${s.reps} reps')),
                                  Expanded(
                                      child: Text(
                                          '${s.weight.toStringAsFixed(1)} ${s.weightUnit}')),
                                  if (s.setType.asString != 'normal')
                                    Text(s.setType.label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (workout.notes != null && workout.notes!.isNotEmpty) ...[
                Text('Notes', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                SectionCard(child: Text(workout.notes!)),
              ],
            ],
          );
        },
      ),
    );
  }
}
