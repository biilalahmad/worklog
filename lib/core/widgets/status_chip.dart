import 'package:flutter/material.dart';

/// Small colored chip for statuses (work status, payment status). Colors
/// are semantic, not decorative — green means good/complete/paid, amber
/// means pending/in-progress, red means overdue/revision-required.
class StatusChip extends StatelessWidget {
  final String label;
  final StatusTone tone;

  const StatusChip({super.key, required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (tone) {
      case StatusTone.good:
        bg = isDark
            ? Colors.green.shade900.withValues(alpha: .48)
            : Colors.green.withValues(alpha: .15);
        fg = isDark ? Colors.green.shade200 : Colors.green.shade800;
        break;
      case StatusTone.warning:
        bg = isDark
            ? Colors.amber.shade900.withValues(alpha: .48)
            : Colors.amber.withValues(alpha: .2);
        fg = isDark ? Colors.amber.shade200 : Colors.amber.shade900;
        break;
      case StatusTone.bad:
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        break;
      case StatusTone.neutral:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurfaceVariant;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style:
              TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

enum StatusTone { good, warning, bad, neutral }
