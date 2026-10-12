import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// WorkLog's shared floating action button sizing and safe-area offset.
class AppFab extends StatelessWidget {
  const AppFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.icon = Icons.add_rounded,
    this.aboveNavigation = true,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;

  /// True for screens inside the floating bottom-navigation shell.
  final bool aboveNavigation;

  @override
  Widget build(BuildContext context) {
    final bottom = AppInsets.floatingActionBottom(
      context,
      aboveNavigation: aboveNavigation,
    );
    return Padding(
      padding: EdgeInsets.only(right: 4, bottom: bottom),
      child: SizedBox.square(
        dimension: AppSpacing.fabSize,
        child: FloatingActionButton(
          onPressed: onPressed,
          tooltip: tooltip,
          child: Icon(icon, size: 30),
        ),
      ),
    );
  }
}
