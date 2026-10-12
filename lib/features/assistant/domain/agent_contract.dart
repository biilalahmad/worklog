import '../../../core/utils/money.dart';

/// The only actions the assistant may propose. This list is also sent to the
/// server to build the Gemini response schema, so the model and client agree.
enum AssistantActionName {
  createWorkEntry,
  updateWorkEntry,
  deleteWorkEntry,
  addFinancial,
  deleteFinancial,
  createReminder,
  deleteReminder,
  findItems,
  cancelAction;

  String get wireName => switch (this) {
        createWorkEntry => 'create_work_entry',
        updateWorkEntry => 'update_work_entry',
        deleteWorkEntry => 'delete_work_entry',
        addFinancial => 'add_financial',
        deleteFinancial => 'delete_financial',
        createReminder => 'create_reminder',
        deleteReminder => 'delete_reminder',
        findItems => 'find_items',
        cancelAction => 'cancel_action',
      };

  static AssistantActionName parse(Object? value) => values.firstWhere(
        (item) => item.wireName == value,
        orElse: () =>
            throw const FormatException('Unsupported assistant action'),
      );
}

enum AssistantActionStatus { collecting, ready }

/// Field definitions are the single source used by client-side validation and
/// the server-provided model context. Required fields follow the real forms and
/// typed domain models; enums mirror the options shown in those forms.
class AssistantActionDefinition {
  const AssistantActionDefinition(this.name, this.fields);
  final AssistantActionName name;
  final Map<String, AssistantFieldDefinition> fields;

  List<String> get requiredFields => fields.entries
      .where((entry) => entry.value.required)
      .map((entry) => entry.key)
      .toList(growable: false);

  Map<String, Object?> toJson() => {
        'action': name.wireName,
        'fields': fields.map((key, value) => MapEntry(key, value.toJson())),
      };
}

class AssistantFieldDefinition {
  const AssistantFieldDefinition(this.type,
      {this.required = false, this.enumValues = const []});
  final String type;
  final bool required;
  final List<String> enumValues;

  Map<String, Object?> toJson() => {
        'type': type,
        'required': required,
        if (enumValues.isNotEmpty) 'enum': enumValues,
      };
}

class AssistantActionRegistry {
  static const incomeMethods = [
    'Bank Transfer',
    'Easypaisa',
    'JazzCash',
    'Fiverr',
    'PayPal',
    'Cash',
    'Other'
  ];
  static const expenseCategories = [
    'Software/Subscriptions',
    'Equipment',
    'Internet/Utilities',
    'Marketing',
    'Travel',
    'Other'
  ];
  static const workStatuses = [
    'pending',
    'inProgress',
    'completed',
    'delivered',
    'revisionRequired'
  ];
  static const priorities = ['low', 'medium', 'high'];
  static const repeats = ['none', 'daily', 'weekly', 'monthly'];

