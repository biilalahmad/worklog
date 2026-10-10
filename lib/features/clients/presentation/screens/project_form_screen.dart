import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/date_time_picker_field.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/project.dart';
import '../providers/client_providers.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  final String clientId;
  const ProjectFormScreen({super.key, required this.clientId});

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController(text: '0');
  String _currency = 'PKR';
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currency = ref.read(defaultCurrencyProvider);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(projectRepositoryProvider);
    setState(() => _saving = true);
    try {
      final subtotalMinor =
          Money.toMinorUnits(double.parse(_amountCtrl.text.trim()), _currency);
      final taxRate = double.parse(_taxRateCtrl.text.trim());
      final taxRateBps = (taxRate * 100).round();
      final taxMinor = (subtotalMinor * taxRateBps / 10000).round();
      final project = Project(
        id: '',
        clientId: widget.clientId,
        title: _titleCtrl.text.trim(),
        totalAmountMinor: subtotalMinor + taxMinor,
        subtotalAmountMinor: subtotalMinor,
        taxAmountMinor: taxMinor,
        taxRateBps: taxRateBps,
        currency: _currency,
        dueDate: _dueDate,
      );
      await repo.addProject(project);
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
      appBar: AppBar(title: const Text('New Project / Invoice')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Project Title *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Subtotal *'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter an amount';
                      }
                      if (double.tryParse(v.trim()) == null) {
                        return 'Enter a valid number';
                      }
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
              controller: _taxRateCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tax rate (%)',
                helperText: 'Optional — 0% keeps the invoice tax-free',
              ),
              validator: (v) {
                final rate = double.tryParse(v?.trim() ?? '');
                if (rate == null || rate < 0 || rate > 1000) {
                  return 'Enter a tax rate between 0 and 1000';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DateTimePickerField(
              date: _dueDate,
              onTapDate: _pickDueDate,
              onClearDate: _dueDate == null
                  ? null
                  : () => setState(() => _dueDate = null),
              label: 'Due date (optional)',
              placeholder: 'Not set',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add Project'),
            ),
          ],
        ),
      ),
    );
  }
}
