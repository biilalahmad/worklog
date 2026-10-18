import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/client_picker_field.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../../core/widgets/date_time_picker_field.dart';
import '../../../clients/presentation/providers/client_providers.dart';
import '../../domain/reminder.dart';
import '../providers/notification_provider.dart';
import '../providers/reminder_providers.dart';
import '../../../../core/errors/failure.dart';
import '../../../../services/notifications/notification_service.dart';

class ReminderFormScreen extends ConsumerStatefulWidget {
  final Reminder? reminder;
  const ReminderFormScreen({super.key, this.reminder});

  @override
  ConsumerState<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends ConsumerState<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleCtrl =
      TextEditingController(text: widget.reminder?.title ?? '');
  late final _descCtrl =
      TextEditingController(text: widget.reminder?.description ?? '');
  late DateTime _date =
      widget.reminder?.dateTime ?? DateTime.now().add(const Duration(hours: 1));
  late TimeOfDay _time = TimeOfDay.fromDateTime(widget.reminder?.dateTime ??
      DateTime.now().add(const Duration(hours: 1)));
  String? _clientId;
  late ReminderPriority _priority =
      widget.reminder?.priority ?? ReminderPriority.medium;
  late RepeatOption _repeat = widget.reminder?.repeat ?? RepeatOption.none;
  bool _saving = false;

  bool get _isEditing => widget.reminder != null;

  @override
  void initState() {
    super.initState();
    _clientId = widget.reminder?.clientId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  DateTime get _combined =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    final lastDate = today.add(const Duration(days: 365 * 2));
    var selectedDate = _date.isBefore(firstDate) ? firstDate : _date;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final media = MediaQuery.of(dialogContext);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 1,
              maxScaleFactor: 1.1,
            ),
          ),
          child: Theme(
            data: theme.copyWith(
              datePickerTheme: DatePickerThemeData(
                backgroundColor: theme.colorScheme.surface,
                headerBackgroundColor: theme.colorScheme.primary,
                headerForegroundColor: theme.colorScheme.onPrimary,
              ),
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) => Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Select date',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        CalendarDatePicker(
                          initialDate: selectedDate,
                          firstDate: firstDate,
                          lastDate: lastDate,
                          onDateChanged: (date) =>
                              setDialogState(() => selectedDate = date),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(selectedDate),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_combined.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future date and time.')),
      );
      return;
    }
    final repo = ref.read(reminderRepositoryProvider);
    final notifications = ref.read(notificationServiceProvider);
    final wasEditing = _isEditing;
    setState(() => _saving = true);
    late final Reminder savedReminder;
    try {
      final reminder = Reminder(
        id: widget.reminder?.id ?? '',
        title: _titleCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        dateTime: _combined,
        clientId: _clientId,
        priority: _priority,
        repeat: _repeat,
        completed: widget.reminder?.completed ?? false,
      );
      final String id;
      if (_isEditing) {
        await repo.updateReminder(reminder);
        id = reminder.id;
      } else {
        id = await repo.addReminder(reminder);
      }
      savedReminder = Reminder(
        id: id,
        title: reminder.title,
        description: reminder.description,
        dateTime: reminder.dateTime,
        clientId: reminder.clientId,
        priority: reminder.priority,
        repeat: reminder.repeat,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Could not save reminder: ${Failure.from(e).message}'),
        ));
      }
      return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    context.pop();

    // Saving the reminder must not keep the form (or the Home screen behind
    // it) waiting on Android permission/settings UI. Persist first, return to
    // the app immediately, then schedule notifications and report any issue.
    unawaited(_scheduleSavedReminder(
      notifications,
      savedReminder,
      messenger,
      reschedule: wasEditing,
    ));
  }

  Future<void> _scheduleSavedReminder(
    NotificationService notifications,
    Reminder reminder,
    ScaffoldMessengerState messenger, {
    required bool reschedule,
  }) async {
    try {
      if (reschedule) {
        await notifications.cancelReminderNotifications(reminder);
      }
      final outcome = await notifications.scheduleForReminder(reminder);
      if (!messenger.mounted) return;
      switch (outcome) {
        case ReminderScheduleOutcome.exact:
          return;
        case ReminderScheduleOutcome.approximate:
          messenger.showSnackBar(const SnackBar(
            content: Text(
                'Reminder saved. Android may deliver its notification a little late because precise alarm access is off.'),
          ));
        case ReminderScheduleOutcome.notificationsDisabled:
          messenger.showSnackBar(const SnackBar(
            content: Text(
                'Reminder saved, but notifications are disabled. Enable them in WorkLog settings to receive alerts.'),
          ));
      }
    } catch (error, stackTrace) {
      debugPrint('WorkLog reminder was saved, but scheduling failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!messenger.mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Reminder saved, but its notification could not be scheduled. Check notification permissions and try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsListProvider);

    return Scaffold(
      appBar:
          AppBar(title: Text(_isEditing ? 'Edit Reminder' : 'New Reminder')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            DateTimePickerField(
              date: _date,
              time: _time,
              onTapDate: _pickDate,
              onTapTime: _pickTime,
              label: 'Reminder date & time',
            ),
            const SizedBox(height: 16),
            clientsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(Failure.from(e).message),
              data: (clients) => ClientPickerField(
                clients: clients,
                initialClientId: _clientId,
                required: false,
                label: 'Related client (optional)',
                maxOptionsHeight: 190,
                onChanged: (id) => setState(() => _clientId = id),
              ),
            ),
            const SizedBox(height: 24),
            AppSelectField<ReminderPriority>(
              value: _priority,
              label: 'Priority',
              options: ReminderPriority.values
                  .map((p) => AppSelectOption(value: p, label: p.label))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _priority = v ?? ReminderPriority.medium),
            ),
            const SizedBox(height: 16),
            AppSelectField<RepeatOption>(
              value: _repeat,
              label: 'Repeat',
              options: RepeatOption.values
                  .map((r) => AppSelectOption(value: r, label: r.label))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _repeat = v ?? RepeatOption.none),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Save Changes' : 'Add Reminder'),
            ),
          ],
        ),
      ),
    );
  }
}
