import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Keeps framework and asynchronous failures out of the release UI while
/// preserving useful diagnostics during local development.
void installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.presentError(details);
  };

  ui.PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Uncaught asynchronous error: $error');
      debugPrintStack(stackTrace: stack);
    }
    return true;
  };

  if (!kDebugMode) {
    ErrorWidget.builder = (_) => const _FriendlyErrorFallback();
  }
}

class _FriendlyErrorFallback extends StatelessWidget {
  const _FriendlyErrorFallback();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 36, color: scheme.error),
              const SizedBox(height: 12),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Close and reopen WorkLog to try again.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
