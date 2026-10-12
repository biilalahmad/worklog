import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/work_repository_impl.dart';
import '../../domain/work_entry.dart';
import '../../domain/work_repository.dart';

final workRepositoryProvider =
    Provider<WorkRepository>((ref) => WorkRepositoryImpl());

class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
}

final workEntriesForRangeProvider =
    StreamProvider.autoDispose.family<List<WorkEntry>, DateRange>((ref, range) {
  return ref
      .watch(workRepositoryProvider)
      .watchEntriesForRange(range.start, range.end);
});

final workEntriesForClientProvider =
    StreamProvider.autoDispose.family<List<WorkEntry>, String>((ref, clientId) {
  return ref.watch(workRepositoryProvider).watchEntriesForClient(clientId);
});

final recentWorkEntriesProvider =
    StreamProvider.autoDispose<List<WorkEntry>>((ref) {
  return ref.watch(workRepositoryProvider).watchAllEntries();
});
