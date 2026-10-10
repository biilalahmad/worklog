import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/date_time_picker_field.dart';
import '../../domain/body_stat.dart';
import '../providers/gym_providers.dart';

class BodyStatFormScreen extends ConsumerStatefulWidget {
  const BodyStatFormScreen({super.key});

  @override
  ConsumerState<BodyStatFormScreen> createState() => _BodyStatFormScreenState();
}

class _BodyStatFormScreenState extends ConsumerState<BodyStatFormScreen> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();
  final _bodyFatCtrl = TextEditingController();
  final _chestCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _armCtrl = TextEditingController();
  final _thighCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _bodyFatCtrl.dispose();
    _chestCtrl.dispose();
    _waistCtrl.dispose();
    _armCtrl.dispose();
    _thighCtrl.dispose();
    super.dispose();
  }

  double? _parse(String v) =>
      v.trim().isEmpty ? null : double.tryParse(v.trim());

  double? _latestValue(List<BodyStat> stats, double? Function(BodyStat) read) {
    for (final stat in stats) {
      final value = read(stat);
      if (value != null) return value;
    }
    return null;
  }

  void _fillFrom(List<BodyStat> stats) {
    _weightCtrl.text =
        _latestValue(stats, (stat) => stat.weight)?.toString() ?? '';
    _heightCtrl.text =
        _latestValue(stats, (stat) => stat.heightCm)?.toString() ?? '';
    _targetWeightCtrl.text =
        _latestValue(stats, (stat) => stat.targetWeightKg)?.toString() ?? '';
    _bodyFatCtrl.text =
        _latestValue(stats, (stat) => stat.bodyFatPct)?.toString() ?? '';
    _chestCtrl.text =
        _latestValue(stats, (stat) => stat.chestCm)?.toString() ?? '';
    _waistCtrl.text =
        _latestValue(stats, (stat) => stat.waistCm)?.toString() ?? '';
    _armCtrl.text = _latestValue(stats, (stat) => stat.armCm)?.toString() ?? '';
    _thighCtrl.text =
        _latestValue(stats, (stat) => stat.thighCm)?.toString() ?? '';
    setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final values = [
      _parse(_weightCtrl.text),
      _parse(_heightCtrl.text),
      _parse(_targetWeightCtrl.text),
      _parse(_bodyFatCtrl.text),
      _parse(_chestCtrl.text),
      _parse(_waistCtrl.text),
      _parse(_armCtrl.text),
      _parse(_thighCtrl.text),
    ];
    if (values.every((value) => value == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter at least one measurement to save.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(bodyStatRepositoryProvider).addBodyStat(BodyStat(
            id: '',
            date: _date,
            weight: _parse(_weightCtrl.text),
            heightCm: _parse(_heightCtrl.text),
            targetWeightKg: _parse(_targetWeightCtrl.text),
            bodyFatPct: _parse(_bodyFatCtrl.text),
            chestCm: _parse(_chestCtrl.text),
            waistCm: _parse(_waistCtrl.text),
            armCm: _parse(_armCtrl.text),
            thighCm: _parse(_thighCtrl.text),
          ));
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
    final latestStats =
        ref.watch(bodyStatsListProvider).valueOrNull ?? const <BodyStat>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Log Body Stats')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DateTimePickerField(date: _date, onTapDate: _pickDate),
          const SizedBox(height: 16),
          if (latestStats.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _fillFrom(latestStats),
                icon: const Icon(Icons.history_rounded),
                label: const Text('Use latest saved measurements'),
              ),
            ),
          Text('Body measurements',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _heightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Height (cm)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight (kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetWeightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target weight (kg, optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyFatCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Body fat %'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chestCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Chest (cm)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _waistCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Waist (cm)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _armCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Arm (cm)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _thighCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Thigh (cm)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
