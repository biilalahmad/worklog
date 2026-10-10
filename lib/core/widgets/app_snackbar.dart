import 'package:flutter/material.dart';

/// Shared floating feedback style used throughout the app.
class AppSnackBar {
  AppSnackBar._();

  static const duration = Duration(seconds: 3);
  static const _margin = EdgeInsets.fromLTRB(16, 0, 16, 20);

  static SnackBar build(
    BuildContext context, {
    required String message,
    SnackBarAction? action,
    bool isError = false,
    Duration duration = duration,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: isError ? scheme.onErrorContainer : scheme.onInverseSurface,
        ),
      ),
      action: action,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: _margin,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isError ? scheme.errorContainer : scheme.inverseSurface,
    );
  }

  /// Replace an existing message instead of queueing stale feedback.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    SnackBarAction? action,
    bool isError = false,
    Duration duration = duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      build(
        context,
        message: message,
        action: action,
        isError: isError,
        duration: duration,
      ),
    );
  }
}
