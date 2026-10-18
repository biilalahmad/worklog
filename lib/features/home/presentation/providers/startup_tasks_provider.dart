import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clients/presentation/providers/client_providers.dart';
import '../../../gym/presentation/providers/gym_providers.dart';
import '../../../reminders/presentation/providers/notification_provider.dart';
import '../../../../core/utils/money.dart';

/// One-shot work that should happen when the app opens, not on every
/// rebuild: generate any due retainer invoices (Section 5 roadmap #6),
/// and alert about newly-overdue invoices (roadmap #7). Kept as a
/// plain `Provider` (not autoDispose) read once from HomeScreen's
/// build, so it fires once per app session.
final startupTasksProvider = FutureProvider<void>((ref) async {
  final clientRepo = ref.read(clientRepositoryProvider);
  final projectRepo = ref.read(projectRepositoryProvider);
  final notifications = ref.read(notificationServiceProvider);

  // Sweep abandoned empty sessions once per app session, instead of
  // issuing the same cleanup query every time the Gym tab is opened.
  unawaited(ref
      .read(workoutRepositoryProvider)
      .discardExpiredEmptyWorkouts()
      .catchError((_) {}));

  try {
    await clientRepo.generateDueRetainerInvoices();
  } catch (_) {
    // Best-effort — a failed retainer-generation check shouldn't block
    // the rest of the app from loading.
  }

  try {
    final overdue = await projectRepo.getNewlyOverdueProjects();
    for (final p in overdue) {
      final amount = Money(p.amountRemainingMinor, p.currency).format();
      await notifications.showNow(
        // Stable per-project id so a second check before the first
        // notification is dismissed just replaces it, never stacks.
        id: p.id.hashCode & 0x7fffffff,
        title: 'Invoice overdue — ${p.clientName}',
        body: '${p.title} is overdue. $amount still remaining.',
        payload: 'project:${p.id}',
      );
      await projectRepo.markOverdueNotified(p.id);
    }
  } catch (_) {
    // Same — notification scheduling failing shouldn't break Home.
  }
});
