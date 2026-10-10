import 'package:flutter/material.dart';

/// Quiet skeleton for gym data fetches; avoids a large spinner on every tab.
class GymLoadingPlaceholder extends StatelessWidget {
  final int rows;

  const GymLoadingPlaceholder({super.key, this.rows = 2});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bar = scheme.onSurface.withValues(alpha: .09);
    return Column(
      children: List.generate(
        rows,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: index == 0 ? 82 : 68,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: .54),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .5)),
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: bar),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FractionallySizedBox(
                        widthFactor: index.isEven ? .56 : .42,
                        alignment: Alignment.centerLeft,
                        child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                                color: bar,
                                borderRadius: BorderRadius.circular(8))),
                      ),
                      const SizedBox(height: 8),
                      FractionallySizedBox(
                        widthFactor: .78,
                        alignment: Alignment.centerLeft,
                        child: Container(
                            height: 9,
                            decoration: BoxDecoration(
                                color: bar,
                                borderRadius: BorderRadius.circular(8))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
