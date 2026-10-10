import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/money.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
import '../../../work/presentation/providers/work_providers.dart';
import '../../../work/domain/work_entry.dart';
import '../../../gym/presentation/providers/gym_providers.dart';
import '../../domain/assistant_contract.dart';
import '../../data/assistant_service.dart';
import '../providers/assistant_providers.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.initialAgent});
  final AssistantAgent? initialAgent;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  AssistantTask? _selectedTask;
  AssistantReply? _reply;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedTask = AssistantTask.values.firstWhere(
      (task) => task.agent == widget.initialAgent,
      orElse: () => AssistantTask.workReview,
    );
  }

  Map<String, Object?> _aggregateContext() {
    final now = DateTime.now();
    final monthRange = DateRange(DateTime(now.year, now.month), now);
    final work =
        ref.read(workEntriesForRangeProvider(monthRange)).valueOrNull ??
            const [];
    final income =
        ref.read(incomeForRangeProvider(monthRange)).valueOrNull ?? const [];
    final expenses =
        ref.read(expensesForRangeProvider(monthRange)).valueOrNull ?? const [];
    final reminders =
        ref.read(upcomingRemindersProvider).valueOrNull ?? const [];
    final profile = ref.read(profileProvider).valueOrNull;
    final currency = profile?.defaultCurrency ?? 'PKR';
    final workouts = ref
            .read(workoutsForRangeProvider(
                GymDateRange(DateTime(now.year, now.month), now)))
            .valueOrNull ??
        const [];
    final meals = ref
            .read(mealsForDateProvider(DateTime(now.year, now.month, now.day)))
            .valueOrNull ??
        const [];
    return {
      'work': {
        'entriesThisMonth': work.length,
        'completedThisMonth': work
            .where((entry) =>
                entry.status == WorkStatus.completed ||
                entry.status == WorkStatus.delivered)
            .length,
        'hoursThisMonth':
            work.fold<double>(0, (sum, entry) => sum + entry.hoursWorked),
        'videosThisMonth':
            work.fold<int>(0, (sum, entry) => sum + entry.videoCount),
      },
      'finance': {
        'currencyCode': currency,
        'incomeThisMonth': income
            .where((item) => item.currency == currency)
            .fold<double>(
                0,
                (sum, item) =>
                    sum + Money(item.amountMinor, currency).asDouble),
        'expensesThisMonth': expenses
            .where((item) => item.currency == currency)
            .fold<double>(
                0,
                (sum, item) =>
                    sum + Money(item.amountMinor, currency).asDouble),
      },
      'reminders': {'upcomingCount': reminders.length},
      'gym': {
        'workoutsThisMonth': workouts.length,
        'workoutStreak': ref.read(workoutStreakProvider),
        'mealsToday': meals.length,
        'caloriesToday':
            meals.fold<double>(0, (sum, meal) => sum + meal.calories),
        'calorieTarget':
            ref.read(dietTargetProvider).valueOrNull?.dailyCalories ?? 0,
      },
    };
  }

  Future<void> _runTask() async {
    final task = _selectedTask;
    if (task == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _reply = null;
    });
    try {
      final reply = await ref.read(assistantServiceProvider).runTask(
            task: task,
            context: _aggregateContext(),
          );
      if (mounted) setState(() => _reply = reply);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is AssistantServiceException
            ? error.message
            : 'The assistant is temporarily unavailable. Your saved data is safe.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enableAndRun() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable WorkLog AI?'),
        content: const Text(
            'For your selected task, WorkLog sends a fixed task selection and aggregated, non-identifying metrics to Google Gemini. It does not send free-text prompts, client details, notes, or transaction rows. Google’s AI terms apply. You can turn AI off anytime in Profile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable and continue')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    await ref.read(assistantConsentControllerProvider).setEnabled(true);
    await _runTask();
  }

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(assistantConsentProvider);
    final now = DateTime.now();
    final monthRange = DateRange(DateTime(now.year, now.month), now);
    ref.watch(workEntriesForRangeProvider(monthRange));
    ref.watch(incomeForRangeProvider(monthRange));
    ref.watch(expensesForRangeProvider(monthRange));
    ref.watch(upcomingRemindersProvider);
    ref.watch(workoutsForRangeProvider(
        GymDateRange(DateTime(now.year, now.month), now)));
    ref.watch(mealsForDateProvider(DateTime(now.year, now.month, now.day)));
    ref.watch(dietTargetProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask WorkLog'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Focused help, using only your aggregated app metrics.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          if (consent.valueOrNull != true) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: scheme.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                          'AI suggestions use Google Gemini. Only the selected task and aggregated metrics are shared; you can opt out anytime in Profile.'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AssistantTask.values
                  .map((task) => ChoiceChip(
                        label: Text(task.label),
                        selected: _selectedTask == task,
                        onSelected: (_) => setState(() {
                          _selectedTask = task;
                          _reply = null;
                          _error = null;
                        }),
                      ))
                  .toList()),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading
                ? null
                : (consent.valueOrNull == true ? _runTask : _enableAndRun),
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_loading
                ? 'Thinking…'
                : consent.valueOrNull == true
                    ? 'Get suggestion'
                    : 'Enable AI & get suggestion'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _MessageCard(icon: Icons.info_outline_rounded, text: _error!),
          ],
          if (_reply != null) ...[
            const SizedBox(height: 20),
            _MessageCard(
                icon: Icons.auto_awesome_rounded, text: _reply!.summary),
            for (final action in _reply!.actions) ...[
              const SizedBox(height: 10),
              _DraftCard(action: action),
            ],
          ],
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ]),
      ));
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.action});
  final AssistantDraftAction action;

  String? get _route => switch (action.domain) {
        'gym' => '/gym/routines/new',
        'nutrition' => '/gym/meal/new',
        'work' => '/work/new',
        'finance' => '/finance/expense/new',
        'clients' => '/clients/new',
        'reminders' => '/reminders/new',
        _ => null,
      };

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Draft · ${action.operation}',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(action.title, style: Theme.of(context).textTheme.titleMedium),
            if (action.details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(action.details)
            ],
            if (action.fields.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final entry in action.fields.entries.take(8))
                Text('${entry.key}: ${entry.value}',
                    style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _route == null ? null : () => context.push(_route!),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Review in app before saving'),
            ),
          ]),
        ),
      );
}
