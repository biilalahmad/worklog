import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/invoice_url.dart';
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
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => context
                                            .push('/clients/${client.id}'),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  p.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                        maxWidth: 130),
                                                child: MoneyDisplay(
                                                  Money(p.amountRemainingMinor,
                                                      p.currency),
                                                  textAlign: TextAlign.end,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          StatusChip(
                                              label: p.displayStatus.label,
                                              tone: tone),
                                          if (p.dueDate != null)
                                            Text(
                                              'Due ${DateFormat('MMM d, yyyy').format(p.dueDate!)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Wrap(
                                          alignment: WrapAlignment.end,
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            if (p.shareToken != null)
                                              OutlinedButton.icon(
                                                onPressed: () async {
                                                  final invoiceUrl =
                                                      buildInvoiceUrl(
                                                          p.shareToken!);
                                                  try {
                                                    await Clipboard.setData(
                                                        ClipboardData(
                                                            text: invoiceUrl));
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    await Share.share(
                                                      invoiceUrl,
                                                      subject:
                                                          'Invoice: ${p.title}',
                                                    );
                                                  } catch (_) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                              'Could not share the invoice link.'),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                                icon: const Icon(
                                                    Icons.link_rounded),
                                                label:
                                                    const Text('Share invoice'),
                                              ),
                                            InvoiceDownloadButton(
                                              project: p,
                                              client: client,
                                              iconSize: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
