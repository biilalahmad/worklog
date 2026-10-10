import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/assistant_contract.dart';

class AssistantEntryCard extends StatelessWidget {
  const AssistantEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/assistant'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: const Icon(Icons.auto_awesome_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ask WorkLog',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text('Get helpful ideas from your work and fitness trends.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

class AssistantShortcutButton extends StatelessWidget {
  const AssistantShortcutButton({super.key, required this.agent});
  final AssistantAgent agent;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Ask ${agent.label}',
        onPressed: () => context.push('/assistant?agent=${agent.wireValue}'),
        icon: const Icon(Icons.auto_awesome_outlined),
      );
}
