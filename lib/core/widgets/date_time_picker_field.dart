import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A clearly-tappable date (and optionally time) picker, styled as
/// real labeled buttons instead of a plain text-and-icon row — so
/// it's obvious at a glance that the date (and time) can be tapped
/// and changed, not just a static display.
class DateTimePickerField extends StatelessWidget {
  final DateTime? date; // null when not yet set (e.g. an optional due date)
  final TimeOfDay? time; // omit to show a date-only field
  final VoidCallback onTapDate;
  final VoidCallback? onTapTime;
  final VoidCallback? onClearDate;
  final String label;
  final String placeholder;

  const DateTimePickerField({
    super.key,
    required this.date,
    this.time,
    required this.onTapDate,
    this.onTapTime,
    this.onClearDate,
    this.label = 'Date',
    this.placeholder = 'Select date',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _PickerButton(
                icon: Icons.calendar_today_rounded,
                label: date == null ? placeholder : DateFormat('EEE, MMM d, yyyy').format(date!),
                onTap: onTapDate,
              ),
            ),
            if (date != null && onClearDate != null) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                tooltip: 'Clear date',
                onPressed: onClearDate,
              ),
            ],
            if (time != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _PickerButton(
                  icon: Icons.access_time_rounded,
                  label: time!.format(context),
                  onTap: onTapTime!,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // A clear "this can be changed" affordance — the same
              // chevron shape people already recognize from dropdowns.
              Icon(Icons.unfold_more_rounded, size: 16, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
