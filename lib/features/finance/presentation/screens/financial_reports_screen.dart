import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/pdf/report_pdf_generator.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/money_display.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/utils/money.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../work/presentation/providers/work_providers.dart';
import '../../domain/expense.dart';
import '../../domain/income.dart';
import '../providers/finance_providers.dart';

class FinancialReportsScreen extends ConsumerStatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  ConsumerState<FinancialReportsScreen> createState() =>
      _FinancialReportsScreenState();
}

class _FinancialReportsScreenState
    extends ConsumerState<FinancialReportsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  ReportKind _kind = ReportKind.combined;
  bool _generating = false;

  DateTime get _monthStart => DateTime(_month.year, _month.month, 1);
  DateTime get _monthEnd => DateTime(_month.year, _month.month + 1, 1)
      .subtract(const Duration(milliseconds: 1));

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  Future<void> _download(List income, List expenses) async {
    setState(() => _generating = true);
    try {
      final displayName = ref.read(displayNameProvider).valueOrNull ??
          ref.read(authRepositoryProvider).currentUserEmail ??
          'WorkLog User';
      await ReportPdfGenerator.generateAndShare(
        month: _month,
        kind: _kind,
        income: income.cast(),
        expenses: expenses.cast(),
        userName: displayName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = DateRange(_monthStart, _monthEnd);
    final incomeAsync = ref.watch(incomeForRangeProvider(range));
    final expensesAsync = ref.watch(expensesForRangeProvider(range));

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _changeMonth(-1)),
                Text(DateFormat('MMMM yyyy').format(_month),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _monthStart.isBefore(DateTime(
                          DateTime.now().year, DateTime.now().month, 1))
                      ? () => _changeMonth(1)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ReportKind>(
            segments: const [
              ButtonSegment(value: ReportKind.income, label: Text('Income')),
              ButtonSegment(
                  value: ReportKind.spending, label: Text('Spending')),
              ButtonSegment(
                  value: ReportKind.combined, label: Text('Combined')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generating ||
                      incomeAsync.valueOrNull == null ||
                      expensesAsync.valueOrNull == null
                  ? null
                  : () {
                      final income = incomeAsync.valueOrNull;
                      final expenses = expensesAsync.valueOrNull;
                      if (income != null && expenses != null) {
                        _download(
                          _newestIncomeFirst(income),
                          _newestExpensesFirst(expenses),
                        );
                      }
                    },
              icon: _generating
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: const Text('Download PDF Report'),
            ),
          ),
          const SizedBox(height: 20),
          incomeAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, _) => ErrorView(message: Failure.from(e).message),
            data: (income) => expensesAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => ErrorView(message: Failure.from(e).message),
              data: (expenses) {
                final newestIncome = _newestIncomeFirst(income);
                final newestExpenses = _newestExpensesFirst(expenses);
                final totalIncome = _sumByCurrency(newestIncome.map(
                    (item) => Money(item.amountMinor.abs(), item.currency)));
                final totalExpenses = _sumByCurrency(newestExpenses.map(
                    (item) => Money(item.amountMinor.abs(), item.currency)));

                return Column(
                  children: [
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_kind != ReportKind.spending)
                            Row(children: [
                              Text('Income: (${newestIncome.length} records) '),
                              Expanded(child: MoneyTotalsDisplay(totalIncome)),
                            ]),
                          if (_kind != ReportKind.income)
                            Row(children: [
                              Text(
                                  'Spending: (${newestExpenses.length} records) '),
                              Expanded(
                                  child: MoneyTotalsDisplay(totalExpenses)),
                            ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_kind != ReportKind.spending) ...[
                      _incomeDetails(newestIncome),
                      if (_kind == ReportKind.combined)
                        const SizedBox(height: 18),
                    ],
                    if (_kind != ReportKind.income)
                      _expenseDetails(newestExpenses),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  MoneyByCurrency _sumByCurrency(Iterable<Money> amounts) {
    final totals = <String, int>{};
    for (final amount in amounts) {
      totals[amount.currency] =
          (totals[amount.currency] ?? 0) + amount.minorUnits;
    }
    return MoneyByCurrency(totals);
  }

  Widget _incomeDetails(List<Income> income) => SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Income entries (${income.length})',
                style: Theme.of(context).textTheme.titleSmall),
            if (income.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('No income recorded for this month.'),
              )
            else
              for (final item in income)
                _ReportEntryRow(
                  icon: Icons.south_west_rounded,
                  title: item.method,
                  timestamp: _formatEntryTimestamp(item.createdAt, item.date),
                  description: item.description,
                  amount: Money(item.amountMinor.abs(), item.currency),
                ),
          ],
        ),
      );

  Widget _expenseDetails(List<Expense> expenses) => SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expense entries (${expenses.length})',
                style: Theme.of(context).textTheme.titleSmall),
            if (expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('No expenses recorded for this month.'),
              )
            else
              for (final item in expenses)
                _ReportEntryRow(
                  icon: Icons.north_east_rounded,
                  title: item.category,
                  timestamp: _formatEntryTimestamp(item.createdAt, item.date),
                  description: item.description,
                  amount: Money(item.amountMinor.abs(), item.currency),
                ),
          ],
        ),
      );
}

String _formatEntryTimestamp(DateTime? createdAt, DateTime transactionDate) {
  if (createdAt == null) return DateFormat.yMMMd().format(transactionDate);
  return DateFormat('MMM d, yyyy · h:mm a').format(createdAt.toLocal());
}

List<Income> _newestIncomeFirst(List<Income> entries) {
  final unique = <String, Income>{};
  for (final item in entries) {
    unique.putIfAbsent(item.id, () => item);
  }
  final result = unique.values.toList()
    ..sort((a, b) {
      final byTimestamp =
          (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date);
      return byTimestamp != 0 ? byTimestamp : a.id.compareTo(b.id);
    });
  return result;
}

List<Expense> _newestExpensesFirst(List<Expense> entries) {
  final unique = <String, Expense>{};
  for (final item in entries) {
    unique.putIfAbsent(item.id, () => item);
  }
  final result = unique.values.toList()
    ..sort((a, b) {
      final byTimestamp =
          (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date);
      return byTimestamp != 0 ? byTimestamp : a.id.compareTo(b.id);
    });
  return result;
}

class _ReportEntryRow extends StatelessWidget {
  const _ReportEntryRow({
    required this.icon,
    required this.title,
    required this.timestamp,
    this.description,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String timestamp;
  final String? description;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(timestamp,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
                if (description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(description!.trim(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: MoneyDisplay(
              amount,
              textAlign: TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
