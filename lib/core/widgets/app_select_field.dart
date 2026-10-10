import 'package:flutter/material.dart';

/// Shared, viewport-safe selector used by form dropdowns and short pickers.
/// The bottom sheet owns one bounded scrollable so the final option remains
/// reachable on short screens, with the system gesture area kept clear.
class AppSelectOption<T> {
  final T value;
  final String label;
  final String? displayLabel;
  final Widget? leading;
  final String? subtitle;

  const AppSelectOption({
    required this.value,
    required this.label,
    this.displayLabel,
    this.leading,
    this.subtitle,
  });
}

class AppSelectField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T?> onChanged;
  final Widget? prefixIcon;
  final String? hintText;

  const AppSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.prefixIcon,
    this.hintText,
  });

  AppSelectOption<T>? get _selected {
    for (final option in options) {
      if (option.value == value) return option;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final selected = await AppSelectSheet.show<T>(
      context: context,
      title: label,
      value: value,
      options: options,
    );
    if (selected != null && context.mounted) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Semantics(
      button: true,
      label: '$label${selected == null ? '' : ', ${selected.label}'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(context),
        child: InputDecorator(
          // The child always renders either the selected value or the hint;
          // keep the label floated so it never overlaps that text.
          isEmpty: false,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: prefixIcon,
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          child: Row(
            children: [
              if (selected?.leading != null) ...[
                SizedBox(width: 28, child: selected!.leading),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  selected?.displayLabel ?? selected?.label ?? hintText ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: selected == null
                      ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)
                      : Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared bounded picker surface for selector fields and preference rows.
class AppSelectSheet {
  const AppSelectSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required T? value,
    required List<AppSelectOption<T>> options,
  }) {
    if (options.isEmpty) return Future<T?>.value();
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Colors.black54,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * .72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title,
                      style: Theme.of(sheetContext).textTheme.titleSmall),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    8,
                    0,
                    8,
                    12 + media.viewPadding.bottom + media.viewInsets.bottom,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option.value == value;
                    final scheme = Theme.of(context).colorScheme;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Material(
                        color: isSelected
                            ? scheme.primaryContainer.withValues(alpha: .58)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              Navigator.of(sheetContext).pop<T>(option.value),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                if (option.leading != null) ...[
                                  SizedBox(
                                      width: 34,
                                      child: Center(child: option.leading)),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(option.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge),
                                      if (option.subtitle != null)
                                        Text(option.subtitle!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                    color: scheme
                                                        .onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_rounded,
                                      color: scheme.primary, size: 21),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shared visual and viewport constraints for searchable autocomplete menus.
/// The menu stays within the screen and leaves room for the system gesture area.
class AppPickerOptionsSurface extends StatelessWidget {
  final Widget child;
  final double maxHeight;

  const AppPickerOptionsSurface({
    super.key,
    required this.child,
    this.maxHeight = 280,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    final height = (media.size.height * .45).clamp(120.0, maxHeight);
    final width = media.size.width - 24;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      tween: Tween(begin: .96, end: 1),
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: Material(
        elevation: 8,
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height, maxWidth: width),
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewPadding.bottom + 8),
            child: child,
          ),
        ),
      ),
    );
  }
}
