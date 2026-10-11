import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/money.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../work/presentation/providers/work_providers.dart';
import '../../../work/domain/work_entry.dart';
import '../../../gym/presentation/providers/gym_providers.dart';
import '../../../clients/domain/client.dart';
import '../../../clients/presentation/providers/client_providers.dart';
import '../../../reminders/domain/reminder.dart';
import '../../../reminders/presentation/providers/notification_provider.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
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
  final _messageController = TextEditingController();
  final List<_ChatTurn> _chat = [];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _loading) return;
    _messageController.clear();
    setState(() {
      _loading = true;
      _error = null;
      _reply = null;
      _chat.add(_ChatTurn(isUser: true, text: message));
    });
    try {
      final reply = await ref.read(assistantServiceProvider).chat(
            message: message,
            history: _chat
                .take(_chat.length - 1)
                .map((turn) => {
                      'role': turn.isUser ? 'user' : 'assistant',
                      'text': turn.text,
                    })
                .toList(growable: false),
            context: _aggregateContext(),
          );
      if (mounted) {
        setState(() {
          _reply = reply;
          _chat.add(_ChatTurn(isUser: false, text: reply.summary));
        });
      }
    } catch (error) {
      if (mounted) {
        final message = error is AssistantServiceException
            ? error.message
            : 'WorkLog AI could not answer just now. Please try again.';
        setState(() {
          _error = message;
          _chat.add(_ChatTurn(isUser: false, text: message));
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmAction(AssistantDraftAction action) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action.domain == 'work' || action.domain == 'reminders'
            ? 'Create ${action.domain == 'work' ? 'work entry' : 'reminder'}?'
            : 'Open ${action.domain}?'),
        content: Text(
            '${action.title}\n\n${action.details}\n\nReview the details before continuing.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    try {
      if (action.domain == 'reminders' && action.operation == 'create') {
        final title = action.fields['title'];
        final rawDate = action.fields['dateTime'] ?? action.fields['date_time'];
        if (title is! String || title.trim().isEmpty || rawDate is! String) {
          throw const FormatException(
              'The reminder needs a title and date/time. Ask WorkLog AI to fill in the missing detail.');
        }
        final dateTime = DateTime.parse(rawDate);
        if (!dateTime.isAfter(DateTime.now())) {
          throw const FormatException(
              'That reminder time has already passed. Ask WorkLog AI for a future time.');
        }
        final reminder = Reminder(
          id: '',
          title: title.trim(),
          description: action.fields['description'] as String?,
          dateTime: dateTime,
          repeat: RepeatOptionX.fromString(action.fields['repeat'] as String?),
          priority: ReminderPriorityX.fromString(
              action.fields['priority'] as String?),
        );
        final id =
            await ref.read(reminderRepositoryProvider).addReminder(reminder);
        final stored = Reminder(
          id: id,
          title: reminder.title,
          description: reminder.description,
          dateTime: reminder.dateTime,
          repeat: reminder.repeat,
          priority: reminder.priority,
        );
        try {
          await ref
              .read(notificationServiceProvider)
              .scheduleForReminder(stored);
        } catch (_) {
          // The reminder itself remains saved; notification settings can be fixed separately.
        }
        ref.invalidate(upcomingRemindersProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reminder “${reminder.title}” was added.')),
          );
        }
        return;
      }

      if (action.domain == 'work' && action.operation == 'create') {
        final taskName = action.fields['taskName'] ??
            action.fields['workType'] ??
            action.title;
        final rawDate = action.fields['date'];
        if (taskName is! String || taskName.trim().isEmpty) {
          throw const FormatException(
              'The work entry needs a task or work type.');
        }
        final date =
            rawDate is String ? DateTime.parse(rawDate) : DateTime.now();
        final clients =
            ref.read(clientsListProvider).valueOrNull ?? const <Client>[];
        final requestedClient = action.fields['clientName'];
        final matching = requestedClient is String
            ? clients
                .where((client) =>
                    client.name.toLowerCase() == requestedClient.toLowerCase())
                .toList()
            : <Client>[];
        final client =
            matching.isNotEmpty ? matching.first : await _chooseClient(clients);
        if (client == null || !mounted) return;
        final hours = action.fields['hoursWorked'];
        final entry = WorkEntry(
          id: '',
          clientId: client.id,
          taskName: taskName.trim(),
          workType: taskName.trim(),
          hoursWorked:
              hours is num ? hours.toDouble().clamp(0, 24).toDouble() : 0,
          date: date,
          notes: action.fields['notes'] as String?,
        );
        await ref.read(workRepositoryProvider).addEntry(entry);
        ref.invalidate(recentWorkEntriesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Work entry for ${client.name} was added.')),
          );
        }
        return;
      }

      final route = switch (action.domain) {
        'gym' => '/gym',
        'nutrition' => '/gym',
        'finance' => '/finance',
        'clients' => '/clients',
        'reminders' => '/reminders',
        'work' => '/work',
        _ => null,
      };
      if (route != null) context.push(route);
    } catch (error) {
      if (!mounted) return;
      final text = error is FormatException
          ? error.message
          : 'Could not complete that action. Your saved data is safe; please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<Client?> _chooseClient(List<Client> clients) async {
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add a client before creating a work entry.')),
      );
      return null;
    }
    return showDialog<Client>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose a client'),
        children: [
          for (final client in clients)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, client),
              child: Text(client.name),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Text('Ask questions or choose a shortcut to get started.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
                const SizedBox(height: 16),
                Text('Suggestions',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AssistantTask.values
                      .map((task) => ChoiceChip(
                            label: Text(task.label),
                            selected: _selectedTask == task,
                            onSelected: _loading
                                ? null
                                : (_) => setState(() {
                                      _selectedTask = task;
                                      _reply = null;
                                      _error = null;
                                    }),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _runTask,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_loading
                      ? 'Thinking…'
                      : (_selectedTask?.label ?? 'Get suggestion')),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Text('Chat', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                if (_chat.isEmpty)
                  const _MessageCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    text:
                        'Ask how to use WorkLog, or request a work entry or reminder.',
                  )
                else
                  for (var index = 0; index < _chat.length; index++)
                    _ChatBubble(turn: _chat[index]),
                if (_error != null && _chat.isEmpty) ...[
                  const SizedBox(height: 12),
                  _MessageCard(icon: Icons.info_outline_rounded, text: _error!),
                ],
                if (_reply != null) ...[
                  if (_chat.isEmpty) ...[
                    const SizedBox(height: 12),
                    _MessageCard(
                        icon: Icons.auto_awesome_rounded,
                        text: _reply!.summary),
                  ],
                  for (final action in _reply!.actions) ...[
                    const SizedBox(height: 10),
                    _DraftCard(
                        action: action,
                        onConfirm: () => _confirmAction(action)),
                  ],
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Ask WorkLog or request an entry…',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Send message',
                    onPressed: _loading ? null : _sendMessage,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                  ),
                ),
              ),
            ),
          ),
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

class _ChatTurn {
  const _ChatTurn({required this.isUser, required this.text});
  final bool isUser;
  final String text;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.turn});
  final _ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: turn.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: turn.isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          turn.text,
          style: TextStyle(
            color: turn.isUser ? scheme.onPrimaryContainer : scheme.onSurface,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.action, required this.onConfirm});
  final AssistantDraftAction action;
  final VoidCallback onConfirm;

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
              onPressed: onConfirm,
              icon: Icon(action.domain == 'work' || action.domain == 'reminders'
                  ? Icons.check_rounded
                  : Icons.open_in_new_rounded),
              label: Text(
                  action.domain == 'work' || action.domain == 'reminders'
                      ? 'Confirm and create'
                      : 'Open in app'),
            ),
          ]),
        ),
      );
}
