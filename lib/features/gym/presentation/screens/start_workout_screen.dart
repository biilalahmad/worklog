import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/workout.dart';
import '../../domain/exercise.dart';
import '../../domain/workout_routine.dart';
import '../providers/gym_providers.dart';
import '../widgets/exercise_picker_field.dart';

class _SessionExercise {
  final String exerciseId;
  final String exerciseName;
  final List<_SessionSet> sets;
  _SessionExercise({
    required this.exerciseId,
    required this.exerciseName,
    int targetSets = 1,
    int? targetReps,
  }) : sets = List.generate(
          targetSets.clamp(1, 30),
          (_) => _SessionSet(initialReps: targetReps),
        );
}

class _SessionSet {
  _SessionSet({int? initialReps}) {
    if (initialReps != null) repsCtrl.text = '$initialReps';
  }

  final repsCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  SetType type = SetType.normal;
  double? rpe;
  bool saved = false;
  String? savedId;
}

/// Active workout logging. A `workouts` row is created immediately on
/// open so nothing is lost if the app closes mid-session; each set is
/// saved the moment it's confirmed (not batched at the end).
class StartWorkoutScreen extends ConsumerStatefulWidget {
  final String? routineId;
  const StartWorkoutScreen({super.key, this.routineId});

  @override
  ConsumerState<StartWorkoutScreen> createState() => _StartWorkoutScreenState();
}

