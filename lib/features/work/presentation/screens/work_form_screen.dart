import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/client_picker_field.dart';
import '../../../../core/widgets/date_time_picker_field.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../clients/presentation/providers/client_providers.dart';
import '../../domain/work_entry.dart';
import '../providers/work_providers.dart';

/// Add/edit a work entry. Pass an existing [entry] to edit.
class WorkFormScreen extends ConsumerStatefulWidget {
  final WorkEntry? entry;
  final String? preselectedClientId;
  const WorkFormScreen({super.key, this.entry, this.preselectedClientId});

  @override
  ConsumerState<WorkFormScreen> createState() => _WorkFormScreenState();
}

class _WorkFormScreenState extends ConsumerState<WorkFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _workTypeCtrl = TextEditingController(
    text: widget.entry?.workType.trim().isNotEmpty == true
        ? widget.entry!.workType
        : widget.entry?.taskName ?? 'General Work',
  );
  late final _videoCountCtrl =
      TextEditingController(text: '${widget.entry?.videoCount ?? 0}');
  late final _otherTaskCtrl =
      TextEditingController(text: '${widget.entry?.otherTaskCount ?? 0}');
  late final _hoursCtrl =
      TextEditingController(text: '${widget.entry?.hoursWorked ?? 0}');
  late final _notesCtrl =
      TextEditingController(text: widget.entry?.notes ?? '');
  String? _clientId;
  String? _clientError;
  late DateTime _date = widget.entry?.date ?? DateTime.now();
  late WorkStatus _status = widget.entry?.status ?? WorkStatus.pending;
  bool _saving = false;
  DateTime? _timerStartedAt;
  Timer? _tick;
  bool _timerUpdating = false;

  bool get _isEditing => widget.entry != null;
  bool get _isVideoEditing =>
      _workTypeCtrl.text.trim().toLowerCase() == 'video editing';

  @override
  void initState() {
    super.initState();
    _clientId = widget.entry?.clientId ?? widget.preselectedClientId;
    _timerStartedAt = widget.entry?.timerStartedAt;
    if (_timerStartedAt != null) _startTicking();
  }

  void _startTicking() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  String get _elapsedLabel {
    if (_timerStartedAt == null) return '00:00:00';
    final d = DateTime.now().difference(_timerStartedAt!);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  Future<void> _toggleTimer() async {
    if (widget.entry == null || _timerUpdating) return;
    setState(() => _timerUpdating = true);
    try {
      final repo = ref.read(workRepositoryProvider);
      if (_timerStartedAt == null) {
        await repo.startTimer(widget.entry!.id);
        if (!mounted) return;
        setState(() => _timerStartedAt = DateTime.now());
        _startTicking();
      } else {
        final elapsedHours =
            DateTime.now().difference(_timerStartedAt!).inSeconds / 3600.0;
        await repo.stopTimer(widget.entry!.id);
        _tick?.cancel();
        if (!mounted) return;
        setState(() {
          final current = double.tryParse(_hoursCtrl.text.trim()) ?? 0;
          _hoursCtrl.text = (current + elapsedHours).toStringAsFixed(2);
          _timerStartedAt = null;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn’t update timer: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _timerUpdating = false);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _workTypeCtrl.dispose();
    _videoCountCtrl.dispose();
    _otherTaskCtrl.dispose();
    _hoursCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      setState(() => _clientError = 'Select a client');
      return;
    }
    final repo = ref.read(workRepositoryProvider);
    setState(() => _saving = true);
    try {
      final entry = WorkEntry(
        id: widget.entry?.id ?? '',
        clientId: _clientId!,
        // Keep the legacy task_name column populated for existing reports and
        // search, while presenting one clear work descriptor in the UI.
        taskName: _workTypeCtrl.text.trim(),
        workType: _workTypeCtrl.text.trim(),
        videoCount: int.tryParse(_videoCountCtrl.text.trim()) ?? 0,
        otherTaskCount: int.tryParse(_otherTaskCtrl.text.trim()) ?? 0,
        hoursWorked: double.tryParse(_hoursCtrl.text.trim()) ?? 0,
        status: _status,
        date: _date,
        completionDate:
            _status == WorkStatus.completed || _status == WorkStatus.delivered
                ? DateTime.now()
                : null,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (_isEditing) {
        await repo.updateEntry(entry);
      } else {
        await repo.addEntry(entry);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Couldn\'t save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsListProvider);

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit Work Entry' : 'New Work Entry')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            clientsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Couldn\'t load clients: $e'),
              data: (clients) => ClientPickerField(
                clients: clients,
                initialClientId: _clientId,
                errorText: _clientError,
                onChanged: (id) => setState(() {
                  _clientId = id;
                  _clientError = null;
                }),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _workTypeCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Work type *',
                hintText: 'e.g. Design, Writing, Consulting',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a work type' : null,
            ),
            const SizedBox(height: 16),
            if (_isEditing) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Timer',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            _elapsedLabel,
                            style: TextStyle(
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _timerUpdating ? null : _toggleTimer,
                      icon: _timerUpdating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_timerStartedAt == null
                              ? Icons.play_arrow_rounded
                              : Icons.stop_rounded),
                      label: Text(_timerUpdating
                          ? 'Saving'
                          : _timerStartedAt == null
                              ? 'Start'
                              : 'Stop'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                if (_isVideoEditing) ...[
                  Expanded(
                    child: TextFormField(
                      controller: _videoCountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Videos'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextFormField(
                    controller: _otherTaskCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Tasks completed'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _hoursCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Hours'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppSelectField<WorkStatus>(
              value: _status,
              label: 'Status',
              options: WorkStatus.values
                  .map((s) => AppSelectOption(value: s, label: s.label))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _status = v ?? WorkStatus.pending),
            ),
            const SizedBox(height: 16),
            DateTimePickerField(date: _date, onTapDate: _pickDate),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description or notes',
                hintText:
                    'Add context, deliverables, or anything you want to remember.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Save Changes' : 'Add Work Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
