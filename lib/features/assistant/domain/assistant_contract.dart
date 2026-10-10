enum AssistantAgent {
  gym('Gym coach', 'gym'),
  nutrition('Nutrition coach', 'nutrition'),
  work('Work planner', 'work'),
  finance('Finance insights', 'finance'),
  reminders('Reminder planner', 'reminders');

  const AssistantAgent(this.label, this.wireValue);
  final String label;
  final String wireValue;
}

enum AssistantTask {
  workoutPlan('Suggest a workout plan', 'workout_plan', AssistantAgent.gym),
  nutritionTips(
      'Review today’s nutrition', 'nutrition_tips', AssistantAgent.nutrition),
  workReview('Review work progress', 'work_review', AssistantAgent.work),
  financeReview(
      'Review monthly finances', 'finance_review', AssistantAgent.finance),
  reminderIdeas(
      'Suggest helpful reminders', 'reminder_ideas', AssistantAgent.reminders);

  const AssistantTask(this.label, this.wireValue, this.agent);
  final String label;
  final String wireValue;
  final AssistantAgent agent;
}

/// Defends against accidental inclusion of arbitrary values in the payload.
/// Only non-identifying aggregate metrics and a currency code are forwarded.
class AssistantMetrics {
  static const _keys = <String, Set<String>>{
    'gym': {
      'workoutsThisMonth',
      'workoutStreak',
      'mealsToday',
      'caloriesToday',
      'calorieTarget',
    },
    'work': {
      'entriesThisMonth',
      'completedThisMonth',
      'hoursThisMonth',
      'videosThisMonth',
    },
    'finance': {'incomeThisMonth', 'expensesThisMonth'},
    'reminders': {'upcomingCount'},
  };

  static Map<String, Object?> sanitize(Map<String, Object?> input) {
    final result = <String, Object?>{};
    for (final section in _keys.entries) {
      final raw = input[section.key];
      if (raw is! Map) continue;
      final values = <String, Object?>{};
      for (final key in section.value) {
        final value = raw[key];
        if (value is num && value.isFinite) {
          values[key] = value.clamp(0, 1000000);
        }
      }
      if (section.key == 'finance') {
        final code = raw['currencyCode'];
        if (code is String && RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
          values['currencyCode'] = code;
        }
      }
      if (values.isNotEmpty) {
        result[section.key] = Map<String, Object?>.unmodifiable(values);
      }
    }
    return Map<String, Object?>.unmodifiable(result);
  }
}

class AssistantDraftAction {
  const AssistantDraftAction({
    required this.operation,
    required this.domain,
    required this.title,
    required this.details,
    this.fields = const {},
  });

  final String operation;
  final String domain;
  final String title;
  final String details;
  final Map<String, dynamic> fields;

  factory AssistantDraftAction.fromJson(Map<String, dynamic> json) {
    const domains = {
      'gym',
      'nutrition',
      'work',
      'finance',
      'clients',
      'reminders'
    };
    final operation = json['operation'];
    final domain = json['domain'];
    final title = json['title'];
    final details = json['details'];
    final rawFields = json['fields'];
    if (operation != 'create' && operation != 'update') {
      throw const FormatException('Unsupported assistant operation');
    }
    if (domain is! String || !domains.contains(domain)) {
      throw const FormatException('Unsupported assistant domain');
    }
    if (title is! String ||
        title.trim().isEmpty ||
        title.length > 100 ||
        details is! String ||
        details.length > 700) {
      throw const FormatException('Invalid assistant draft');
    }
    if (rawFields != null && rawFields is! Map<String, dynamic>) {
      throw const FormatException('Invalid assistant draft fields');
    }
    return AssistantDraftAction(
      operation: operation,
      domain: domain,
      title: title.trim(),
      details: details.trim(),
      fields: rawFields == null ? const {} : Map.unmodifiable(rawFields),
    );
  }
}

class AssistantReply {
  const AssistantReply({required this.summary, required this.actions});
  final String summary;
  final List<AssistantDraftAction> actions;

  factory AssistantReply.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    final rawActions = json['actions'];
    if (summary is! String ||
        summary.trim().isEmpty ||
        summary.length > 3000 ||
        rawActions is! List ||
        rawActions.length > 3) {
      throw const FormatException('Invalid assistant response');
    }
    return AssistantReply(
      summary: summary.trim(),
      actions: rawActions.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid assistant action');
        }
        return AssistantDraftAction.fromJson(item);
      }).toList(growable: false),
    );
  }
}
