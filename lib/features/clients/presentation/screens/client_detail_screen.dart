import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/invoice_url.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/invoice_download_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/money_display.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../../work/domain/work_entry.dart';
import '../../../work/presentation/providers/work_providers.dart';
import '../../domain/client.dart';
import '../../domain/project.dart';
import '../providers/client_providers.dart';

class ClientDetailScreen extends ConsumerWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientProvider(clientId));
    final projectsAsync = ref.watch(projectsForClientProvider(clientId));
    final workAsync = ref.watch(workEntriesForClientProvider(clientId));
    final incomeAsync = ref.watch(incomeForClientProvider(clientId));

    return Scaffold(
      appBar: AppBar(
        title: clientAsync.when(
          data: (c) => Text(c?.name ?? 'Client'),
          loading: () => const Text('Client'),
          error: (_, __) => const Text('Client'),
        ),
        actions: [
          clientAsync.maybeWhen(
            data: (client) => client == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        context.push('/clients/$clientId/edit', extra: client),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clients/$clientId/projects/new'),
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add),
        label: const Text('Add project'),
      ),
      body: clientAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(message: Failure.from(e).message),
        data: (client) {
          if (client == null) {
            return const Center(child: Text('Client not found'));
          }
          final historyHeadingStyle = Theme.of(context).textTheme.titleMedium;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AvatarCircle(
                          imageUrl: client.avatarUrl,
                          initials: client.name.isNotEmpty
                              ? client.name[0].toUpperCase()
                              : '?',
                          size: 56,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(client.name,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              if (client.email != null) Text(client.email!),
                              if (client.phone != null) Text(client.phone!),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (client.phone != null || client.email != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (client.phone != null)
                            _QuickActionChip(
                              icon: Icons.call_outlined,
                              label: 'Call',
                              onTap: () => launchUrl(
                                  Uri(scheme: 'tel', path: client.phone)),
                            ),
                          if (client.phone != null) const SizedBox(width: 10),
                          if (client.email != null)
                            _QuickActionChip(
                              icon: Icons.mail_outline_rounded,
                              label: 'Email',
                              onTap: () => launchUrl(Uri(
                                scheme: 'mailto',
                                path: client.email,
                                query:
                                    'subject=${Uri.encodeComponent('Hi ${client.name}')}',
                              )),
                            ),
                          if (client.phone != null) ...[
                            const SizedBox(width: 10),
                            _QuickActionChip(
                              icon: Icons.chat_outlined,
                              label: 'WhatsApp',
                              onTap: () => launchUrl(
                                Uri.parse(
                                    'https://wa.me/${_digitsOnly(client.phone!)}'),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (client.notes != null && client.notes!.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(client.notes!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (client.isRetainer) ...[
                SectionCard(
                  child: Row(
                    children: [
                      Icon(Icons.autorenew_rounded,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Retainer client',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            if (client.retainerAmountMinor != null)
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  MoneyDisplay(Money(
                                      client.retainerAmountMinor!,
                                      client.retainerCurrency ?? 'PKR')),
                                  Text(
                                      'on day ${client.retainerDayOfMonth ?? 1} of each month'),
                                ],
                              )
                            else
                              Text('Billing details not set',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      )),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final count = await ref
                              .read(clientRepositoryProvider)
                              .generateDueRetainerInvoices();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(count > 0
                                      ? 'Generated $count invoice(s)'
                                      : 'Nothing due yet')),
                            );
                          }
                        },
                        child: const Text('Generate Now'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (client.totalPending.isEmpty)
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Earned',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      MoneyTotalsDisplay(client.totalEarned,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Earned',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            MoneyTotalsDisplay(client.totalEarned,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pending',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            MoneyTotalsDisplay(client.totalPending,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              workAsync.when(
                loading: () =>
                    const SectionCard(child: LinearProgressIndicator()),
                error: (e, _) => ErrorView(message: Failure.from(e).message),
                data: (entries) {
                  final completed = entries
                      .where((w) =>
                          w.status == WorkStatus.completed ||
                          w.status == WorkStatus.delivered)
                      .length;
                  return SectionCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Completed work'),
                        Text('$completed',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('Projects / Invoices',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              projectsAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => ErrorView(message: Failure.from(e).message),
                data: (projects) {
                  if (projects.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No invoice available to display',
                      subtitle: 'Please add a project first.',
                    );
                  }
                  return Column(
                    children: [
                      for (final p in projects) ...[
                        _ProjectTile(project: p, client: client),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('Work History', style: historyHeadingStyle),
              const SizedBox(height: 8),
              workAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => ErrorView(message: Failure.from(e).message),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const SizedBox(
                      height: 210,
                      child: EmptyState(
                        icon: Icons.work_history_outlined,
                        title: 'No work history yet',
                        subtitle:
                            'Work you complete for this client will appear here.',
                      ),
                    );
                  }
                  return Column(
                    children: entries.take(10).map((w) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SectionCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text(
                                        w.workType.trim().isEmpty
                                            ? 'General Work'
                                            : w.workType,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall)),
                                StatusChip(
                                    label: w.status.label,
                                    tone: switch (w.status) {
                                      WorkStatus.completed ||
                                      WorkStatus.delivered =>
                                        StatusTone.good,
                                      WorkStatus.inProgress =>
                                        StatusTone.warning,
                                      WorkStatus.revisionRequired =>
                                        StatusTone.bad,
                                      WorkStatus.pending => StatusTone.neutral,
                                    }),
                              ]),
                              const SizedBox(height: 6),
                              Wrap(spacing: 8, runSpacing: 4, children: [
                                Text(DateFormat('MMM d, yyyy')
                                    .format(w.date.toLocal())),
                                if (w.hoursWorked > 0)
                                  Text(
                                      '${w.hoursWorked.toStringAsFixed(1)} hr'),
                              ]),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('Payment History', style: historyHeadingStyle),
              const SizedBox(height: 8),
              incomeAsync.when(
                loading: () => const LoadingIndicator(),
                error: (e, _) => ErrorView(message: Failure.from(e).message),
                data: (payments) {
                  if (payments.isEmpty) {
                    return const SizedBox(
                      height: 210,
                      child: EmptyState(
                        icon: Icons.payments_outlined,
                        title: 'No payment history yet',
                        subtitle: 'Payments from this client will appear here.',
                      ),
                    );
                  }
                  return Column(
                    children: payments.take(10).map((income) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(income.method,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall),
                                  const SizedBox(height: 3),
                                  Text(
                                    DateFormat('MMM d, yyyy')
                                        .format(income.date),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 145),
                              child: MoneyDisplay(
                                Money(
                                    income.amountMinor.abs(), income.currency),
                                textAlign: TextAlign.end,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final Project project;
  final Client client;
  const _ProjectTile({required this.project, required this.client});

  @override
  Widget build(BuildContext context) {
    final tone = switch (project.displayStatus) {
      ProjectStatus.paid => StatusTone.good,
      ProjectStatus.partiallyPaid => StatusTone.warning,
      ProjectStatus.overdue => StatusTone.bad,
      ProjectStatus.unpaid => StatusTone.neutral,
    };
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(project.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    MoneyDisplay(
                      Money(project.totalAmountMinor, project.currency),
                      textAlign: TextAlign.start,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: project.displayStatus.label, tone: tone),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            children: [
              if (project.shareToken case final token?)
                IconButton(
                  tooltip: 'Share online invoice',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.link_rounded),
                  onPressed: () async {
                    final invoiceUrl = buildInvoiceUrl(token);
                    await Clipboard.setData(ClipboardData(text: invoiceUrl));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invoice link copied')),
                    );
                    await Share.share(
                      invoiceUrl,
                      subject: 'Invoice: ${project.title}',
                    );
                  },
                ),
              InvoiceDownloadButton(
                project: project,
                client: client,
                iconSize: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small pill button used for the Call / Email / WhatsApp row on
/// Client Detail — each opens the respective native app directly with
/// that client's contact info via the standard OS intent/URL scheme.
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label, style: const TextStyle(fontSize: 12.5)),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10)),
      ),
    );
  }
}

String _digitsOnly(String input) => input.replaceAll(RegExp(r'[^0-9+]'), '');
