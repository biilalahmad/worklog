import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/diet_target.dart';
import '../../domain/meal_entry.dart';
import '../../domain/water_log.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_loading_placeholder.dart';

class DietTab extends ConsumerWidget {
  const DietTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mealsAsync = ref.watch(mealsForDateProvider(today));
    final targetAsync = ref.watch(dietTargetProvider);
    final waterAsync = ref.watch(waterLogsForDateProvider(today));
    final pageError = mealsAsync.hasError
        ? mealsAsync.error
        : targetAsync.hasError
            ? targetAsync.error
            : waterAsync.hasError
                ? waterAsync.error
                : null;
    if (pageError != null) {
      return ErrorView(
        message: Failure.from(pageError).message,
        onRetry: () {
          ref.invalidate(mealsForDateProvider(today));
          ref.invalidate(dietTargetProvider);
          ref.invalidate(waterLogsForDateProvider(today));
        },
      );
    }

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            176 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text("Today's Nutrition",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            mealsAsync.when(
              loading: () => const GymLoadingPlaceholder(rows: 1),
              error: (_, __) => const SizedBox.shrink(),
              data: (meals) => targetAsync.when(
                loading: () => const GymLoadingPlaceholder(rows: 1),
                error: (_, __) => const SizedBox.shrink(),
                data: (target) => _MacroSummary(meals: meals, target: target),
              ),
            ),
            const SizedBox(height: 18),
            _HydrationCard(logsAsync: waterAsync),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Meals Today',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () => targetAsync
                      .whenData((t) => _editTargetDialog(context, ref, t)),
                  child: const Text('Edit target'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            mealsAsync.when(
              loading: () => const GymLoadingPlaceholder(rows: 2),
              error: (_, __) => const SizedBox.shrink(),
              data: (meals) {
                if (meals.isEmpty) {
                  return const EmptyState(
                    icon: Icons.restaurant_outlined,
                    title: 'No meals logged today',
                    subtitle: 'Tap Add Meal below to log what you ate.',
                  );
                }
                final grouped = <MealType, List<MealEntry>>{};
                for (final m in meals) {
                  grouped.putIfAbsent(m.mealType, () => []).add(m);
                }
                return Column(
                  children:
                      MealType.values.where(grouped.containsKey).map((type) {
                    final items = grouped[type]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(type.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 6),
                          SectionCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Column(
                              children: items
                                  .map((m) => Dismissible(
                                        key: ValueKey(m.id),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding:
                                              const EdgeInsets.only(right: 16),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .errorContainer,
                                          child:
                                              const Icon(Icons.delete_outline),
                                        ),
                                        onDismissed: (_) => ref
                                            .read(dietRepositoryProvider)
                                            .deleteMeal(m.id),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(m.foodName),
                                          subtitle: Text(
                                              '${m.calories.toStringAsFixed(0)} kcal'),
                                          trailing: Text(
                                            'P${m.protein.toStringAsFixed(0)} C${m.carbs.toStringAsFixed(0)} F${m.fat.toStringAsFixed(0)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
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
          bottom: 16 + MediaQuery.paddingOf(context).bottom,
          child: FloatingActionButton.extended(
            heroTag: 'newMeal',
            onPressed: () => context.push('/gym/meal/new'),
            icon: const Icon(Icons.add),
            label: const Text('Add Meal'),
          ),
        ),
      ],
    );
  }

  void _editTargetDialog(
      BuildContext context, WidgetRef ref, DietTarget current) {
    final calCtrl =
        TextEditingController(text: current.dailyCalories.toStringAsFixed(0));
    final proCtrl =
        TextEditingController(text: current.dailyProtein.toStringAsFixed(0));
    final carbCtrl =
        TextEditingController(text: current.dailyCarbs.toStringAsFixed(0));
    final fatCtrl =
        TextEditingController(text: current.dailyFat.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Target'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calories')),
            const SizedBox(height: 12),
            TextField(
                controller: proCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Protein (g)')),
            const SizedBox(height: 12),
            TextField(
                controller: carbCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Carbs (g)')),
            const SizedBox(height: 12),
            TextField(
                controller: fatCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fat (g)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(dietRepositoryProvider).saveDietTarget(DietTarget(
                    dailyCalories:
                        double.tryParse(calCtrl.text) ?? current.dailyCalories,
                    dailyProtein:
                        double.tryParse(proCtrl.text) ?? current.dailyProtein,
                    dailyCarbs:
                        double.tryParse(carbCtrl.text) ?? current.dailyCarbs,
                    dailyFat: double.tryParse(fatCtrl.text) ?? current.dailyFat,
                  ));
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _HydrationCard extends ConsumerWidget {
  const _HydrationCard({required this.logsAsync});
  final AsyncValue<List<WaterLog>> logsAsync;

  static const _dailyGoalMl = 2000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheme = Theme.of(context).colorScheme;
    return logsAsync.when(
      loading: () => const GymLoadingPlaceholder(rows: 1),
      error: (error, _) => SectionCard(
        child: Row(children: [
          const Icon(Icons.water_drop_outlined),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  'Hydration unavailable: ${Failure.from(error).message}')),
        ]),
      ),
      data: (logs) {
        final total = logs.fold<int>(0, (sum, log) => sum + log.milliliters);
        final progress = (total / _dailyGoalMl).clamp(0.0, 1.0);
        return SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.water_drop_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Water today',
                        style: TextStyle(fontWeight: FontWeight.w800))),
                Text('${(total / 1000).toStringAsFixed(1)} / 2.0 L',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 450),
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    color: scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [250, 500, 750]
                    .map((ml) => ActionChip(
                          avatar: Icon(Icons.add_rounded,
                              size: 17, color: scheme.onPrimaryContainer),
                          label: Text('+${ml}ml'),
                          labelStyle: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700),
                          backgroundColor: scheme.primaryContainer,
                          side: BorderSide(
                              color: scheme.primary.withValues(alpha: .35)),
                          onPressed: () async {
                            try {
                              await ref
                                  .read(dietRepositoryProvider)
                                  .addWaterLog(ml, today);
                              ref.invalidate(waterLogsForDateProvider(today));
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(Failure.save(e).message)),
                                );
                              }
                            }
                          },
                        ))
                    .toList(),
              ),
              if (logs.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      try {
                        await ref
                            .read(dietRepositoryProvider)
                            .deleteWaterLog(logs.first.id);
                        ref.invalidate(waterLogsForDateProvider(today));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(Failure.save(e).message)),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.undo_rounded, size: 17),
                    label: const Text('Undo last'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MacroSummary extends StatelessWidget {
  final List<MealEntry> meals;
  final DietTarget target;
  const _MacroSummary({required this.meals, required this.target});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cal = meals.fold(0.0, (s, m) => s + m.calories);
    final pro = meals.fold(0.0, (s, m) => s + m.protein);
    final carb = meals.fold(0.0, (s, m) => s + m.carbs);
    final fat = meals.fold(0.0, (s, m) => s + m.fat);
    final remaining = (target.dailyCalories - cal).clamp(0, double.infinity);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: SectionCard(
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
                        '${cal.toStringAsFixed(0)} / ${target.dailyCalories.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18)),
                    Text('${remaining.toStringAsFixed(0)} kcal remaining',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (cal / target.dailyCalories).clamp(0, 1),
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _MacroBar(
                        label: 'Protein',
                        value: pro,
                        target: target.dailyProtein,
                        color: Colors.blue)),
                const SizedBox(width: 10),
                Expanded(
                    child: _MacroBar(
                        label: 'Carbs',
                        value: carb,
                        target: target.dailyCarbs,
                        color: Colors.orange)),
                const SizedBox(width: 10),
                Expanded(
                    child: _MacroBar(
                        label: 'Fat',
                        value: fat,
                        target: target.dailyFat,
                        color: Colors.purple)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;
  const _MacroBar(
      {required this.label,
      required this.value,
      required this.target,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${value.toStringAsFixed(0)}g',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text('$label / ${target.toStringAsFixed(0)}g',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: target == 0 ? 0 : (value / target).clamp(0, 1),
            minHeight: 5,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}
