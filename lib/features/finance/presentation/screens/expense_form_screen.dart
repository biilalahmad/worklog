import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/date_time_picker_field.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/expense.dart';
import '../providers/finance_providers.dart';

const _expenseCategories = [
  'Software/Subscriptions',
  'Equipment',
  'Internet/Utilities',
  'Marketing',
  'Travel',
  'Other'
];

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = _expenseCategories.first;
  String _currency = 'PKR';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currency = ref.read(defaultCurrencyProvider);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(financeRepositoryProvider);
    setState(() => _saving = true);
    try {
      final expense = Expense(
        id: '',
        amountMinor: Money.toMinorUnits(
            double.parse(_amountCtrl.text.trim()).abs(), _currency),
        currency: _currency,
        date: _date,
        category: _category,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      await repo.addExpense(expense);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount spent *',
                      helperText: 'Enter a positive amount',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter an amount';
                      final amount = double.tryParse(v.trim());
                      if (amount == null) return 'Enter a valid number';
                      if (amount <= 0) return 'Amount must be greater than 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppSelectField<String>(
                    value: _currency,
                    label: 'Currency',
                    options: supportedCurrencies
                        .map((c) => AppSelectOption(value: c, label: c))
                        .toList(),
                    onChanged: (v) => setState(() => _currency = v ?? 'PKR'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppSelectField<String>(
              value: _category,
              label: 'Category',
              options: _expenseCategories
                  .map((c) => AppSelectOption(value: c, label: c))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _category = v ?? _expenseCategories.first),
            ),
            const SizedBox(height: 16),
            DateTimePickerField(date: _date, onTapDate: _pickDate),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
