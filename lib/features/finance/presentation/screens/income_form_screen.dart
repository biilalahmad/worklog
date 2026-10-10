import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/client_picker_field.dart';
import '../../../../core/widgets/date_time_picker_field.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../clients/domain/project.dart';
import '../../../clients/presentation/providers/client_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/income.dart';
import '../providers/finance_providers.dart';

const _paymentMethods = [
  'Bank Transfer',
  'Easypaisa',
  'JazzCash',
  'Fiverr',
  'PayPal',
  'Cash',
  'Other',
];

class IncomeFormScreen extends ConsumerStatefulWidget {
  const IncomeFormScreen({super.key});

  @override
  ConsumerState<IncomeFormScreen> createState() => _IncomeFormScreenState();
}

class _IncomeFormScreenState extends ConsumerState<IncomeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _tipCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _clientId;
  String? _clientError;
  String? _projectId;
  String _currency = 'PKR';
  String _method = _paymentMethods.first;
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
    _tipCtrl.dispose();
    _descCtrl.dispose();
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

  /// Selecting a project pre-fills the Amount field with what's still
  /// owed on it (so recording a payment defaults to clearing the
  /// balance) — the field stays fully editable for a partial payment.
  void _onProjectSelected(String? projectId, List<Project> projects) {
    setState(() => _projectId = projectId);
    if (projectId == null) return;
    Project? project;
    for (final p in projects) {
      if (p.id == projectId) {
        project = p;
        break;
      }
    }
    if (project == null) return;
    final remaining =
        project.amountRemainingMinor > 0 ? project.amountRemainingMinor : 0;
    _amountCtrl.text =
        Money(remaining, project.currency).asDouble.toStringAsFixed(2);
    setState(() => _currency = project!.currency);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      setState(() => _clientError = 'Select a client');
      return;
    }
    final repo = ref.read(financeRepositoryProvider);
    setState(() => _saving = true);
    try {
      final baseAmount = Money.toMinorUnits(
          double.parse(_amountCtrl.text.trim()).abs(), _currency);
      final tipAmount = _tipCtrl.text.trim().isEmpty
          ? 0
          : Money.toMinorUnits(
              double.parse(_tipCtrl.text.trim()).abs(), _currency);
      final description = [
        if (_descCtrl.text.trim().isNotEmpty) _descCtrl.text.trim(),
        if (tipAmount > 0)
          'Includes ${Money(tipAmount, _currency).format()} tip',
      ].join(' — ');
      final income = Income(
        id: '',
        clientId: _clientId!,
        projectId: _projectId,
        amountMinor: baseAmount + tipAmount,
        currency: _currency,
        date: _date,
        method: _method,
        description: description.isEmpty ? null : description,
      );
      await repo.addIncome(income);
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
    final clientsAsync = ref.watch(clientsListProvider);
    final projectsAsync = _clientId == null
        ? null
        : ref.watch(projectsForClientProvider(_clientId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Record Income')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            clientsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(Failure.from(e).message),
              data: (clients) => ClientPickerField(
                clients: clients,
                initialClientId: _clientId,
                errorText: _clientError,
                onChanged: (id) => setState(() {
                  _clientId = id;
                  _clientError = null;
                  _projectId = null;
                  _amountCtrl.clear();
                }),
              ),
            ),
            if (projectsAsync != null) ...[
              const SizedBox(height: 16),
              projectsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(Failure.from(e).message),
                data: (projects) => AppSelectField<String>(
                  value: _projectId,
                  label: 'Project (optional)',
                  hintText: 'No project selected',
                  options: projects
                      .map((p) => AppSelectOption(value: p.id, label: p.title))
                      .toList(),
                  onChanged: (v) => _onProjectSelected(v, projects),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount received *',
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
            TextFormField(
              controller: _tipCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Extra tip (if any)',
                hintText: 'e.g. 100',
                prefixIcon: Icon(Icons.volunteer_activism_outlined, size: 20),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final amount = double.tryParse(v.trim());
                if (amount == null) return 'Enter a valid number';
                if (amount < 0) return 'Tip cannot be negative';
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppSelectField<String>(
              value: _method,
              label: 'Payment method',
              options: _paymentMethods
                  .map((m) => AppSelectOption(value: m, label: m))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _method = v ?? _paymentMethods.first),
            ),
            const SizedBox(height: 16),
            DateTimePickerField(date: _date, onTapDate: _pickDate),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Income'),
            ),
          ],
        ),
      ),
    );
  }
}