  static const definitions = <AssistantActionName, AssistantActionDefinition>{
    AssistantActionName.createWorkEntry:
        AssistantActionDefinition(AssistantActionName.createWorkEntry, {
      'taskName': AssistantFieldDefinition('string', required: true),
      'clientName': AssistantFieldDefinition('string', required: true),
      'date': AssistantFieldDefinition('date', required: true),
      'hoursWorked': AssistantFieldDefinition('number'),
      'videoCount': AssistantFieldDefinition('integer'),
      'otherTaskCount': AssistantFieldDefinition('integer'),
      'status': AssistantFieldDefinition('string', enumValues: workStatuses),
      'notes': AssistantFieldDefinition('string'),
    }),
    AssistantActionName.updateWorkEntry:
        AssistantActionDefinition(AssistantActionName.updateWorkEntry, {
      'targetQuery': AssistantFieldDefinition('string', required: true),
      'taskName': AssistantFieldDefinition('string'),
      'clientName': AssistantFieldDefinition('string'),
      'date': AssistantFieldDefinition('date'),
      'hoursWorked': AssistantFieldDefinition('number'),
      'videoCount': AssistantFieldDefinition('integer'),
      'otherTaskCount': AssistantFieldDefinition('integer'),
      'status': AssistantFieldDefinition('string', enumValues: workStatuses),
      'notes': AssistantFieldDefinition('string'),
    }),
    AssistantActionName.deleteWorkEntry:
        AssistantActionDefinition(AssistantActionName.deleteWorkEntry, {
      'targetQuery': AssistantFieldDefinition('string', required: true),
    }),
    AssistantActionName.addFinancial:
        AssistantActionDefinition(AssistantActionName.addFinancial, {
      'type': AssistantFieldDefinition('string',
          required: true, enumValues: ['income', 'expense']),
      'amount': AssistantFieldDefinition('number', required: true),
      'currency': AssistantFieldDefinition('string',
          required: true, enumValues: supportedCurrencies),
      'date': AssistantFieldDefinition('date', required: true),
      'clientName': AssistantFieldDefinition('string'),
      'source': AssistantFieldDefinition('string'),
      'category':
          AssistantFieldDefinition('string', enumValues: expenseCategories),
      'method': AssistantFieldDefinition('string', enumValues: incomeMethods),
      'projectName': AssistantFieldDefinition('string'),
      'description': AssistantFieldDefinition('string'),
      'notes': AssistantFieldDefinition('string'),
    }),
    AssistantActionName.deleteFinancial:
        AssistantActionDefinition(AssistantActionName.deleteFinancial, {
      'type': AssistantFieldDefinition('string',
          required: true, enumValues: ['income', 'expense']),
      'targetQuery': AssistantFieldDefinition('string', required: true),
    }),
    AssistantActionName.createReminder:
        AssistantActionDefinition(AssistantActionName.createReminder, {
      'title': AssistantFieldDefinition('string', required: true),
      'dateTime': AssistantFieldDefinition('datetime', required: true),
      'description': AssistantFieldDefinition('string'),
      'clientName': AssistantFieldDefinition('string'),
      'priority': AssistantFieldDefinition('string', enumValues: priorities),
      'repeat': AssistantFieldDefinition('string', enumValues: repeats),
    }),
    AssistantActionName.deleteReminder:
        AssistantActionDefinition(AssistantActionName.deleteReminder, {
      'targetQuery': AssistantFieldDefinition('string', required: true),
    }),
    AssistantActionName.findItems:
        AssistantActionDefinition(AssistantActionName.findItems, {
      'type': AssistantFieldDefinition('string',
          required: true,
          enumValues: ['work', 'income', 'expense', 'reminder']),
      'targetQuery': AssistantFieldDefinition('string', required: true),
      'requestedAction': AssistantFieldDefinition('string', enumValues: [
        'update_work_entry',
        'delete_work_entry',
        'delete_financial',
        'delete_reminder',
      ]),
      'taskName': AssistantFieldDefinition('string'),
      'clientName': AssistantFieldDefinition('string'),
      'date': AssistantFieldDefinition('date'),
      'hoursWorked': AssistantFieldDefinition('number'),
      'videoCount': AssistantFieldDefinition('integer'),
      'otherTaskCount': AssistantFieldDefinition('integer'),
      'status': AssistantFieldDefinition('string', enumValues: workStatuses),
      'notes': AssistantFieldDefinition('string'),
    }),
    AssistantActionName.cancelAction:
        AssistantActionDefinition(AssistantActionName.cancelAction, const {}),
  };

  static List<String> missing(
      AssistantActionName action, Map<String, Object?> fields) {
    final required = definitions[action]!.requiredFields;
    final result = required.where((key) {
      final value = fields[key];
      return value == null || value is String && value.trim().isEmpty;
    }).toList();
    if (action == AssistantActionName.addFinancial &&
        fields['type'] == 'income') {
      if ((fields['clientName'] ?? fields['source']) == null)
        result.add('clientName');
      if (fields['method'] == null) result.add('method');
    }
    if (action == AssistantActionName.addFinancial &&
        fields['type'] == 'expense' &&
        fields['category'] == null) {
      result.add('category');
    }
    return result;
  }
}

class AssistantAgentAction {
  const AssistantAgentAction({
    required this.name,
    required this.status,
    required this.fields,
    required this.missing,
    required this.nextQuestion,
    this.quickReplies = const [],
  });

  final AssistantActionName name;
  final AssistantActionStatus status;
  final Map<String, Object?> fields;
  final List<String> missing;
  final String nextQuestion;
  final List<String> quickReplies;

  Map<String, Object?> toJson() => {
        'name': name.wireName,
        'status': status.name,
        'fields': fields,
        'missing': missing,
        'next_question': nextQuestion,
        'quick_replies': quickReplies,
      };

