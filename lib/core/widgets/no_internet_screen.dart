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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'No internet connection',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF18263A),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: isRetrying ? null : onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF183B60),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 48),
                  ),
                  child: Text(isRetrying ? 'Checking…' : 'Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
