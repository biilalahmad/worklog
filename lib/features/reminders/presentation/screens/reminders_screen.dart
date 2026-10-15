import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_fab.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../domain/reminder.dart';
import '../providers/notification_provider.dart';
import '../providers/reminder_providers.dart';
import '../../../assistant/domain/assistant_contract.dart';
import '../../../assistant/presentation/widgets/assistant_entry.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen>
    with WidgetsBindingObserver {
  bool? _notificationsEnabled;
  Timer? _expiryRefresh;
  bool _openedNotificationTarget = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _expiryRefresh = Timer.periodic(const Duration(minutes: 1), (_) {
      ref.invalidate(upcomingRemindersProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryRefresh?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final enabled =
        await ref.read(notificationServiceProvider).areNotificationsEnabled();
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(upcomingRemindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: const [
          AssistantShortcutButton(agent: AssistantAgent.reminders)
        ],
      ),
      floatingActionButton: AppFab(
        tooltip: 'Add reminder',
        aboveNavigation: false,
        onPressed: () => context.push('/reminders/new'),
      ),
      body: Column(
        children: [
          if (_notificationsEnabled == false)
            _PermissionBanner(onEnable: () async {
              await ref
                  .read(notificationServiceProvider)
                  .openNotificationSettings();
            }),
          Expanded(
            child: remindersAsync.when(
              loading: () => const AppListSkeleton(),
              error: (e, _) => ErrorView(message: Failure.from(e).message),
              data: (reminders) {
                final targetId =
                    GoRouterState.of(context).uri.queryParameters['open'];
                if (!_openedNotificationTarget && targetId != null) {
                  final matching =
                      reminders.where((item) => item.id == targetId);
                  if (matching.isNotEmpty) {
                    final target = matching.first;
                    _openedNotificationTarget = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        context.push('/reminders/$targetId/edit',
                            extra: target);
                      }
                    });
                  }
                }
                if (reminders.isEmpty) {
                  return const EmptyState(
                    icon: Icons.notifications_none,
                    title: 'No reminders yet',
                    subtitle: 'Tap + to add your first reminder.',
                  );
                }
                final now = DateTime.now();
                DateTime due(Reminder reminder) => reminder.nextOccurrence(now);
                final overdue =
                    reminders.where((r) => due(r).isBefore(now)).toList();
                final today = reminders
                    .where((r) =>
                        !due(r).isBefore(now) &&
                        due(r).year == now.year &&
                        due(r).month == now.month &&
                        due(r).day == now.day)
                    .toList();
                final tomorrowDate = now.add(const Duration(days: 1));
                final tomorrow = reminders
                    .where((r) =>
                        due(r).year == tomorrowDate.year &&
                        due(r).month == tomorrowDate.month &&
                        due(r).day == tomorrowDate.day)
                    .toList();
                final thisWeek = reminders
                    .where((r) =>
                        !overdue.contains(r) &&
                        !today.contains(r) &&
                        !tomorrow.contains(r) &&
                        due(r).difference(now).inDays < 7)
                    .toList();
                final future = reminders
                    .where((r) =>
                        !overdue.contains(r) &&
                        !today.contains(r) &&
                        !tomorrow.contains(r) &&
                        !thisWeek.contains(r))
                    .toList();

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    96 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    if (overdue.isNotEmpty)
                      _Section(title: 'Overdue', reminders: overdue),
                    if (today.isNotEmpty)
                      _Section(title: 'Today', reminders: today),
                    if (tomorrow.isNotEmpty)
                      _Section(title: 'Tomorrow', reminders: tomorrow),
                    if (thisWeek.isNotEmpty)
                      _Section(title: 'This Week', reminders: thisWeek),
                    if (future.isNotEmpty)
                      _Section(title: 'Future', reminders: future),
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

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onEnable;
  const _PermissionBanner({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade700,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.notifications_off_outlined,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Notification permission is required to receive reminders.',
                style: TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ),
            TextButton(
              onPressed: onEnable,
              child: const Text('Enable',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Reminder> reminders;
  const _Section({required this.title, required this.reminders});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...reminders.map((r) => _ReminderTile(reminder: r)),
      ],
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  final Reminder reminder;
  const _ReminderTile({required this.reminder});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Delete reminder?'),
        content: Text('“${reminder.title}” will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(notificationServiceProvider)
          .cancelReminderNotifications(reminder);
      await ref.read(reminderRepositoryProvider).deleteReminder(reminder.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete reminder: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final remaining =
        reminder.nextOccurrence(DateTime.now()).difference(DateTime.now());
    final countdown = remaining.isNegative
        ? 'Overdue'
        : remaining.inDays > 0
            ? 'Upcoming in ${remaining.inDays} ${remaining.inDays == 1 ? 'day' : 'days'}'
            : remaining.inHours > 0
                ? 'Upcoming in ${remaining.inHours} ${remaining.inHours == 1 ? 'hour' : 'hours'}'
                : 'Upcoming in ${remaining.inMinutes.clamp(1, 59)} ${remaining.inMinutes.clamp(1, 59) == 1 ? 'minute' : 'minutes'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .9)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            context.push('/reminders/${reminder.id}/edit', extra: reminder),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                reminder.completed
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_active_outlined,
                color: scheme.primary,
                size: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: reminder.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  decoration: reminder.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                          TextSpan(
                            text: ' / ${reminder.repeat.label}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.normal,
                                    ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(countdown,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            )),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Delete reminder',
                    onPressed: () => _delete(context, ref),
                    icon:
                        Icon(Icons.delete_outline_rounded, color: scheme.error),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