  factory AssistantAgentAction.fromJson(Object? value) {
    if (value == null) throw const FormatException('Missing action value');
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference({
          'name',
          'status',
          'fields',
          'missing',
          'next_question',
          'quick_replies'
        }).isNotEmpty ||
        !value.keys.toSet().containsAll({
          'name',
          'status',
          'fields',
          'missing',
          'next_question',
          'quick_replies'
        })) {
      throw const FormatException('Invalid assistant action');
    }
    final name = AssistantActionName.parse(value['name']);
    final status = switch (value['status']) {
      'collecting' => AssistantActionStatus.collecting,
      'ready' => AssistantActionStatus.ready,
      _ => throw const FormatException('Invalid assistant action status'),
    };
    final rawFields = value['fields'];
    if (rawFields is! Map<String, dynamic>)
      throw const FormatException('Invalid assistant action fields');
    final allowed =
        AssistantActionRegistry.definitions[name]!.fields.keys.toSet();
    if (rawFields.keys.any((key) => !allowed.contains(key)) ||
        rawFields.values.any((value) =>
            value is! String &&
            value is! num &&
            value is! bool &&
            value != null)) {
      throw const FormatException('Unexpected assistant action field');
    }
    for (final entry in rawFields.entries) {
      final definition =
          AssistantActionRegistry.definitions[name]!.fields[entry.key]!;
      final field = entry.value;
      if (field == null) continue;
      if (definition.type == 'string' && field is! String ||
          (definition.type == 'date' || definition.type == 'datetime') &&
              (field is! String || DateTime.tryParse(field) == null) ||
          (definition.type == 'number' || definition.type == 'integer') &&
              field is! num ||
          definition.type == 'integer' && field is num && field % 1 != 0) {
        throw const FormatException('Invalid assistant action field type');
      }
      if (definition.enumValues.isNotEmpty &&
          !definition.enumValues.contains(field)) {
        throw const FormatException('Invalid assistant action field option');
      }
    }
    final missing = value['missing'];
    final question = value['next_question'];
    final replies = value['quick_replies'] ?? const <Object?>[];
    if (missing is! List ||
        missing.any((field) => field is! String || !allowed.contains(field)) ||
        question is! String ||
        question.length > 240 ||
        replies is! List ||
        replies.length > 5 ||
        replies.any((item) => item is! String || item.length > 50)) {
      throw const FormatException('Invalid assistant follow-up');
    }
    final values = Map<String, Object?>.unmodifiable(rawFields);
    final actuallyMissing = AssistantActionRegistry.missing(name, values);
    if (status == AssistantActionStatus.ready && actuallyMissing.isNotEmpty) {
      throw const FormatException(
          'Assistant marked an incomplete action ready');
    }
    if (status == AssistantActionStatus.ready && missing.isNotEmpty) {
      throw const FormatException(
          'Assistant marked fields missing on a ready action');
    }
    if (status == AssistantActionStatus.collecting && question.trim().isEmpty) {
      throw const FormatException('Assistant omitted a follow-up question');
    }
    return AssistantAgentAction(
      name: name,
      status: status,
      fields: values,
      missing: List.unmodifiable(missing.cast<String>()),
      nextQuestion: question.trim(),
      quickReplies: List.unmodifiable(replies.cast<String>()),
    );
  }
}

class AssistantAgentReply {
  const AssistantAgentReply({required this.message, this.action});
  final String message;
  final AssistantAgentAction? action;

  factory AssistantAgentReply.fromJson(Map<String, dynamic> json) {
    if (json.keys.toSet().difference({'message', 'action'}).isNotEmpty ||
        !json.keys.toSet().containsAll({'message', 'action'}) ||
        json['message'] is! String ||
        (json['message'] as String).trim().isEmpty ||
        (json['message'] as String).length > 1000) {
      throw const FormatException('Invalid assistant response');
    }
    final rawAction = json['action'];
    return AssistantAgentReply(
      message: (json['message'] as String).trim(),
      action:
          rawAction == null ? null : AssistantAgentAction.fromJson(rawAction),
    );
  }
}

enum AssistantChatPhase { idle, collecting, confirming, executing }

class AssistantConfirmationGate {
  static bool isYes(String message) => const {
        'y',
        'yes',
        'haan',
        'han',
        'ok',
        'theek hai',
        'save',
        'confirm'
      }.contains(message.trim().toLowerCase());
  static bool isNo(String message) => const {
        'n',
        'no',
        'nahi',
        'nahin',
        'cancel',
        'rehne do'
      }.contains(message.trim().toLowerCase());

  static bool mayExecute(AssistantChatPhase phase, bool confirmed) =>
      phase == AssistantChatPhase.confirming && confirmed;
}
