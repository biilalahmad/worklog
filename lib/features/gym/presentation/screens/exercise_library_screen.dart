import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/exercise.dart';
import '../providers/gym_providers.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  static const _popularExercises = <(String, MuscleGroup, String)>[
    ('Push-up', MuscleGroup.chest, 'Bodyweight'),
    ('Bench Press', MuscleGroup.chest, 'Barbell'),
    ('Dumbbell Row', MuscleGroup.back, 'Dumbbell'),
    ('Lat Pulldown', MuscleGroup.back, 'Cable'),
    ('Squat', MuscleGroup.legs, 'Bodyweight'),
    ('Goblet Squat', MuscleGroup.legs, 'Dumbbell'),
    ('Shoulder Press', MuscleGroup.shoulders, 'Dumbbell'),
    ('Biceps Curl', MuscleGroup.arms, 'Dumbbell'),
    ('Plank', MuscleGroup.core, 'Bodyweight'),
    ('Jumping Jacks', MuscleGroup.cardio, 'Bodyweight'),
  ];

  String _query = '';
  MuscleGroup? _filter;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _addSuggestion(
      String name, MuscleGroup group, String equipment) async {
    try {
      final saved = ref.read(exercisesListProvider).valueOrNull ?? const [];
      if (!saved.any(
          (exercise) => exercise.name.toLowerCase() == name.toLowerCase())) {
        await ref.read(exerciseRepositoryProvider).addExercise(Exercise(
              id: '',
              name: name,
              muscleGroup: group,
              equipment: equipment,
            ));
        ref.invalidate(exercisesListProvider);
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name added to your library')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.save(error).message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesListProvider);
    final remoteAsync = _query.length >= 2
        ? ref.watch(wgerExerciseSearchProvider(_query))
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Library')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) setState(() => _query = v.trim().toLowerCase());
                });
              },
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                    label: 'All',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null)),
                for (final g in MuscleGroup.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _FilterChip(
                      label: g.label,
                      selected: _filter == g,
                      onTap: () => setState(() => _filter = g),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: exercisesAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => ErrorView(message: Failure.from(e).message),
              data: (exercises) {
                final filtered = exercises.where((e) {
                  if (_filter != null && e.muscleGroup != _filter) return false;
                  if (_query.isNotEmpty &&
                      !e.name.toLowerCase().contains(_query)) return false;
                  return true;
                }).toList();
                final popular = _popularExercises.where((entry) {
                  final matchesQuery =
                      _query.isEmpty || entry.$1.toLowerCase().contains(_query);
                  final matchesFilter = _filter == null || _filter == entry.$2;
                  final alreadySaved = exercises.any((exercise) =>
                      exercise.name.toLowerCase() == entry.$1.toLowerCase());
                  return matchesQuery && matchesFilter && !alreadySaved;
                }).toList();
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (filtered.isNotEmpty) ...[
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('My library',
                              style: TextStyle(fontWeight: FontWeight.w800))),
                      for (final e in filtered)
                        _ExerciseTile(
                            name: e.name,
                            subtitle: e.equipment.isEmpty
                                ? e.muscleGroup.label
                                : '${e.muscleGroup.label} · ${e.equipment}'),
                    ],
                    if (_query.length < 2 && popular.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.only(
                            top: filtered.isEmpty ? 8 : 16, bottom: 8),
                        child: Text(
                          filtered.isEmpty ? 'Popular exercises' : 'Try these',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      for (final entry in popular)
                        _ExerciseTile(
                          name: entry.$1,
                          subtitle: '${entry.$2.label} · ${entry.$3}',
                          onAdd: () =>
                              _addSuggestion(entry.$1, entry.$2, entry.$3),
                        ),
                    ],
                    if (_query.length >= 2) ...[
                      const Padding(
                          padding: EdgeInsets.only(top: 14, bottom: 8),
                          child: Text('More exercises',
                              style: TextStyle(fontWeight: FontWeight.w800))),
                      remoteAsync!.when(
                        loading: () => const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator())),
                        error: (_, __) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                    'Online suggestions are unavailable. Your saved exercises still work offline.'),
                                TextButton.icon(
                                  onPressed: () => ref.invalidate(
                                      wgerExerciseSearchProvider(_query)),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                ),
                              ],
                            )),
                        data: (items) {
                          final savedNames = exercises
                              .map((exercise) => exercise.name.toLowerCase())
                              .toSet();
                          final suggestions = items
                              .where((item) =>
                                  !savedNames.contains(item.name.toLowerCase()))
                              .toList();
                          return suggestions.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text('No online suggestions found.'))
                              : Column(
                                  children: items
                                      .where((item) => !savedNames
                                          .contains(item.name.toLowerCase()))
                                      .map((item) => _ExerciseTile(
                                          name: item.name,
                                          subtitle: item.equipment.isEmpty
                                              ? item.muscleGroup.label
                                              : '${item.muscleGroup.label} · ${item.equipment}',
                                          onAdd: () => _addSuggestion(
                                              item.name,
                                              item.muscleGroup,
                                              item.equipment)))
                                      .toList());
                        },
                      ),
                    ],
                    if (_query.length >= 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          'Online exercise suggestions are provided by wger; exercise descriptions are shared under CC BY-SA.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.name, required this.subtitle, this.onAdd});
  final String name;
  final String subtitle;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fitness_center_rounded),
            title:
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle),
            trailing: onAdd == null
                ? null
                : TextButton(onPressed: onAdd, child: const Text('Add')),
          ),
        ),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: scheme.primaryContainer,
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide(color: scheme.outlineVariant),
    );
  }
}
