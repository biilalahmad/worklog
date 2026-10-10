import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/invoice_download_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/money_display.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../clients/domain/project.dart';
import '../../../clients/presentation/providers/client_providers.dart';
import '../../../../core/errors/failure.dart';

/// "Money I Need to Receive" — every project across every client that
/// isn't fully paid yet. Reads client rollups (fast) then drills into
/// each client's projects only when there's pending money, so this
/// doesn't need a cross-collection query.
class PendingPaymentsScreen extends ConsumerWidget {
  const PendingPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Money I Need to Receive')),
      body: clientsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(message: Failure.from(e).message),
        data: (clients) {
          final owingClients =
              clients.where((c) => !c.totalPending.isEmpty).toList();
          if (owingClients.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All clear!',
              subtitle: 'No pending payments right now.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: owingClients.length,
            itemBuilder: (context, index) {
              final client = owingClients[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              client.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Consumer(builder: (context, ref, _) {
                        final projectsAsync =
                            ref.watch(projectsForClientProvider(client.id));
                        return projectsAsync.when(
                          loading: () => const LoadingIndicator(),
                          error: (e, _) => Text(Failure.from(e).message),
                          data: (projects) {
                            final unpaid = projects
                                .where((p) =>
                                    p.displayStatus != ProjectStatus.paid)
                                .toList();
                            if (unpaid.isEmpty) return const SizedBox.shrink();
                            return Column(
                              children: unpaid.map((p) {
                                final tone =
                                    p.displayStatus == ProjectStatus.overdue
                                        ? StatusTone.bad
                                        : StatusTone.warning;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () =>
                                      context.push('/clients/${client.id}'),
                                  title: Text(
                                    p.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (p.dueDate != null)
                                        Text(
                                          'Due: ${DateFormat('MMM d, yyyy').format(p.dueDate!)}',
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          StatusChip(
                                            label: p.displayStatus.label,
                                            tone: tone,
                                          ),
                                          InvoiceDownloadButton(
                                            project: p,
                                            client: client,
                                            iconSize: 18,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 130),
                                    child: MoneyDisplay(
                                      Money(p.amountRemainingMinor, p.currency),
                                      textAlign: TextAlign.end,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
