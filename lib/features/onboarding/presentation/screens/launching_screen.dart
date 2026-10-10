import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/presentation/providers/profile_providers.dart';

/// Brief, branded gate while the signed-in profile is loaded. This avoids
/// briefly showing Home or replaying onboarding for returning users.
class LaunchingScreen extends ConsumerWidget {
  const LaunchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: profile.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded,
                          size: 38, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 14),
                      Text('Can’t load your workspace yet',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text('Check your internet connection, then try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 18),
                      FilledButton.tonal(
                          onPressed: () => ref.invalidate(profileProvider),
                          child: const Text('Try again')),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 42, color: scheme.primary),
                      const SizedBox(height: 14),
                      Text('Getting your workspace ready',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 18),
                      const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
