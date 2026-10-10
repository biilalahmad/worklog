import 'project.dart';

/// Result row from `get_newly_overdue_projects()` — a lighter shape
/// than the full Project, since it already joins in the client name
/// (so the app doesn't need a second lookup to build the alert text).
class OverdueProject {
  final String id;
  final String clientId;
  final String clientName;
  final String title;
  final int totalAmountMinor;
  final int amountRemainingMinor;
  final String currency;
  final DateTime dueDate;

  const OverdueProject({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.title,
    required this.totalAmountMinor,
    required this.amountRemainingMinor,
    required this.currency,
    required this.dueDate,
  });

  factory OverdueProject.fromMap(Map<String, dynamic> data) {
    return OverdueProject(
      id: data['id'] as String,
      clientId: data['client_id'] as String,
      clientName: data['client_name'] as String? ?? '',
      title: data['title'] as String? ?? '',
      totalAmountMinor: (data['total_amount'] as num?)?.toInt() ?? 0,
      amountRemainingMinor: (data['amount_remaining'] as num?)?.toInt() ?? 0,
      currency: data['currency'] as String? ?? 'PKR',
      dueDate: DateTime.parse(data['due_date'] as String),
    );
  }
}

abstract class ProjectRepository {
  Stream<List<Project>> watchProjectsForClient(String clientId);
  Stream<Project?> watchProject(String projectId);
  Future<String> addProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String projectId);

  /// Projects that have crossed their due date, aren't fully paid, and
  /// haven't been alerted about yet (see schema.sql's
  /// `overdue_notified_at`) — checked once on Home launch to drive the
  /// in-app late-payment notification.
  Future<List<OverdueProject>> getNewlyOverdueProjects();

  /// Marks a project as already alerted, so it isn't re-notified on
  /// every app open.
  Future<void> markOverdueNotified(String projectId);
}
