import 'package:flutter/material.dart';

/// Branded recovery state used when a signed-in workspace cannot reach the
/// WorkLog backend. The page is intentionally usable with large text and in
/// both app themes.
class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen(
      {super.key, required this.onRetry, this.isRetrying = false});

  final VoidCallback? onRetry;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    color: colors.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Image.asset(
                              'assets/images/worklog_icon.png',
                              fit: BoxFit.contain,
                              semanticLabel: 'WorkLog',
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primaryContainer,
                            ),
                            child: Icon(
                              Icons.wifi_off_rounded,
                              size: 48,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'No internet connection',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Check your connection. WorkLog will open your saved workspace when it can connect.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: isRetrying ? null : onRetry,
                              icon: isRetrying
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                              label: Text(isRetrying
                                  ? 'Checking connection…'
                                  : 'Retry'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
