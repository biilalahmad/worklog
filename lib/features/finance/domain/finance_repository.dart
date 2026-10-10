import 'expense.dart';
import 'income.dart';

abstract class FinanceRepository {
  Stream<List<Income>> watchIncomeForRange(DateTime start, DateTime end);
  Stream<List<Income>> watchIncomeForClient(String clientId);
  Stream<List<Expense>> watchExpensesForRange(DateTime start, DateTime end);
  Future<String> addIncome(Income income);
  Future<void> deleteIncome(String incomeId);
  Future<String> addExpense(Expense expense);
  Future<void> deleteExpense(String expenseId);

  /// Full history (no date filter) — used for CSV export/backup.
  Future<List<Income>> getAllIncome();
  Future<List<Expense>> getAllExpenses();
}
