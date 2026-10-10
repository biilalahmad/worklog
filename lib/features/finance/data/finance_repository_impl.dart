import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/offline_data_store.dart';

import '../domain/expense.dart';
import '../domain/finance_repository.dart';
import '../domain/income.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  final SupabaseClient _client;

  FinanceRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<List<Income>> watchIncomeForRange(DateTime start, DateTime end) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'income',
            queryKey: 'all',
            remote: _client
                .from('income')
                .stream(primaryKey: ['id']).order('date', ascending: false))
        .map((rows) => rows
            .map(Income.fromMap)
            .where((i) => !i.date.isBefore(start) && !i.date.isAfter(end))
            .toList());
  }

  @override
  Stream<List<Income>> watchIncomeForClient(String clientId) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'income',
            queryKey: 'client:$clientId',
            remote: _client
                .from('income')
                .stream(primaryKey: ['id'])
                .eq('client_id', clientId)
                .order('date', ascending: false))
        .map((rows) => rows
            .where((row) => row['client_id'] == clientId)
            .map(Income.fromMap)
            .toList());
  }

  @override
  Stream<List<Expense>> watchExpensesForRange(DateTime start, DateTime end) {
    return OfflineDataStore.instance
        .watchRows(
            client: _client,
            table: 'expenses',
            queryKey: 'all',
            remote: _client
                .from('expenses')
                .stream(primaryKey: ['id']).order('date', ascending: false))
        .map((rows) => rows
            .map(Expense.fromMap)
            .where((e) => !e.date.isBefore(start) && !e.date.isAfter(end))
            .toList());
  }

  @override
  Future<String> addIncome(Income income) async {
    // Inserting here is what the `trg_income_rollup` Postgres trigger
    // listens for, to update the linked project and client rollups.
    final row = income.toWritableMap()
      ..['created_at'] =
          (income.createdAt ?? DateTime.now()).toUtc().toIso8601String();
    return OfflineDataStore.instance.insert(_client, 'income', row,
        id: income.id.isEmpty ? null : income.id);
  }

  @override
  Future<void> deleteIncome(String incomeId) {
    return OfflineDataStore.instance.delete(_client, 'income', incomeId);
  }

  @override
  Future<String> addExpense(Expense expense) async {
    final row = expense.toWritableMap()
      ..['created_at'] =
          (expense.createdAt ?? DateTime.now()).toUtc().toIso8601String();
    return OfflineDataStore.instance.insert(_client, 'expenses', row,
        id: expense.id.isEmpty ? null : expense.id);
  }

  @override
  Future<void> deleteExpense(String expenseId) {
    return OfflineDataStore.instance.delete(_client, 'expenses', expenseId);
  }

  @override
  Future<List<Income>> getAllIncome() async {
    final rows = await OfflineDataStore.instance.fetchRows(
      client: _client,
      table: 'income',
      queryKey: 'all',
      fetch: () async =>
          await _client.from('income').select().order('date', ascending: false),
    );
    return rows.map(Income.fromMap).toList();
  }

  @override
  Future<List<Expense>> getAllExpenses() async {
    final rows = await OfflineDataStore.instance.fetchRows(
      client: _client,
      table: 'expenses',
      queryKey: 'all',
      fetch: () async => await _client
          .from('expenses')
          .select()
          .order('date', ascending: false),
    );
    return rows.map(Expense.fromMap).toList();
  }
}
