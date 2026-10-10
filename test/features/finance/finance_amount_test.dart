import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worklog/features/finance/domain/expense.dart';
import 'package:worklog/features/finance/domain/income.dart';
import 'package:worklog/features/finance/presentation/providers/finance_providers.dart';

void main() {
  test('income legacy negatives read and serialize as positive inflows', () {
    final income = Income.fromMap({
      'id': 'income-1',
      'client_id': 'client-1',
      'amount': -12500,
      'currency': 'PKR',
      'date': '2026-10-09T12:00:00Z',
      'method': 'Easypaisa',
    });

    expect(income.amountMinor, 12500);
    expect(income.toWritableMap()['amount'], 12500);
  });

  test('expense legacy negatives read and serialize as positive spending', () {
    final expense = Expense.fromMap({
      'id': 'expense-1',
      'amount': -2500,
      'currency': 'PKR',
      'date': '2026-10-09T12:00:00Z',
      'category': 'Equipment',
    });

    expect(expense.amountMinor, 2500);
    expect(expense.toWritableMap()['amount'], 2500);
  });

  test('deleting a finance activity notice persists per user', () async {
    SharedPreferences.setMockInitialValues({});
    final first = DeletedFinanceActivityNotifier('user-1');
    await first.delete('income:record-1');

    final reloaded = DeletedFinanceActivityNotifier('user-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(reloaded.isLoaded, isTrue);
    expect(reloaded.state, contains('income:record-1'));
    expect(DeletedFinanceActivityNotifier('user-2').state, isEmpty);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('worklog.finance.deleted_activity.user-1'),
      contains('income:record-1'),
    );
  });

  test('a staged swipe delete can be undone without losing other deletions',
      () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = DeletedFinanceActivityNotifier('user-undo');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(notifier.isLoaded, isTrue);

    await notifier.stageDelete('income:first');
    await notifier.stageDelete('expense:second');
    expect(notifier.state, isEmpty);

    notifier.markDeleted('income:first');
    notifier.markDeleted('expense:second');
    await notifier.restore('income:first');

    expect(notifier.state, {'expense:second'});
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('worklog.finance.deleted_activity.user-undo'),
      ['expense:second'],
    );
  });

  test('previously hidden notices migrate to permanent activity deletions',
      () async {
    SharedPreferences.setMockInitialValues({
      'worklog.finance.hidden_activity.user-1': ['expense:record-2'],
    });
    final notifier = DeletedFinanceActivityNotifier('user-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(notifier.state, contains('expense:record-2'));
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('worklog.finance.deleted_activity.user-1'),
      contains('expense:record-2'),
    );
    expect(preferences.containsKey('worklog.finance.hidden_activity.user-1'),
        isFalse);
  });
}