class _StartWorkoutScreenState extends ConsumerState<StartWorkoutScreen> {
  String? _workoutId;
  DateTime? _startedAt;
  final List<_SessionExercise> _exercises = [];
  bool _initializing = true;
  String? _initError;
  bool _addingExercise = false;
  bool _finishing = false;
  Timer? _restTimer;
  int _restSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      var routineItems = const <RoutineExercise>[];
      var exercises = ref.read(exercisesListProvider).valueOrNull;
      if (widget.routineId != null) {
        exercises ??= await ref
            .read(exercisesListProvider.future)
            .timeout(const Duration(seconds: 12));
        routineItems = await ref
            .read(routineRepositoryProvider)
            .watchRoutineExercises(widget.routineId!)
            .first
            .timeout(const Duration(seconds: 12));
      }
      String? routineName;
      if (widget.routineId != null) {
        for (final routine
            in ref.read(routinesListProvider).valueOrNull ?? const []) {
          if (routine.id == widget.routineId) {
            routineName = routine.name;
            break;
          }
        }
      }
      final startedAt = DateTime.now();
      final id = await ref.read(workoutRepositoryProvider).addWorkout(Workout(
            id: '',
            routineId: widget.routineId,
            name: routineName ?? 'Workout',
            date: startedAt,
            startedAt: startedAt,
          ));
      for (final item in routineItems) {
        final matches = exercises!.where((e) => e.id == item.exerciseId);
        if (matches.isNotEmpty) {
          _exercises.add(_SessionExercise(
            exerciseId: item.exerciseId,
            exerciseName: matches.first.name,
            targetSets: item.targetSets,
            targetReps: item.targetReps,
          ));
        }
      }
      if (mounted) {
        setState(() {
          _workoutId = id;
          _startedAt = startedAt;
          _initializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = Failure.from(e).message;
          _initializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    for (final ex in _exercises) {
      for (final s in ex.sets) {
        s.repsCtrl.dispose();
        s.weightCtrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _addExercise(String name) async {
    if (_addingExercise) return;
    setState(() => _addingExercise = true);
    try {
      final known = ref.read(exercisesListProvider).valueOrNull ?? const [];
      Exercise? match;
      for (final exercise in known) {
        if (exercise.name.toLowerCase() == name.trim().toLowerCase()) {
          match = exercise;
          break;
        }
      }
      final id = match?.id ??
          await ref.read(exerciseRepositoryProvider).addExercise(Exercise(
                id: '',
                name: name.trim(),
                muscleGroup: MuscleGroup.other,
                equipment: '',
              ));
      if (!mounted || _exercises.any((item) => item.exerciseId == id)) return;
      setState(() {
        _exercises
            .add(_SessionExercise(exerciseId: id, exerciseName: name.trim()));
        _exercises.last.sets.add(_SessionSet());
      });
      ref.invalidate(exercisesListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.save(e).message)));
      }
    } finally {
      if (mounted) setState(() => _addingExercise = false);
    }
  }

  void _addSet(_SessionExercise ex) {
    final last = ex.sets.isNotEmpty ? ex.sets.last : null;
    final s = _SessionSet();
    if (last != null) {
      s.repsCtrl.text = last.repsCtrl.text;
      s.weightCtrl.text = last.weightCtrl.text;
      s.type = SetType.normal;
    }
    setState(() => ex.sets.add(s));
  }

  Future<void> _confirmSet(_SessionExercise ex, _SessionSet s) async {
    if (_workoutId == null) return;
    final reps = int.tryParse(s.repsCtrl.text.trim()) ?? 0;
    final weight = double.tryParse(s.weightCtrl.text.trim()) ?? 0;
    try {
      final setNumber = ex.sets.indexOf(s) + 1;
      final id = await ref.read(workoutRepositoryProvider).addSet(WorkoutSet(
            id: '',
            workoutId: _workoutId!,
            exerciseId: ex.exerciseId,
            setNumber: setNumber,
            reps: reps,
            weight: weight,
            setType: s.type,
            rpe: s.rpe,
          ));
      setState(() {
        s.saved = true;
        s.savedId = id;
      });
      _startRestTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.from(e).message)));
      }
    }
  }

  void _startRestTimer({int seconds = 90}) {
    _restTimer?.cancel();
    setState(() => _restSecondsLeft = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restSecondsLeft <= 1) {
        t.cancel();
        setState(() => _restSecondsLeft = 0);
      } else {
        setState(() => _restSecondsLeft--);
      }
    });
  }

  Future<void> _finish() async {
    if (_workoutId == null) return;
    setState(() => _finishing = true);
    try {
      await ref.read(workoutRepositoryProvider).updateWorkout(Workout(
            id: _workoutId!,
            routineId: widget.routineId,
            date: DateTime.now(),
            startedAt: _startedAt,
            completedAt: DateTime.now(),
          ));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exercisesAsync = ref.watch(exercisesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Workout'),
        actions: [
          TextButton(
            onPressed: _finishing || _exercises.isEmpty ? null : _finish,
            child: _finishing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Finish'),
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _initError != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_initError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _initError = null;
                                _initializing = true;
                              });
                              _init();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry')),
                      ])))
              : Column(
                  children: [
                    if (_restSecondsLeft > 0)
                      _RestBanner(
                          seconds: _restSecondsLeft,
                          onSkip: () {
                            _restTimer?.cancel();
                            setState(() => _restSecondsLeft = 0);
                          }),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                        children: [
                          exercisesAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text(Failure.from(e).message),
                            data: (exercises) => ExercisePickerField(
                              exercises: exercises,
                              onSelectedOrCreate: _addExercise,
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (final ex in _exercises)
                            _ExerciseSessionCard(
                              exercise: ex,
                              onAddSet: () => _addSet(ex),
                              onConfirmSet: (s) => _confirmSet(ex, s),
                              onRemoveSet: (s) =>
                                  setState(() => ex.sets.remove(s)),
                            ),
                          if (_exercises.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'Add an exercise above to start logging sets.',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _RestBanner extends StatelessWidget {
  final int seconds;
  final VoidCallback onSkip;
  const _RestBanner({required this.seconds, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return Material(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Rest: $m:${s.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseSessionCard extends ConsumerWidget {
  final _SessionExercise exercise;
  final VoidCallback onAddSet;
  final ValueChanged<_SessionSet> onConfirmSet;
  final ValueChanged<_SessionSet> onRemoveSet;

  const _ExerciseSessionCard({
    required this.exercise,
    required this.onAddSet,
    required this.onConfirmSet,
    required this.onRemoveSet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lastSetsAsync =
        ref.watch(lastSetsForExerciseProvider(exercise.exerciseId));

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.exerciseName,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            lastSetsAsync.maybeWhen(
              data: (sets) {
                if (sets.isEmpty) return const SizedBox.shrink();
                final top = sets.first;
                return Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Previous: ${top.reps} reps @ ${top.weight.toStringAsFixed(1)} ${top.weightUnit}',
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            if (exercise.sets.isNotEmpty)
              const Row(
                children: [
                  SizedBox(
                      width: 28,
                      child: Text('Set',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600))),
                  Expanded(
                      child: Text('Reps',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600))),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text('Weight',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600))),
                  SizedBox(width: 76),
                ],
              ),
            for (int i = 0; i < exercise.sets.length; i++)
              _SetRow(
                index: i + 1,
                set: exercise.sets[i],
                onConfirm: () => onConfirmSet(exercise.sets[i]),
                onRemove: () => onRemoveSet(exercise.sets[i]),
              ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Set'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  final int index;
  final _SessionSet set;
  final VoidCallback onConfirm;
  final VoidCallback onRemove;
  const _SetRow(
      {required this.index,
      required this.set,
      required this.onConfirm,
      required this.onRemove});

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  void _cycleType() {
    const values = SetType.values;
    final next = values[(widget.set.type.index + 1) % values.length];
    setState(() => widget.set.type = next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = widget.set;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${widget.index}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: TextField(
              controller: s.repsCtrl,
              enabled: !s.saved,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: s.weightCtrl,
              enabled: !s.saved,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
          SizedBox(
            width: 76,
            child: Row(
              children: [
                if (!s.saved)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(_typeIcon(s.type),
                        size: 16, color: scheme.primary),
                    tooltip: s.type.label,
                    onPressed: _cycleType,
                  ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    s.saved
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline,
                    color: s.saved ? Colors.green : scheme.onSurfaceVariant,
                    size: 22,
                  ),
                  onPressed: s.saved ? null : widget.onConfirm,
                ),
                if (!s.saved)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(SetType t) {
    switch (t) {
      case SetType.warmup:
        return Icons.wb_sunny_outlined;
      case SetType.drop:
        return Icons.south_rounded;
      case SetType.failure:
        return Icons.warning_amber_rounded;
      case SetType.superset:
        return Icons.link_rounded;
      case SetType.normal:
        return Icons.circle_outlined;
    }
  }
}
