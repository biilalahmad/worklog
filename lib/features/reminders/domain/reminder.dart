enum RepeatOption { none, daily, weekly, monthly }

extension RepeatOptionX on RepeatOption {
  String get asString => toString().split('.').last;
  String get label {
    switch (this) {
      case RepeatOption.none:
        return 'One time';
      case RepeatOption.daily:
        return 'Daily';
      case RepeatOption.weekly:
        return 'Weekly';
      case RepeatOption.monthly:
        return 'Monthly';
    }
  }

  static RepeatOption fromString(String? value) {
    return RepeatOption.values.firstWhere(
      (r) => r.asString == value,
      orElse: () => RepeatOption.none,
    );
  }
}

enum ReminderPriority { low, medium, high }

extension ReminderPriorityX on ReminderPriority {
  String get asString => toString().split('.').last;
  String get label {
    switch (this) {
      case ReminderPriority.low:
        return 'Low';
      case ReminderPriority.medium:
        return 'Medium';
      case ReminderPriority.high:
        return 'High';
    }
  }

  static ReminderPriority fromString(String? value) {
    return ReminderPriority.values.firstWhere(
      (p) => p.asString == value,
      orElse: () => ReminderPriority.medium,
    );
  }
}

class Reminder {
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final String? clientId;
  final String? projectId;
  final ReminderPriority priority;
  final RepeatOption repeat;
  final bool completed;
  final DateTime? createdAt;

  const Reminder({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    this.clientId,
    this.projectId,
    this.priority = ReminderPriority.medium,
    this.repeat = RepeatOption.none,
    this.completed = false,
    this.createdAt,
  });

  /// Stable positive int for scheduling with flutter_local_notifications
  /// (which needs a platform notification id), derived from the
  /// record's id so re-scheduling the same reminder overwrites rather
  /// than duplicates its notification.
  int get notificationId => id.hashCode & 0x7fffffff;

  /// The next firing for a repeating reminder, keeping its original local
  /// time and calendar day where possible (month-end dates are clamped).
  DateTime nextOccurrence(DateTime now) {
    if (repeat == RepeatOption.none || dateTime.isAfter(now)) return dateTime;
    switch (repeat) {
      case RepeatOption.none:
        return dateTime;
      case RepeatOption.daily:
        var next = dateTime;
        while (!next.isAfter(now)) {
          next = DateTime(next.year, next.month, next.day + 1, next.hour,
              next.minute, next.second);
        }
        return next;
      case RepeatOption.weekly:
        var next = dateTime;
        while (!next.isAfter(now)) {
          next = DateTime(next.year, next.month, next.day + 7, next.hour,
              next.minute, next.second);
        }
        return next;
      case RepeatOption.monthly:
        var year = dateTime.year;
        var month = dateTime.month;
        final day = dateTime.day;
        var next = dateTime;
        while (!next.isAfter(now)) {
          month++;
          if (month > 12) {
            year++;
            month = 1;
          }
          final lastDay = DateTime(year, month + 1, 0).day;
          next = DateTime(year, month, day.clamp(1, lastDay), dateTime.hour,
              dateTime.minute, dateTime.second);
        }
        return next;
    }
  }

  factory Reminder.fromMap(Map<String, dynamic> data) {
    return Reminder(
      id: data['id'] as String,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      dateTime: DateTime.tryParse(data['date_time'] as String? ?? '') ??
          DateTime.now(),
      clientId: data['client_id'] as String?,
      projectId: data['project_id'] as String?,
      priority: ReminderPriorityX.fromString(data['priority'] as String?),
      repeat: RepeatOptionX.fromString(data['repeat'] as String?),
      completed: data['completed'] as bool? ?? false,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toWritableMap() {
    return {
      'title': title,
      'description': description,
      'date_time': dateTime.toIso8601String(),
      'client_id': clientId,
      'project_id': projectId,
      'priority': priority.asString,
      'repeat': repeat.asString,
      'completed': completed,
    };
  }
}
