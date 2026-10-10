import 'package:flutter/material.dart';

/// Shown instead of crashing when lib/core/config/supabase_config.dart
/// still has placeholder credentials. Points to exactly what to do —
/// friendly, not a stack trace.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cloud_off_rounded, size: 40, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text('Connect WorkLog to Supabase',
                      style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'WorkLog needs your Supabase project URL and anon key before it can '
                    'save anything. Add them in lib/core/config/supabase_config.dart, or '
                    'run with --dart-define, then restart the app.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      'flutter run \\\n'
                      '  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n'
                      '  --dart-define=SUPABASE_ANON_KEY=xxxxx',
                      style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
