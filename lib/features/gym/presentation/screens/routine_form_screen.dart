import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/exercise.dart';
import '../../domain/workout_routine.dart';
import '../providers/gym_providers.dart';
import '../widgets/exercise_picker_field.dart';

/// Create a routine, then add exercises to it one at a time. Kept as
/// two steps (create → add exercises) rather than one big form so the
/// routine exists (and is savable) the moment it's named.
class RoutineFormScreen extends ConsumerStatefulWidget {
  final String? routineId;
  const RoutineFormScreen({super.key, this.routineId});

  @override
  ConsumerState<RoutineFormScreen> createState() => _RoutineFormScreenState();
}

class _RoutineFormScreenState extends ConsumerState<RoutineFormScreen> {
  final _nameCtrl = TextEditingController();
  String? _routineId;
  bool _saving = false;
  bool _addingExercise = false;
  final _targetSetsCtrl = TextEditingController(text: '3');
  final _targetRepsCtrl = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _routineId = widget.routineId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetSetsCtrl.dispose();
    _targetRepsCtrl.dispose();
    super.dispose();
  }

  Future<void> _createRoutine() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(routineRepositoryProvider)
          .addRoutine(WorkoutRoutine(id: '', name: name));
      if (mounted) setState(() => _routineId = id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addExercise(String name) async {
    final routineId = _routineId;
    if (routineId == null || _addingExercise) return;
    setState(() => _addingExercise = true);
    try {
      final saved = ref.read(exercisesListProvider).valueOrNull ?? const [];
      Exercise? exercise;
      for (final item in saved) {
        if (item.name.toLowerCase() == name.trim().toLowerCase()) {
          exercise = item;
          break;
        }
      }
      final exId = exercise?.id ??
          await ref.read(exerciseRepositoryProvider).addExercise(Exercise(
                id: '',
                name: name.trim(),
                muscleGroup: MuscleGroup.other,
                equipment: '',
              ));
      final current =
          ref.read(routineExercisesProvider(routineId)).valueOrNull ?? const [];
      if (current.any((item) => item.exerciseId == exId)) return;
      await ref.read(routineRepositoryProvider).addRoutineExercise(
            RoutineExercise(
              id: '',
              routineId: routineId,
              exerciseId: exId,
              targetSets: int.tryParse(_targetSetsCtrl.text.trim()) ?? 3,
              targetReps: int.tryParse(_targetRepsCtrl.text.trim()) ?? 10,
              orderIndex: current.length,
            ),
          );
      ref.invalidate(exercisesListProvider);
      ref.invalidate(routineExercisesProvider(routineId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Failure.save(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _addingExercise = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesListProvider);

    return Scaffold(
      appBar: AppBar(
          title: Text(_routineId == null ? 'New Routine' : 'Edit Routine')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_routineId == null) ...[
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Routine name', hintText: 'e.g. Push Day'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _createRoutine,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create & add exercises'),
            ),
          ] else ...[
            exercisesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(Failure.from(e).message),
              data: (exercises) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExercisePickerField(
                    exercises: exercises,
                    onSelectedOrCreate: _addExercise,
                  ),
                  if (_addingExercise) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 4),
                    Text('Saving exercise…',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Default for each exercise',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetSetsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sets'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _targetRepsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Reps'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                'These targets prefill your daily workout log; confirm each set to save it.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final reAsync =
                    ref.watch(routineExercisesProvider(_routineId!));
                final exAsync = ref.watch(exercisesListProvider);
                return reAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text(Failure.from(e).message),
                  data: (routineExercises) {
                    final exNames = exAsync.valueOrNull ?? const [];
                    String nameFor(String id) {
                      final m = exNames.where((e) => e.id == id);
                      return m.isEmpty ? 'Exercise' : m.first.name;
                    }

                    if (routineExercises.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                            'Add exercises to this routine using the field above.'),
                      );
                    }
                    return Column(
                      children: routineExercises
                          .map((re) => Card(
                                child: ListTile(
                                  title: Text(nameFor(re.exerciseId)),
                                  subtitle: Text(
                                      '${re.targetSets} sets × ${re.targetReps} reps'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20),
                                    onPressed: () => ref
                                        .read(routineRepositoryProvider)
                                        .deleteRoutineExercise(re.id),
                                  ),
                                ),
                              ))
                          .toList(),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
