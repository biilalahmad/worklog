import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/utils/search_match.dart';
import '../../../clients/domain/client.dart';
import '../../../clients/domain/project.dart';
import '../../../clients/presentation/providers/client_providers.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
import '../../../work/domain/work_entry.dart';
import '../../../work/presentation/providers/work_providers.dart';

/// Global search across clients, work entries and reminders — filtered
/// client-side over the already-loaded lists. This keeps the first cut
/// simple and fast for a single-user dataset; if the data volume grows
/// enough to matter, swap in a dedicated search index (e.g. Algolia)
/// behind the same ClientRepository/WorkRepository interfaces without
/// touching this screen.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsListProvider);
    final workAsync = ref.watch(recentWorkEntriesProvider);
    final remindersAsync = ref.watch(upcomingRemindersProvider);

    final q = _query.trim();
    final clients = clientsAsync.valueOrNull ?? const [];
    final clientsById = {for (final client in clients) client.id: client};
    final matchedClients = q.isEmpty
        ? const []
        : clients
            .where((client) => matchesSearch(
                  '${client.name} ${client.email ?? ''} ${client.phone ?? ''} ${client.notes ?? ''}',
                  q,
                ))
            .toList();
    final matchedProjects = <({Client client, Project project})>[];
    if (q.isNotEmpty) {
      for (final client in clients) {
        final projects = ref.watch(projectsForClientProvider(client.id));
        for (final project in projects.valueOrNull ?? const <Project>[]) {
          if (matchesSearch(
              '${project.title} ${project.displayStatus.label}', q)) {
            matchedProjects.add((client: client, project: project));
          }
        }
      }
    }
    final matchedWork = q.isEmpty
        ? const []
        : (workAsync.valueOrNull ?? []).where((entry) {
            final clientName = clientsById[entry.clientId]?.name ?? '';
            return matchesSearch(
              '${entry.taskName} ${entry.workType} ${entry.status.label} ${entry.notes ?? ''} $clientName',
              q,
            );
          }).toList();
    final matchedReminders = q.isEmpty
        ? const []
        : (remindersAsync.valueOrNull ?? []).where((reminder) {
            final clientName = clientsById[reminder.clientId]?.name ?? '';
            return matchesSearch(
              '${reminder.title} ${reminder.description ?? ''} $clientName',
              q,
            );
          }).toList();

    final hasResults = matchedClients.isNotEmpty ||
        matchedProjects.isNotEmpty ||
        matchedWork.isNotEmpty ||
        matchedReminders.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search clients, work, reminders...',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: q.isEmpty
          ? const EmptyState(
              icon: Icons.search, title: 'Start typing to search')
          : !hasResults
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'No search results found',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (matchedClients.isNotEmpty) ...[
                      Text('Clients',
                          style: Theme.of(context).textTheme.titleSmall),
                      ...matchedClients.map((c) => ListTile(
                            title: Text(c.name),
                            onTap: () => context.push('/clients/${c.id}'),
                          )),
                    ],
                    if (matchedProjects.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Projects / invoices',
                          style: Theme.of(context).textTheme.titleSmall),
                      ...matchedProjects.map((match) => ListTile(
                            title: Text(match.project.title),
                            subtitle: Text(match.client.name),
                            onTap: () =>
                                context.push('/clients/${match.client.id}'),
                          )),
                    ],
                    if (matchedWork.isNotEmpty) ...[
                      Text('Work',
                          style: Theme.of(context).textTheme.titleSmall),
                      ...matchedWork.map((w) => ListTile(
                            title: Text(w.workType.trim().isEmpty
                                ? 'General Work'
                                : w.workType),
                            onTap: () =>
                                context.push('/work/${w.id}/edit', extra: w),
                          )),
                    ],
                    if (matchedReminders.isNotEmpty) ...[
                      Text('Reminders',
                          style: Theme.of(context).textTheme.titleSmall),
                      ...matchedReminders.map((r) => ListTile(
                            title: Text(r.title),
                            onTap: () => context.push('/reminders/${r.id}/edit',
                                extra: r),
                          )),
                    ],
                  ],
                ),
    );
  }
}
