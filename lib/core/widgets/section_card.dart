import 'package:flutter/material.dart';

/// Standard padded card used across dashboard/detail screens so spacing
/// stays consistent instead of every screen inventing its own padding.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: padding, child: child));
  }
}
