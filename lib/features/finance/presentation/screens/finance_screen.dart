import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/date_keys.dart';
import '../../../../core/utils/local_day_provider.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/money_display.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../providers/finance_providers.dart';
import '../../../work/presentation/providers/work_providers.dart'
    show DateRange;
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/utils/refresh_with_network.dart';
import '../../../assistant/domain/assistant_contract.dart';
import '../../../assistant/presentation/widgets/assistant_entry.dart';
import '../../domain/expense.dart';
import '../../domain/income.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  static const _undoDuration = Duration(seconds: 3);
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  Timer? _undoTimer;
  int _snackbarGeneration = 0;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  void _deleteActivity(DeletedFinanceActivityNotifier notifier, String key) {
    notifier.markDeleted(key);
    unawaited(notifier.stageDelete(key).then((_) {
      if (mounted) _showDeletedActivitySnackBar(notifier, key);
    }).catchError((Object _) async {
      await notifier.rollbackStage(key);
      if (mounted) _showDeleteActivityError();
    }));
  }

  void _showDeletedActivitySnackBar(
    DeletedFinanceActivityNotifier notifier,
    String key,
  ) {
    _undoTimer?.cancel();
    final generation = ++_snackbarGeneration;
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      AppSnackBar.build(
        messenger.context,
        message: 'Notification deleted successfully',
        duration: _undoDuration,
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            if (generation != _snackbarGeneration) return;
            _undoTimer?.cancel();
            _undoTimer = null;
            unawaited(_restoreFinanceActivity(notifier, key, messenger));
          },
        ),
      ),
    );
    // SnackBars with actions may be kept open by accessibility settings.
    // Keep the undo window deterministic, and cancel this timer if another
    // message replaces the current one or the route is disposed.
    _undoTimer = Timer(_undoDuration, () {
      if (!mounted || generation != _snackbarGeneration) return;
      if (messenger.mounted) controller.close();
    });
    unawaited(controller.closed.then((_) {
      if (generation == _snackbarGeneration) {
        _undoTimer?.cancel();
        _undoTimer = null;
      }
    }));
  }

  Future<void> _restoreFinanceActivity(
    DeletedFinanceActivityNotifier notifier,
    String key,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      await notifier.restore(key);
    } catch (_) {
      if (mounted && messenger.mounted) {
        _showDeleteActivityError();
      }
    }
  }

  void _showDeleteActivityError() {
    _undoTimer?.cancel();
    _undoTimer = null;
    _snackbarGeneration++;
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      AppSnackBar.build(
        messenger.context,
        message: 'Could not delete or restore notification. Please try again.',
        isError: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    ref.watch(localCalendarDayProvider);
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final todayRange =
        DateRange(DateKeys.startOfDay(now), DateKeys.endOfDay(now));
    final monthRange =
        DateRange(DateKeys.startOfMonth(now), DateKeys.endOfDay(now));

    final todayIncomeAsync = ref.watch(incomeForRangeProvider(todayRange));
    final todayExpenseAsync = ref.watch(expensesForRangeProvider(todayRange));
    final monthIncomeAsync = ref.watch(incomeForRangeProvider(monthRange));
    final monthExpenseAsync = ref.watch(expensesForRangeProvider(monthRange));
    final userId =
        Supabase.instance.client.auth.currentUser?.id ?? 'signed-out';
    final deletedActivity = ref.watch(deletedFinanceActivityProvider(userId));
    final defaultCurrency = ref.watch(defaultCurrencyProvider);
    final recentCutoff = now.subtract(const Duration(days: 7));

    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finance'),
          actions: [
            IconButton(
              icon: const Icon(Icons.pending_actions_outlined),
              tooltip: 'Pending payments',
              onPressed: () => context.push('/finance/pending'),
            ),
            IconButton(
              icon: const Icon(Icons.insights_outlined),
              tooltip: 'Analytics',
              onPressed: () => context.push('/finance/analytics'),
            ),
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'Financial Reports',
              onPressed: () => context.push('/finance/reports'),
            ),
            const AssistantShortcutButton(agent: AssistantAgent.finance),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => refreshWithNetworkMessage(context, () async {
            await Future.wait([
              ref.refresh(incomeForRangeProvider(todayRange).future),
              ref.refresh(expensesForRangeProvider(todayRange).future),
              ref.refresh(incomeForRangeProvider(monthRange).future),
              ref.refresh(expensesForRangeProvider(monthRange).future),
            ]);
          }),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => context.push('/finance/expense/new'),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('Add Expense'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.errorContainer,
                        foregroundColor:
                            Theme.of(context).colorScheme.onErrorContainer,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/finance/income/new'),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Income'),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary,
                      scheme.primary.withValues(alpha: 0.78)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.2),
                        blurRadius: 22,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded,
                            color: scheme.onPrimary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'TODAY\'S CASH FLOW',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 11,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    todayIncomeAsync.when(
                      loading: () => SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: scheme.onPrimary),
                      ),
                      error: (e, _) => Text(Failure.from(e).message,
                          style: const TextStyle(color: Colors.white)),
                      data: (income) => todayExpenseAsync.when(
                        loading: () => SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: scheme.onPrimary),
                        ),
                        error: (e, _) => Text(Failure.from(e).message,
                            style: const TextStyle(color: Colors.white)),
                        data: (expenses) => MoneyTotalsDisplay(
                          _cashFlowByCurrency(income, expenses,
                              defaultCurrency: defaultCurrency),
                          style: const TextStyle(
                            fontSize: 30,
                            height: 1.15,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('Income recorded today',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.76))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('This Month Income',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          monthIncomeAsync.when(
                            loading: () => const LoadingIndicator(),
                            error: (e, _) => Text(Failure.from(e).message),
                            data: (list) => MoneyTotalsDisplay(
                              _sumByCurrency(list.map((i) =>
                                  Money(i.amountMinor.abs(), i.currency))),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('This Month Expenses',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          monthExpenseAsync.when(
                            loading: () => const LoadingIndicator(),
                            error: (e, _) => Text(Failure.from(e).message),
                            data: (list) => MoneyTotalsDisplay(
                              _sumByCurrency(list.map((e) =>
                                  Money(e.amountMinor.abs(), e.currency))),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Consumer(
                builder: (context, ref, _) {
                  final showIncome = ref.watch(financeRecentToggleProvider);
                  final dismissalsLoaded = ref
                      .read(deletedFinanceActivityProvider(userId).notifier)
                      .isLoaded;
                  if (!dismissalsLoaded) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LoadingIndicator(),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                              value: true, label: Text('Recent Income')),
                          ButtonSegment(
                              value: false, label: Text('Recent Spending')),
                        ],
                        selected: {showIncome},
                        onSelectionChanged: (s) => ref
                            .read(financeRecentToggleProvider.notifier)
                            .state = s.first,
                      ),
                      const SizedBox(height: 12),
                      if (showIncome)
                        monthIncomeAsync.when(
                          loading: () => const LoadingIndicator(),
                          error: (e, _) =>
                              ErrorView(message: Failure.from(e).message),
                          data: (list) {
                            final newestFirst = _newestFirst(
                              list
                                  .where((item) =>
                                      !item.date.isBefore(recentCutoff) &&
                                      !item.date.isAfter(now))
                                  .toList(),
                              (item) => item.createdAt ?? item.date,
                              (item) => item.id,
                            );
                            final visible = newestFirst
                                .where((i) =>
                                    !deletedActivity.contains('income:${i.id}'))
                                .take(10)
                                .toList();
                            if (visible.isEmpty) {
                              return const SizedBox(
                                height: 210,
                                child: EmptyState(
                                  icon: Icons.south_west_rounded,
                                  title: 'No recent income',
                                  subtitle:
                                      'Income recorded in the last 7 days will appear here.',
                                ),
                              );
                            }
                            return Column(
                              children: visible.map((income) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _FinanceActivityDismissible(
                                    activityId: 'income:${income.id}',
                                    onDismissed: () {
                                      final notifier = ref.read(
                                          deletedFinanceActivityProvider(userId)
                                              .notifier);
                                      _deleteActivity(
                                          notifier, 'income:${income.id}');
                                    },
                                    child: _FinanceActivityTile(
                                      icon: Icons.arrow_downward_rounded,
                                      title: income.method,
                                      date: income.date,
                                      createdAt: income.createdAt,
                                      description: income.description,
                                      amount: Money(income.amountMinor.abs(),
                                          income.currency),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        )
                      else
                        monthExpenseAsync.when(
                          loading: () => const LoadingIndicator(),
                          error: (e, _) =>
                              ErrorView(message: Failure.from(e).message),
                          data: (list) {
                            final newestFirst = _newestFirst(
                              list
                                  .where((item) =>
                                      !item.date.isBefore(recentCutoff) &&
                                      !item.date.isAfter(now))
                                  .toList(),
                              (item) => item.createdAt ?? item.date,
                              (item) => item.id,
                            );
                            final visible = newestFirst
                                .where((e) => !deletedActivity
                                    .contains('expense:${e.id}'))
                                .take(10)
                                .toList();
                            if (visible.isEmpty) {
                              return const SizedBox(
                                height: 210,
                                child: EmptyState(
                                  icon: Icons.north_east_rounded,
                                  title: 'No recent spending',
                                  subtitle:
                                      'Spending recorded in the last 7 days will appear here.',
                                ),
                              );
                            }
                            return Column(
                              children: visible.map((expense) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _FinanceActivityDismissible(
                                    activityId: 'expense:${expense.id}',
                                    onDismissed: () {
                                      final notifier = ref.read(
                                          deletedFinanceActivityProvider(userId)
                                              .notifier);
                                      _deleteActivity(
                                          notifier, 'expense:${expense.id}');
                                    },
                                    child: _FinanceActivityTile(
                                      icon: Icons.arrow_upward_rounded,
                                      title: expense.category,
                                      date: expense.date,
                                      createdAt: expense.createdAt,
                                      description: expense.description,
                                      amount: Money(expense.amountMinor.abs(),
                                          expense.currency),
                                      isExpense: true,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  MoneyByCurrency _sumByCurrency(Iterable<Money> amounts) {
    final map = <String, int>{};
    for (final m in amounts) {
      map[m.currency] = (map[m.currency] ?? 0) + m.minorUnits;
    }
    return MoneyByCurrency(map);
  }

  MoneyByCurrency _cashFlowByCurrency(
    Iterable<Income> income,
    Iterable<Expense> expenses, {
    required String defaultCurrency,
  }) {
    final totals = <String, int>{};
    for (final item in income) {
      totals[item.currency] =
          (totals[item.currency] ?? 0) + item.amountMinor.abs();
    }
    for (final item in expenses) {
      totals[item.currency] =
          (totals[item.currency] ?? 0) - item.amountMinor.abs();
    }
    if (totals.isEmpty) totals[defaultCurrency] = 0;
    return MoneyByCurrency(totals);
  }
}

List<T> _newestFirst<T>(
  List<T> items,
  DateTime Function(T) timestampOf,
  String Function(T) idOf,
) {
  final uniqueById = <String, T>{};
  for (final item in items) {
    uniqueById.putIfAbsent(idOf(item), () => item);
  }
  final indexed = uniqueById.values.indexed.toList();
  indexed.sort((a, b) {
    final byTimestamp = timestampOf(b.$2).compareTo(timestampOf(a.$2));
    return byTimestamp != 0 ? byTimestamp : idOf(a.$2).compareTo(idOf(b.$2));
  });
  return indexed.map((entry) => entry.$2).toList();
}

class _FinanceActivityDismissible extends StatelessWidget {
  const _FinanceActivityDismissible({
    required this.activityId,
    required this.onDismissed,
    required this.child,
  });

  final String activityId;
  final VoidCallback onDismissed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(activityId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child:
            Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
      ),
      // Never wait on a network write before animating the swipe. The row is
      // hidden optimistically and restored if its persistence later fails.
      confirmDismiss: (_) async => true,
      onDismissed: (_) => onDismissed(),
      child: child,
    );
  }
}

class _FinanceActivityTile extends StatelessWidget {
  const _FinanceActivityTile({
    required this.icon,
    required this.title,
    required this.date,
    this.createdAt,
    required this.amount,
    this.description,
    this.isExpense = false,
  });

  final IconData icon;
  final String title;
  final DateTime date;
  final DateTime? createdAt;
  final Money amount;
  final String? description;
  final bool isExpense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: scheme.primaryContainer,
            child: Icon(icon, size: 17, color: scheme.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 5),
                Text(
                    createdAt == null
                        ? DateFormat('MMM d, yyyy').format(date.toLocal())
                        : DateFormat('MMM d, yyyy • h:mm a')
                            .format(createdAt!.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        )),
                if (description?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 7),
                  Text(description!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(height: 1.35)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: MoneyDisplay(
              amount,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isExpense ? scheme.error : null,
                  ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}
