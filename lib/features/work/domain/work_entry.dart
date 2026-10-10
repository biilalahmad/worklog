enum WorkStatus { pending, inProgress, completed, delivered, revisionRequired }

extension WorkStatusX on WorkStatus {
  String get label {
    switch (this) {
      case WorkStatus.pending:
        return 'Pending';
      case WorkStatus.inProgress:
        return 'In Progress';
      case WorkStatus.completed:
        return 'Completed';
      case WorkStatus.delivered:
        return 'Delivered';
      case WorkStatus.revisionRequired:
        return 'Revision Required';
    }
  }

  String get asString => toString().split('.').last;

  static WorkStatus fromString(String? value) {
    return WorkStatus.values.firstWhere(
      (s) => s.asString == value,
      orElse: () => WorkStatus.pending,
    );
  }
}

/// A single day's unit of work for a client/project. `videoCount` is
/// tracked separately from `otherTaskCount` because video-editing
/// metrics get dedicated statistics per the spec (Videos Tracking).
class WorkEntry {
  final String id;
  final String clientId;
  final String? projectId;
  final String taskName;
  final String workType;
  final int videoCount;
  final int otherTaskCount;
  final double hoursWorked;
  final WorkStatus status;
  final DateTime date;
  final DateTime? dueDate;
  final DateTime? completionDate;
  final String? notes;
  final DateTime? createdAt;
  /// Set while a Start/Stop timer is running on this entry; null
  /// otherwise. Managed by WorkRepository.startTimer/stopTimer, not by
  /// normal form saves.
  final DateTime? timerStartedAt;

  const WorkEntry({
    required this.id,
    required this.clientId,
    this.projectId,
    required this.taskName,
    required this.workType,
    this.videoCount = 0,
    this.otherTaskCount = 0,
    this.hoursWorked = 0,
    this.status = WorkStatus.pending,
    required this.date,
    this.dueDate,
    this.completionDate,
    this.notes,
    this.createdAt,
    this.timerStartedAt,
  });

  factory WorkEntry.fromMap(Map<String, dynamic> data) {
    return WorkEntry(
      id: data['id'] as String,
      clientId: data['client_id'] as String? ?? '',
      projectId: data['project_id'] as String?,
      taskName: data['task_name'] as String? ?? '',
      workType: data['work_type'] as String? ?? '',
      videoCount: (data['video_count'] as num?)?.toInt() ?? 0,
      otherTaskCount: (data['other_task_count'] as num?)?.toInt() ?? 0,
      hoursWorked: (data['hours_worked'] as num?)?.toDouble() ?? 0,
      status: WorkStatusX.fromString(data['status'] as String?),
      date: DateTime.tryParse(data['date'] as String? ?? '') ?? DateTime.now(),
      dueDate: data['due_date'] != null ? DateTime.tryParse(data['due_date'] as String) : null,
      completionDate: data['completion_date'] != null
          ? DateTime.tryParse(data['completion_date'] as String)
          : null,
      notes: data['notes'] as String?,
      createdAt: data['created_at'] != null ? DateTime.tryParse(data['created_at'] as String) : null,
      timerStartedAt:
          data['timer_started_at'] != null ? DateTime.tryParse(data['timer_started_at'] as String) : null,
    );
  }

  Map<String, dynamic> toWritableMap() {
    return {
      'client_id': clientId,
      'project_id': projectId,
      'task_name': taskName,
      'work_type': workType,
      'video_count': videoCount,
      'other_task_count': otherTaskCount,
      'hours_worked': hoursWorked,
      'status': status.asString,
      'date': date.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'completion_date': completionDate?.toIso8601String(),
      'notes': notes,
    };
  }
}
