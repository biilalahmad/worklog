import 'work_entry.dart';

abstract class WorkRepository {
  Stream<List<WorkEntry>> watchEntriesForRange(DateTime start, DateTime end);
  Stream<List<WorkEntry>> watchEntriesForClient(String clientId);
  Stream<List<WorkEntry>> watchAllEntries({int limit = 100});
  Future<String> addEntry(WorkEntry entry);
  Future<void> updateEntry(WorkEntry entry);
  Future<void> deleteEntry(String entryId);

  /// Starts the Start/Stop timer on [entryId] (sets timer_started_at
  /// to now — a currently-running timer is left as-is, not restarted).
  Future<void> startTimer(String entryId);

  /// Stops the timer and adds the elapsed time to hoursWorked. A
  /// no-op if the timer isn't currently running.
  Future<void> stopTimer(String entryId);

  /// Full list (no stream, no limit) — used for CSV export/backup.
  Future<List<WorkEntry>> getAllEntries();
}
