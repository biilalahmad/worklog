import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/search_match.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/app_fab.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../../core/widgets/money_display.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../domain/client.dart';
import '../providers/client_providers.dart';

enum _ClientSort { name, totalEarned, pending }

final _clientSortProvider =
    StateProvider.autoDispose<_ClientSort>((ref) => _ClientSort.name);

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _magnitude(MoneyByCurrency moneyByCurrency) =>
      moneyByCurrency.toMap().values.fold<int>(0, (s, v) => s + v);

  List<Client> _sorted(List<Client> clients, _ClientSort sort) {
    final list = [...clients];
    switch (sort) {
      case _ClientSort.name:
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _ClientSort.totalEarned:
        list.sort((a, b) =>
            _magnitude(b.totalEarned).compareTo(_magnitude(a.totalEarned)));
      case _ClientSort.pending:
        list.sort((a, b) =>
            _magnitude(b.totalPending).compareTo(_magnitude(a.totalPending)));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final clientsAsync = ref.watch(clientsListProvider);
    final sort = ref.watch(_clientSortProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            tooltip: 'Sort clients',
            icon: const Icon(Icons.sort_rounded),
            onPressed: () async {
              final selected = await AppSelectSheet.show<_ClientSort>(
                context: context,
                title: 'Sort clients',
                value: sort,
                options: const [
                  AppSelectOption(value: _ClientSort.name, label: 'By name'),
                  AppSelectOption(
                      value: _ClientSort.totalEarned, label: 'By total earned'),
                  AppSelectOption(
                      value: _ClientSort.pending, label: 'By pending amount'),
                ],
              );
              if (selected != null) {
                ref.read(_clientSortProvider.notifier).state = selected;
              }
            },
          ),
        ],
      ),
      floatingActionButton: AppFab(
        tooltip: 'Add client',
        onPressed: () => context.push('/clients/new'),
      ),
      body: clientsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => ErrorView(message: Failure.from(e).message),
        data: (clients) {
          if (clients.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No clients yet',
              subtitle: 'Tap + to add your first client',
            );
          }
          final filtered = clients
              .where((client) => matchesSearch(client.name, _query))
              .toList();
          final sorted = _sorted(filtered, sort);
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              AppInsets.belowNavigation(context),
            ),
            itemCount: sorted.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search among ${clients.length} clients',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search among ${clients.length} clients',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (sorted.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text('Client not found')),
                      ),
                  ],
                );
              }
              final client = sorted[index - 1];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push('/clients/${client.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              width: 2,
                            ),
                          ),
                          child: AvatarCircle(
                            imageUrl: client.avatarUrl,
                            initials: client.name.isNotEmpty
                                ? client.name[0].toUpperCase()
                                : '?',
                            size: 42,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(client.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 5),
                              if (client.totalPending.isEmpty)
                                Text('All payments settled',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant))
                              else
                                Wrap(
                                  spacing: 5,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('Due:',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    MoneyTotalsDisplay(
                                      client.totalPending,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 130),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Earned',
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                              const SizedBox(height: 4),
                              MoneyTotalsDisplay(
                                client.totalEarned,
                                textAlign: TextAlign.end,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
