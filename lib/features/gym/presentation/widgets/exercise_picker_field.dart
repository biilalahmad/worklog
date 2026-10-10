import 'package:flutter/material.dart';

import '../../../../core/widgets/app_select_field.dart';
import '../../domain/exercise.dart';

/// Type-ahead exercise picker — same pattern as ClientPickerField, but
/// also lets you create a brand-new exercise by typing a name that
/// doesn't match anything yet and tapping "Add <name>".
class ExercisePickerField extends StatefulWidget {
  final List<Exercise> exercises;
  final ValueChanged<String>
      onSelectedOrCreate; // returns the exercise name (id resolved by caller)
  final String label;
  final VoidCallback? onCleared;

  const ExercisePickerField({
    super.key,
    required this.exercises,
    required this.onSelectedOrCreate,
    this.label = 'Exercise',
    this.onCleared,
  });

  @override
  State<ExercisePickerField> createState() => _ExercisePickerFieldState();
}

class _ExercisePickerFieldState extends State<ExercisePickerField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) {
          return widget.exercises.map((e) => e.name);
        }
        final q = value.text.trim().toLowerCase();
        return widget.exercises
            .map((e) => e.name)
            .where((n) => n.toLowerCase().contains(q));
      },
      onSelected: (name) {
        widget.onSelectedOrCreate(name);
        _controller.clear();
        FocusScope.of(context).unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Type an exercise name…',
            prefixIcon: const Icon(Icons.fitness_center_rounded, size: 20),
          ),
          onSubmitted: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) return;
            widget.onSelectedOrCreate(trimmed);
            controller.clear();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        final typed = _controller.text.trim();
        final exactMatch =
            list.any((o) => o.toLowerCase() == typed.toLowerCase());
        final media = MediaQuery.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: AppPickerOptionsSurface(
            maxHeight: 280,
            child: SizedBox(
              width: media.size.width - 24,
              child: ListView(
                padding:
                    EdgeInsets.fromLTRB(0, 6, 0, 12 + media.viewPadding.bottom),
                shrinkWrap: true,
                children: [
                  if (typed.isNotEmpty && !exactMatch)
                    ListTile(
                      dense: true,
                      leading:
                          Icon(Icons.add_circle_outline, color: scheme.primary),
                      title: Text('Add "$typed"',
                          style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600)),
                      onTap: () => onSelected(typed),
                    ),
                  for (final name in list)
                    ListTile(
                      dense: true,
                      leading:
                          const Icon(Icons.fitness_center_rounded, size: 18),
                      title: Text(name),
                      onTap: () => onSelected(name),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
