import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/backend_connection.dart';
import '../../../clients/domain/client.dart';
import '../../../clients/domain/project.dart';
import '../../../clients/presentation/providers/client_providers.dart';
import '../../../finance/domain/expense.dart';
import '../../../finance/domain/income.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../gym/presentation/providers/gym_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../reminders/domain/reminder.dart';
import '../../../reminders/presentation/providers/notification_provider.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
import '../../../work/domain/work_entry.dart';
import '../../../work/presentation/providers/work_providers.dart';
import '../../data/assistant_service.dart';
import '../../data/assistant_action_audit_log.dart';
import '../../data/offline_assistant_responder.dart';
import '../../domain/agent_contract.dart';
import '../../domain/assistant_contract.dart';
import '../providers/assistant_providers.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.initialAgent});
  final AssistantAgent? initialAgent;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatTurn> _chat = [];
  AssistantChatPhase _phase = AssistantChatPhase.idle;
  AssistantAgentAction? _draft;
  _AssistantTarget? _target;
  List<_AssistantTarget> _matches = const [];
  bool _loading = false;
  String? _error;

  static const _suggestions = [
    ('Add entry', 'Add a work log entry'),
    ('Reminder', 'Set a reminder'),
    ('Finances', 'Add an income or expense'),
    ('Review progress', 'Review my work progress'),
    ('Workout plan', 'Suggest a workout plan'),
    ('Nutrition', 'Review my nutrition today'),
    ('Monthly finances', 'Review my monthly finances'),
    ('Reminder ideas', 'Suggest helpful reminders'),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, Object?> _aggregateContext() {
    final now = DateTime.now();
    final work = ref
            .read(workEntriesForRangeProvider(
                DateRange(DateTime(now.year, now.month), now)))
            .valueOrNull ??
        const <WorkEntry>[];
    final income = ref
            .read(incomeForRangeProvider(
                DateRange(DateTime(now.year, now.month), now)))
            .valueOrNull ??
        const <Income>[];
    final expenses = ref
            .read(expensesForRangeProvider(
                DateRange(DateTime(now.year, now.month), now)))
            .valueOrNull ??
        const <Expense>[];
    final reminders =
        ref.read(upcomingRemindersProvider).valueOrNull ?? const <Reminder>[];
    final currency = ref.read(defaultCurrencyProvider);
    final workouts = ref
            .read(workoutsForRangeProvider(
                GymDateRange(DateTime(now.year, now.month), now)))
            .valueOrNull ??
        const [];
    final meals = ref
            .read(mealsForDateProvider(DateTime(now.year, now.month, now.day)))
            .valueOrNull ??
        const [];
    return {
      'work': {
        'entriesThisMonth': work.length,
        'completedThisMonth': work
            .where((e) =>
                e.status == WorkStatus.completed ||
                e.status == WorkStatus.delivered)
            .length,
        'hoursThisMonth': work.fold<double>(0, (sum, e) => sum + e.hoursWorked),
        'videosThisMonth': work.fold<int>(0, (sum, e) => sum + e.videoCount),
      },
      'finance': {
        'currencyCode': currency,
        'incomeThisMonth': income
            .where((e) => e.currency == currency)
            .fold<double>(
                0, (sum, e) => sum + Money(e.amountMinor, currency).asDouble),
        'expensesThisMonth': expenses
            .where((e) => e.currency == currency)
            .fold<double>(
                0, (sum, e) => sum + Money(e.amountMinor, currency).asDouble),
      },
      'reminders': {'upcomingCount': reminders.length},
      'gym': {
        'workoutsThisMonth': workouts.length,
        'workoutStreak': ref.read(workoutStreakProvider),
        'mealsToday': meals.length,
        'caloriesToday':
            meals.fold<double>(0, (sum, meal) => sum + meal.calories),
        'calorieTarget':
            ref.read(dietTargetProvider).valueOrNull?.dailyCalories ?? 0,
      },
    };
  }

  Map<String, Object?> _agentContext() {
    final now = DateTime.now();
    final clients =
        ref.read(clientsListProvider).valueOrNull ?? const <Client>[];
    final projects = <String>[];
    for (final client in clients.take(20)) {
      final items =
          ref.read(projectsForClientProvider(client.id)).valueOrNull ??
              const <Project>[];
      projects.addAll(items.take(10).map((item) => item.title));
    }
    return {
      'today':
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'timezone': now.timeZoneName,
      'defaultCurrency': ref.read(defaultCurrencyProvider),
      'currencies': supportedCurrencies,
      'clients':
          clients.take(20).map((item) => item.name).toList(growable: false),
      'projects': projects.take(20).toList(growable: false),
      'incomeMethods': AssistantActionRegistry.incomeMethods,
      'expenseCategories': AssistantActionRegistry.expenseCategories,
      'fieldDefinitions': AssistantActionRegistry.definitions.values
          .map((item) => item.toJson())
          .toList(growable: false),
    };
  }

  Future<void> _sendMessage([String? submitted]) async {
    final message = (submitted ?? _messageController.text).trim();
    if (message.isEmpty || _loading) return;
    _messageController.clear();
    setState(() {
      _loading = true;
      _error = null;
      _chat.add(_ChatTurn(isUser: true, text: message));
    });
    _scrollToBottom();

    if (_phase == AssistantChatPhase.confirming &&
        AssistantConfirmationGate.isYes(message)) {
      await _executePending();
      return;
    }
    if ((_phase == AssistantChatPhase.confirming ||
            _phase == AssistantChatPhase.collecting) &&
        AssistantConfirmationGate.isNo(message)) {
      setState(() {
        _loading = false;
        _phase = AssistantChatPhase.idle;
        _draft = null;
        _target = null;
        _matches = const [];
        _chat.add(
            const _ChatTurn(isUser: false, text: 'Okay, nothing was saved.'));
      });
      _scrollToBottom();
      return;
    }
    setState(() {
      if (_phase == AssistantChatPhase.confirming)
        _phase = AssistantChatPhase.collecting;
      _target = null;
      _matches = const [];
    });

    final offlineReply = BackendConnection.instance.isAvailable.value == false
        ? OfflineAssistantResponder.replyTo(message)
        : null;
    if (offlineReply != null) {
      setState(() {
        _loading = false;
        _chat.add(_ChatTurn(isUser: false, text: offlineReply));
      });
      _scrollToBottom();
      return;
    }

    try {
      final priorTurns = _chat.take(_chat.length - 1).toList(growable: false);
      final recentTurns = priorTurns.length <= 6
          ? priorTurns
          : priorTurns.sublist(priorTurns.length - 6);
      final reply = await ref.read(assistantServiceProvider).agentChat(
            message: message,
            history: recentTurns
                .map((turn) => {
                      'role': turn.isUser ? 'user' : 'assistant',
                      'text': turn.text,
                    })
                .toList(growable: false),
            context: _aggregateContext(),
            agentContext: _agentContext(),
            draft: _draft?.toJson(),
          );
      if (mounted) await _handleReply(reply);
    } catch (error) {
      if (!mounted) return;
      final offlineReply = OfflineAssistantResponder.replyTo(message);
      final text = offlineReply ??
          (error is AssistantServiceException
              ? error.message
              : 'WorkLog AI could not answer just now. Please try again.');
      setState(() {
        _error = offlineReply == null ? text : null;
        _chat.add(_ChatTurn(isUser: false, text: text));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  Future<void> _handleReply(AssistantAgentReply reply) async {
    var action = reply.action;
    if (action == null) {
      setState(() {
        _chat.add(_ChatTurn(isUser: false, text: reply.message));
        if (_draft == null) _phase = AssistantChatPhase.idle;
      });
      return;
    }
    if (action.name == AssistantActionName.cancelAction) {
      setState(() {
        _draft = null;
        _target = null;
        _matches = const [];
        _phase = AssistantChatPhase.idle;
        _chat.add(
            const _ChatTurn(isUser: false, text: 'Okay, nothing was saved.'));
      });
      return;
    }

    // Deletion and updates always pass through the explicit local find-items
    // step first; no database identifier is accepted from the model.
    if (const {
      AssistantActionName.updateWorkEntry,
      AssistantActionName.deleteWorkEntry,
      AssistantActionName.deleteFinancial,
      AssistantActionName.deleteReminder,
    }.contains(action.name)) {
      final type = switch (action.name) {
        AssistantActionName.updateWorkEntry ||
        AssistantActionName.deleteWorkEntry =>
          'work',
        AssistantActionName.deleteFinancial => action.fields['type'],
        AssistantActionName.deleteReminder => 'reminder',
        _ => null,
      };
      action = AssistantAgentAction(
        name: AssistantActionName.findItems,
        status: action.status,
        fields: {
          ...action.fields,
          'type': type,
          'requestedAction': action.name.wireName,
        },
        missing: action.missing,
        nextQuestion: action.nextQuestion,
        quickReplies: action.quickReplies,
      );
    }

    final prior = _draft?.name == action.name
        ? _draft!.fields
        : const <String, Object?>{};
    final merged = <String, Object?>{...prior, ...action.fields};
    final actualMissing = AssistantActionRegistry.missing(action.name, merged);
    final next = AssistantAgentAction(
      name: action.name,
      status:
          actualMissing.isEmpty && action.status == AssistantActionStatus.ready
              ? AssistantActionStatus.ready
              : AssistantActionStatus.collecting,
      fields: Map.unmodifiable(merged),
      missing: actualMissing.isEmpty ? action.missing : actualMissing,
      nextQuestion: action.nextQuestion,
      quickReplies: action.quickReplies,
    );
    setState(() {
      _draft = next;
      _phase = next.status == AssistantActionStatus.ready
          ? AssistantChatPhase.confirming
          : AssistantChatPhase.collecting;
      _chat.add(_ChatTurn(isUser: false, text: reply.message));
      if (next.status == AssistantActionStatus.collecting &&
          next.nextQuestion.isNotEmpty) {
        if (next.nextQuestion == reply.message &&
            next.quickReplies.isNotEmpty) {
          _chat[_chat.length - 1] = _ChatTurn(
              isUser: false,
              text: reply.message,
              quickReplies: next.quickReplies);
        } else if (next.nextQuestion != reply.message) {
          _chat.add(_ChatTurn(
              isUser: false,
              text: next.nextQuestion,
              quickReplies: next.quickReplies));
        }
      }
    });
    if (next.status == AssistantActionStatus.collecting) return;

    final validationError = _validateDraft(next);
    if (validationError != null) {
      setState(() {
        _phase = AssistantChatPhase.collecting;
        _chat.add(_ChatTurn(isUser: false, text: validationError));
      });
      return;
    }
    if (_requiresTarget(next.name)) {
      final matches = await _findTargets(next);
      if (!mounted) return;
      if (matches.isEmpty) {
        setState(() {
          _phase = AssistantChatPhase.collecting;
          _chat.add(const _ChatTurn(
              isUser: false,
              text:
                  'I couldn’t find a matching saved item. Please add a more specific task, client, amount, or date.'));
        });
      } else if (matches.length > 1) {
        setState(() {
          _matches = matches.take(5).toList(growable: false);
          _chat.add(const _ChatTurn(
              isUser: false,
              text: 'I found a few matches. Which one do you mean?'));
        });
      } else if (next.name == AssistantActionName.findItems &&
          next.fields['requestedAction'] == null) {
        setState(() {
          _chat.add(_ChatTurn(isUser: false, text: matches.first.label));
          _draft = null;
          _phase = AssistantChatPhase.idle;
        });
      } else if (next.name == AssistantActionName.findItems) {
        await _selectTarget(matches.first);
      } else {
        setState(() {
          _target = matches.first;
          _phase = AssistantChatPhase.confirming;
        });
      }
    }
  }

  String? _validateDraft(AssistantAgentAction action) {
    final fields = action.fields;
    if (action.name == AssistantActionName.addFinancial) {
      final currency = fields['currency'];
      final amount = fields['amount'];
      if (currency is String && !supportedCurrencies.contains(currency))
        return 'That currency is not supported. Choose one of: ${supportedCurrencies.join(', ')}.';
      if (amount is num && (!amount.isFinite || amount <= 0))
        return 'Please give a positive amount.';
      if (fields['type'] == 'income' && fields['method'] is! String)
        return 'Which payment method should I use? (${AssistantActionRegistry.incomeMethods.join(', ')})';
      final rawDate = fields['date'];
      final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
      if (date != null &&
          DateUtils.dateOnly(date).isAfter(DateUtils.dateOnly(DateTime.now())))
        return 'Financial records can only be dated today or earlier. What date should I use?';
    }
    if (action.name == AssistantActionName.createWorkEntry &&
        fields['hoursWorked'] is num &&
        (fields['hoursWorked'] as num) > 24)
      return 'A work entry can have at most 24 hours. How many hours should I use?';
    if (action.name == AssistantActionName.createReminder) {
      final raw = fields['dateTime'];
      final when = raw is String ? DateTime.tryParse(raw) : null;
      if (when != null && !when.isAfter(DateTime.now()))
        return 'That time has passed. What future date and time should I use?';
    }
    for (final key in ['date', 'dateTime']) {
      final raw = fields[key];
      if (raw is String && DateTime.tryParse(raw) == null)
        return 'Please give a valid ${key == 'date' ? 'date' : 'date and time'}.';
      if (key == 'date' && raw is String) {
        final date = DateTime.tryParse(raw);
        final today = DateUtils.dateOnly(DateTime.now());
        if (date != null &&
            (date.isBefore(DateTime(today.year - 2, today.month, today.day)) ||
                date.isAfter(
                    DateTime(today.year + 1, today.month, today.day)))) {
          return 'That work date is outside the date range supported by WorkLog. Please choose a date within the last two years or next year.';
        }
      }
    }
    return null;
  }

  bool _requiresTarget(AssistantActionName name) => const {
        AssistantActionName.updateWorkEntry,
        AssistantActionName.deleteWorkEntry,
        AssistantActionName.deleteFinancial,
        AssistantActionName.deleteReminder,
        AssistantActionName.findItems,
      }.contains(name);

  Future<List<_AssistantTarget>> _findTargets(
      AssistantAgentAction action) async {
    final query =
        (action.fields['targetQuery'] as String? ?? '').trim().toLowerCase();
    final type = action.fields['type'] as String?;
    if (query.isEmpty) return const [];
    final found = <_AssistantTarget>[];
    if (type == null ||
        type == 'work' ||
        action.name == AssistantActionName.updateWorkEntry ||
        action.name == AssistantActionName.deleteWorkEntry) {
      final entries = await ref.read(workRepositoryProvider).getAllEntries();
      final clients = await ref.read(clientRepositoryProvider).getAllClients();
      for (final entry in entries) {
        final client = clients.where((c) => c.id == entry.clientId).firstOrNull;
        final label =
            '${entry.taskName} · ${client?.name ?? 'Client'} · ${_dateLabel(entry.date)}';
        if (_containsQuery(label, query))
          found.add(_AssistantTarget('work', label, entry));
      }
    }
    if (type == null ||
        type == 'income' ||
        type == 'expense' ||
        action.name == AssistantActionName.deleteFinancial) {
      final repo = ref.read(financeRepositoryProvider);
      final clients = await ref.read(clientRepositoryProvider).getAllClients();
      if (type == null || type == 'income') {
        for (final item in await repo.getAllIncome()) {
          final client =
              clients.where((c) => c.id == item.clientId).firstOrNull;
          final label =
              '${Money(item.amountMinor, item.currency).format()} income · ${client?.name ?? ''} · ${item.method} · ${_dateLabel(item.date)}';
          if (_containsQuery('$label ${item.description ?? ''}', query))
            found.add(_AssistantTarget('income', label, item));
        }
      }
      if (type == null || type == 'expense') {
        for (final item in await repo.getAllExpenses()) {
          final label =
              '${Money(item.amountMinor, item.currency).format()} expense · ${item.category} · ${_dateLabel(item.date)}';
          if (_containsQuery('$label ${item.description ?? ''}', query))
            found.add(_AssistantTarget('expense', label, item));
        }
      }
    }
    if (type == null ||
        type == 'reminder' ||
        action.name == AssistantActionName.deleteReminder) {
      final reminders =
          await ref.read(reminderRepositoryProvider).watchUpcoming().first;
      for (final item in reminders) {
        final label = '${item.title} · ${_dateLabel(item.dateTime)}';
        if (_containsQuery('$label ${item.description ?? ''}', query))
          found.add(_AssistantTarget('reminder', label, item));
      }
    }
    return found;
  }

  bool _containsQuery(String source, String query) =>
      source.toLowerCase().contains(query) ||
      (query
              .split(RegExp(r'\s+'))
              .where((part) => part.length > 2)
              .isNotEmpty &&
          query
              .split(RegExp(r'\s+'))
              .where((part) => part.length > 2)
              .every((part) => source.toLowerCase().contains(part)));

  String _dateLabel(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _selectTarget(_AssistantTarget target) async {
    if (_draft?.name == AssistantActionName.findItems) {
      final findAction = _draft!;
      final requested = findAction.fields['requestedAction'];
      if (requested == null) {
        setState(() {
          _chat.add(_ChatTurn(isUser: false, text: target.label));
          _draft = null;
          _matches = const [];
          _phase = AssistantChatPhase.idle;
        });
        return;
      }
      final actionName = AssistantActionName.parse(requested);
      final allowed =
          AssistantActionRegistry.definitions[actionName]!.fields.keys;
      final fields = <String, Object?>{
        for (final entry in findAction.fields.entries)
          if (allowed.contains(entry.key)) entry.key: entry.value,
      };
      if (actionName == AssistantActionName.updateWorkEntry &&
          fields.keys.where((key) => key != 'targetQuery').isEmpty) {
        setState(() {
          _draft = AssistantAgentAction(
            name: actionName,
            status: AssistantActionStatus.collecting,
            fields: Map.unmodifiable(fields),
            missing: const ['taskName'],
            nextQuestion: 'What would you like me to change on this entry?',
          );
          _chat.add(_ChatTurn(
              isUser: false,
              text:
                  'I found ${target.label}. What would you like me to change?'));
          _target = null;
          _matches = const [];
          _phase = AssistantChatPhase.collecting;
        });
        return;
      }
      final pending = AssistantAgentAction(
        name: actionName,
        status: AssistantActionStatus.ready,
        fields: Map.unmodifiable(fields),
        missing: const [],
        nextQuestion: '',
      );
      final error = _validateDraft(pending);
      setState(() {
        _draft = pending;
        _target = error == null ? target : null;
        _matches = const [];
        _phase = error == null
            ? AssistantChatPhase.confirming
            : AssistantChatPhase.collecting;
        if (error != null) _chat.add(_ChatTurn(isUser: false, text: error));
      });
      return;
    }
    setState(() {
      _target = target;
      _matches = const [];
      _phase = AssistantChatPhase.confirming;
    });
  }

  Future<void> _executePending() async {
    final action = _draft;
    if (action == null || !AssistantConfirmationGate.mayExecute(_phase, true))
      return;
    setState(() {
      _loading = true;
      _phase = AssistantChatPhase.executing;
    });
    Future<void> Function()? undo;
    String? actionId;
    try {
      final fields = action.fields;
      switch (action.name) {
        case AssistantActionName.createWorkEntry:
          final client = await _matchClient(fields['clientName'] as String?);
          if (client == null)
            throw const FormatException(
                'I can’t match that client. Use a client name from your WorkLog list.');
          final date = DateTime.parse(fields['date'] as String);
          final work = WorkEntry(
            id: '',
            clientId: client.id,
            taskName: fields['taskName'] as String,
            workType: fields['taskName'] as String,
            hoursWorked: (fields['hoursWorked'] as num?)?.toDouble() ?? 0,
            videoCount: (fields['videoCount'] as num?)?.toInt() ?? 0,
            otherTaskCount: (fields['otherTaskCount'] as num?)?.toInt() ?? 0,
            status: WorkStatusX.fromString(fields['status'] as String?),
            date: date,
            notes: fields['notes'] as String?,
          );
          final id = await ref.read(workRepositoryProvider).addEntry(work);
          actionId = id;
          undo = () => ref.read(workRepositoryProvider).deleteEntry(id);
          ref.invalidate(recentWorkEntriesProvider);
          ref.invalidate(workEntriesForRangeProvider);
          break;
        case AssistantActionName.updateWorkEntry:
          final old = _target?.value as WorkEntry?;
          if (old == null)
            throw const FormatException(
                'Please find the work entry again before updating it.');
          final client = fields['clientName'] == null
              ? null
              : await _matchClient(fields['clientName'] as String);
          if (fields['clientName'] != null && client == null)
            throw const FormatException('I can’t match that client name.');
          final updated = WorkEntry(
            id: old.id,
            clientId: client?.id ?? old.clientId,
            projectId: old.projectId,
            taskName: fields['taskName'] as String? ?? old.taskName,
            workType: fields['taskName'] as String? ?? old.workType,
            videoCount:
                (fields['videoCount'] as num?)?.toInt() ?? old.videoCount,
            otherTaskCount: (fields['otherTaskCount'] as num?)?.toInt() ??
                old.otherTaskCount,
            hoursWorked:
                (fields['hoursWorked'] as num?)?.toDouble() ?? old.hoursWorked,
            status: fields['status'] is String
                ? WorkStatusX.fromString(fields['status'] as String)
                : old.status,
            date: fields['date'] is String
                ? DateTime.parse(fields['date'] as String)
                : old.date,
            dueDate: old.dueDate,
            completionDate: old.completionDate,
            notes: fields['notes'] as String? ?? old.notes,
            createdAt: old.createdAt,
          );
          await ref.read(workRepositoryProvider).updateEntry(updated);
          actionId = old.id;
          undo = () => ref.read(workRepositoryProvider).updateEntry(old);
          ref.invalidate(recentWorkEntriesProvider);
          ref.invalidate(workEntriesForRangeProvider);
          break;
        case AssistantActionName.deleteWorkEntry:
          final item = _target?.value as WorkEntry?;
          if (item == null)
            throw const FormatException(
                'Please find the work entry again before deleting it.');
          await ref.read(workRepositoryProvider).deleteEntry(item.id);
          actionId = item.id;
          undo = () async {
            await ref.read(workRepositoryProvider).addEntry(item);
          };
          ref.invalidate(recentWorkEntriesProvider);
          ref.invalidate(workEntriesForRangeProvider);
          break;
        case AssistantActionName.addFinancial:
          final amount = (fields['amount'] as num).toDouble();
          final currency = fields['currency'] as String;
          final date = DateTime.parse(fields['date'] as String);
          final finance = ref.read(financeRepositoryProvider);
          if (fields['type'] == 'income') {
            final name = (fields['clientName'] ?? fields['source']) as String;
            final client = await _matchClient(name);
            if (client == null)
              throw const FormatException(
                  'I can’t match that client/source to a saved client.');
            final projectId =
                await _matchProject(client, fields['projectName'] as String?);
            final income = Income(
              id: '',
              clientId: client.id,
              projectId: projectId,
              amountMinor: Money.toMinorUnits(amount, currency),
              currency: currency,
              date: date,
              method: fields['method'] as String,
              description: fields['description'] as String?,
              notes: fields['notes'] as String?,
            );
            final id = await finance.addIncome(income);
            actionId = id;
            undo = () => finance.deleteIncome(id);
          } else {
            final expense = Expense(
              id: '',
              amountMinor: Money.toMinorUnits(amount, currency),
              currency: currency,
              date: date,
              category: fields['category'] as String,
              description: fields['description'] as String?,
              notes: fields['notes'] as String?,
            );
            final id = await finance.addExpense(expense);
            actionId = id;
            undo = () => finance.deleteExpense(id);
          }
          ref.invalidate(incomeForRangeProvider);
          ref.invalidate(expensesForRangeProvider);
          ref.invalidate(clientsListProvider);
          break;
        case AssistantActionName.deleteFinancial:
          final target = _target;
          if (target?.value is Income) {
            final item = target!.value as Income;
            await ref.read(financeRepositoryProvider).deleteIncome(item.id);
            actionId = item.id;
            undo = () async {
              await ref.read(financeRepositoryProvider).addIncome(item);
            };
          } else if (target?.value is Expense) {
            final item = target!.value as Expense;
            await ref.read(financeRepositoryProvider).deleteExpense(item.id);
            actionId = item.id;
            undo = () async {
              await ref.read(financeRepositoryProvider).addExpense(item);
            };
          } else {
            throw const FormatException(
                'Please find the financial record again before deleting it.');
          }
          ref.invalidate(incomeForRangeProvider);
          ref.invalidate(expensesForRangeProvider);
          ref.invalidate(clientsListProvider);
          break;
        case AssistantActionName.createReminder:
          final client = fields['clientName'] == null
              ? null
              : await _matchClient(fields['clientName'] as String);
          if (fields['clientName'] != null && client == null)
            throw const FormatException('I can’t match that client name.');
          final reminder = Reminder(
            id: '',
            title: fields['title'] as String,
            description: fields['description'] as String?,
            dateTime: DateTime.parse(fields['dateTime'] as String).toLocal(),
            clientId: client?.id,
            priority:
                ReminderPriorityX.fromString(fields['priority'] as String?),
            repeat: RepeatOptionX.fromString(fields['repeat'] as String?),
          );
          final id =
              await ref.read(reminderRepositoryProvider).addReminder(reminder);
          final savedReminder = Reminder(
            id: id,
            title: reminder.title,
            description: reminder.description,
            dateTime: reminder.dateTime,
            clientId: reminder.clientId,
            priority: reminder.priority,
            repeat: reminder.repeat,
          );
          actionId = id;
          undo = () async {
            await ref.read(reminderRepositoryProvider).deleteReminder(id);
            try {
              await ref
                  .read(notificationServiceProvider)
                  .cancel(savedReminder.notificationId);
            } catch (_) {
              // The reminder deletion is still undone if OS cleanup fails.
            }
          };
          try {
            await ref
                .read(notificationServiceProvider)
                .scheduleForReminder(savedReminder);
          } catch (_) {
            // The saved reminder is still valid if OS notification permission is unavailable.
          }
          ref.invalidate(upcomingRemindersProvider);
          break;
        case AssistantActionName.deleteReminder:
          final item = _target?.value as Reminder?;
          if (item == null)
            throw const FormatException(
                'Please find the reminder again before deleting it.');
          await ref.read(reminderRepositoryProvider).deleteReminder(item.id);
          try {
            await ref
                .read(notificationServiceProvider)
                .cancel(item.notificationId);
          } catch (_) {
            // Removing the reminder is still successful if notification cleanup fails.
          }
          actionId = item.id;
          undo = () async {
            final id =
                await ref.read(reminderRepositoryProvider).addReminder(item);
            try {
              await ref
                  .read(notificationServiceProvider)
                  .scheduleForReminder(Reminder(
                    id: id,
                    title: item.title,
                    description: item.description,
                    dateTime: item.dateTime,
                    clientId: item.clientId,
                    projectId: item.projectId,
                    priority: item.priority,
                    repeat: item.repeat,
                  ));
            } catch (_) {
              // The restored reminder remains saved if OS scheduling fails.
            }
          };
          ref.invalidate(upcomingRemindersProvider);
          break;
        case AssistantActionName.findItems:
        case AssistantActionName.cancelAction:
          return;
      }
      try {
        await AssistantActionAuditLog()
            .record(action: action.name.wireName, id: actionId);
      } catch (_) {
        // Audit persistence must not misreport an already completed app write.
      }
      if (!mounted) return;
      setState(() {
        _phase = AssistantChatPhase.idle;
        _draft = null;
        _target = null;
        _matches = const [];
        _chat.add(const _ChatTurn(
            isUser: false, text: 'Done — the change was saved.'));
      });
      _showUndoSnack(action.name.wireName, actionId, undo);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = AssistantChatPhase.collecting;
        _chat.add(_ChatTurn(
            isUser: false,
            text: error is FormatException
                ? error.message
                : 'I couldn’t complete that action. Your saved data is unchanged; please try again.'));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _showUndoSnack(String action, String id, Future<void> Function() undo) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Done — the change was saved.'),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => unawaited(_undo(action, id, undo)),
      ),
    ));
  }

  Future<void> _undo(
      String action, String id, Future<void> Function() undo) async {
    try {
      await undo();
      ref.invalidate(recentWorkEntriesProvider);
      ref.invalidate(workEntriesForRangeProvider);
      ref.invalidate(incomeForRangeProvider);
      ref.invalidate(expensesForRangeProvider);
      ref.invalidate(upcomingRemindersProvider);
      ref.invalidate(clientsListProvider);
      await AssistantActionAuditLog().record(action: 'undo_$action', id: id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Undone.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not undo that change.')),
        );
      }
    }
  }

  Future<Client?> _matchClient(String? name) async {
    if (name == null || name.trim().isEmpty) return null;
    final clients = await ref.read(clientRepositoryProvider).getAllClients();
    final matches = clients
        .where((item) =>
            item.name.trim().toLowerCase() == name.trim().toLowerCase())
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  Future<String?> _matchProject(Client client, String? name) async {
    if (name == null || name.trim().isEmpty) return null;
    final projects =
        await ref.read(projectsForClientProvider(client.id).future);
    final matches = projects
        .where((item) =>
            item.title.trim().toLowerCase() == name.trim().toLowerCase())
        .toList();
    if (matches.length != 1)
      throw const FormatException(
          'I can’t match that project to the selected client.');
    return matches.single.id;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients)
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
    });
  }

  String _confirmationTitle() {
    final draft = _draft!;
    final f = draft.fields;
    switch (draft.name) {
      case AssistantActionName.createWorkEntry:
        return 'Add work entry';
      case AssistantActionName.updateWorkEntry:
        return 'Update work entry';
      case AssistantActionName.deleteWorkEntry:
        return 'Delete work entry';
      case AssistantActionName.addFinancial:
        return 'Add ${f['type']} record';
      case AssistantActionName.deleteFinancial:
        return 'Delete ${f['type']} record';
      case AssistantActionName.createReminder:
        return 'Create reminder';
      case AssistantActionName.deleteReminder:
        return 'Delete reminder';
      case AssistantActionName.findItems:
        return 'Find saved item';
      case AssistantActionName.cancelAction:
        return 'Cancel';
    }
  }

  List<String> _confirmationDetails() {
    final draft = _draft!;
    final f = draft.fields;
    final target = _target;
    switch (draft.name) {
      case AssistantActionName.createWorkEntry:
        return [
          '${f['taskName']} · ${f['clientName']}',
          '${f['hoursWorked'] ?? 0} hours · ${f['date']}',
          if (f['videoCount'] != null) 'Videos: ${f['videoCount']}',
          if (f['otherTaskCount'] != null)
            'Other tasks: ${f['otherTaskCount']}',
          if (f['status'] != null) 'Status: ${f['status']}',
          if (f['notes'] != null) 'Notes: ${f['notes']}',
        ];
      case AssistantActionName.updateWorkEntry:
        return [
          target?.label ?? 'Work entry',
          if (f['taskName'] != null) 'Task: ${f['taskName']}',
          if (f['clientName'] != null) 'Client: ${f['clientName']}',
          if (f['date'] != null) 'Date: ${f['date']}',
          if (f['hoursWorked'] != null) 'Hours: ${f['hoursWorked']}',
          if (f['videoCount'] != null) 'Videos: ${f['videoCount']}',
          if (f['status'] != null) 'Status: ${f['status']}',
          if (f['notes'] != null) 'Notes: ${f['notes']}',
        ];
      case AssistantActionName.deleteWorkEntry:
      case AssistantActionName.deleteFinancial:
      case AssistantActionName.deleteReminder:
        return [target?.label ?? (f['targetQuery'] as String? ?? '')];
      case AssistantActionName.addFinancial:
        return [
          '${Money(Money.toMinorUnits((f['amount'] as num).toDouble(), f['currency'] as String), f['currency'] as String).format()} (${f['currency']}) · ${f['type']}',
          '${f['date']} · ${f['clientName'] ?? f['category'] ?? f['source']}',
          if (f['method'] != null) 'Method: ${f['method']}',
          if (f['projectName'] != null) 'Project: ${f['projectName']}',
          if (f['description'] != null) 'Description: ${f['description']}',
          if (f['notes'] != null) 'Notes: ${f['notes']}',
        ];
      case AssistantActionName.createReminder:
        final reminderTime = DateTime.parse(f['dateTime'] as String).toLocal();
        final localizations = MaterialLocalizations.of(context);
        return [
          '${f['title']}',
          '${localizations.formatMediumDate(reminderTime)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(reminderTime))}',
          if (f['repeat'] != null && f['repeat'] != 'none')
            'Repeats ${f['repeat']}',
          if (f['priority'] != null) 'Priority: ${f['priority']}',
          if (f['clientName'] != null) 'Client: ${f['clientName']}',
          if (f['description'] != null) 'Description: ${f['description']}',
        ];
      case AssistantActionName.findItems:
      case AssistantActionName.cancelAction:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = DateRange(DateTime(now.year, now.month), now);
    ref.watch(workEntriesForRangeProvider(month));
    ref.watch(recentWorkEntriesProvider);
    ref.watch(incomeForRangeProvider(month));
    ref.watch(expensesForRangeProvider(month));
    ref.watch(upcomingRemindersProvider);
    ref.watch(workoutsForRangeProvider(
        GymDateRange(DateTime(now.year, now.month), now)));
    ref.watch(mealsForDateProvider(DateTime(now.year, now.month, now.day)));
    ref.watch(dietTargetProvider);
    ref.watch(clientsListProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ask WorkLog')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final item in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(item.$1),
                      backgroundColor: scheme.surfaceContainerHigh,
                      side: BorderSide(color: scheme.outlineVariant),
                      labelStyle: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: scheme.onSurface),
                      onPressed: _loading ? null : () => _sendMessage(item.$2),
                    ),
                  )
              ],
            ),
          ),
        ),
        Expanded(
            child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            if (_chat.isEmpty)
              _ChatBubble(
                  turn: _ChatTurn(
                      isUser: false,
                      text: widget.initialAgent == null
                          ? 'Hi! I can help with work entries, finances, reminders, and using WorkLog. What would you like to do?'
                          : 'Hi! I can help with ${widget.initialAgent!.label.toLowerCase()} and anything else in WorkLog. What would you like to do?')),
            for (final turn in _chat)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChatBubble(turn: turn),
                  if (!turn.isUser && turn.quickReplies.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final reply in turn.quickReplies)
                            ActionChip(
                              label: Text(reply),
                              backgroundColor: scheme.surfaceContainerHigh,
                              side: BorderSide(color: scheme.outlineVariant),
                              labelStyle: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: scheme.onSurface),
                              onPressed:
                                  _loading ? null : () => _sendMessage(reply),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            if (_loading) const _ThinkingBubble(),
            if (_matches.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final target in _matches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed:
                            _loading ? null : () => _selectTarget(target),
                        child: Text(target.label),
                      )),
                ),
            ],
            if (_phase == AssistantChatPhase.confirming && _draft != null)
              _ConfirmationCard(
                title: _confirmationTitle(),
                details: _confirmationDetails(),
                onSave: _loading ? null : _executePending,
                onEdit: _loading
                    ? null
                    : () => setState(() {
                          _phase = AssistantChatPhase.collecting;
                          _target = null;
                          _chat.add(const _ChatTurn(
                              isUser: false,
                              text: 'Tell me what you’d like to change.'));
                        }),
                onCancel: _loading ? null : () => _sendMessage('no'),
              ),
            if (_error != null && _chat.isEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: scheme.error))),
          ],
        )),
        SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Ask WorkLog…',
                  filled: true,
                  fillColor: scheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28)),
                  suffixIcon: IconButton(
                    tooltip: 'Send message',
                    onPressed: _loading ? null : _sendMessage,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ),
            )),
      ]),
    );
  }
}

class _ChatTurn {
  const _ChatTurn(
      {required this.isUser, required this.text, this.quickReplies = const []});
  final bool isUser;
  final String text;
  final List<String> quickReplies;
}

class _AssistantTarget {
  const _AssistantTarget(this.type, this.label, this.value);
  final String type;
  final String label;
  final Object value;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.turn});
  final _ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: turn.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: turn.isUser
              ? colors.primaryContainer
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(turn.text,
            style: TextStyle(
              color: turn.isUser ? colors.onPrimaryContainer : colors.onSurface,
              height: 1.35,
            )),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 9),
            Text('Thinking…', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard(
      {required this.title,
      required this.details,
      required this.onSave,
      required this.onEdit,
      required this.onCancel});
  final String title;
  final List<String> details;
  final VoidCallback? onSave;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Card(
        color: colors.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Review this change?',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 5),
                    for (final line in details)
                      Text(line, style: Theme.of(context).textTheme.bodyMedium),
                  ]),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              OutlinedButton(onPressed: onSave, child: const Text('Yes, save')),
              OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
              TextButton(onPressed: onCancel, child: const Text('No')),
            ]),
          ]),
        ),
      ),
    );
  }
}
