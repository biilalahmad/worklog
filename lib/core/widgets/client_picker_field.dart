import 'package:flutter/material.dart';

import 'app_select_field.dart';
import '../../features/clients/domain/client.dart';

/// A type-ahead client field: start typing a name and pick from the
/// filtered suggestions that drop down live, instead of opening a
/// closed dropdown menu and scrolling through every client. Still
/// resolves to a real client id (never free text) so it stays a valid
/// foreign key — typing something that doesn't match an existing
/// client, or editing the text after picking one, clears the
/// selection until a suggestion is tapped again.
class ClientPickerField extends StatefulWidget {
  final List<Client> clients;
  final String? initialClientId;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool required;
  final String? errorText;
  final double maxOptionsHeight;

  const ClientPickerField({
    super.key,
    required this.clients,
    required this.onChanged,
    this.initialClientId,
    this.label = 'Client',
    this.required = true,
    this.errorText,
    this.maxOptionsHeight = 260,
  });

  @override
  State<ClientPickerField> createState() => _ClientPickerFieldState();
}

class _ClientPickerFieldState extends State<ClientPickerField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _selectedId;

  Client? _byId(String? id) {
    if (id == null) return null;
    for (final c in widget.clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialClientId;
    _controller = TextEditingController(text: _byId(_selectedId)?.name ?? '');
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant ClientPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clients load asynchronously — backfill the display name once the
    // list arrives if we already had a selected id but no label yet.
    if (_selectedId != null && _controller.text.isEmpty) {
      final match = _byId(_selectedId);
      if (match != null) _controller.text = match.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RawAutocomplete<Client>(
      key: ValueKey(_selectedId ?? 'unselected-client'),
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        // A modal picker (e.g. Project) can restore focus to this field when
        // it closes. Keep suggestions closed after selection; typing changes
        // the text, clears the selection, and opens matching options again.
        if (_selectedId != null) {
          return const <Client>[];
        }
        if (value.text.trim().isEmpty) return widget.clients;
        final q = value.text.trim().toLowerCase();
        return widget.clients.where((c) => c.name.toLowerCase().contains(q));
      },
      displayStringForOption: (c) => c.name,
      onSelected: (c) {
        setState(() => _selectedId = c.id);
        widget.onChanged(c.id);
        _focusNode.unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          readOnly: _selectedId != null,
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.label} *' : widget.label,
            errorText: widget.errorText,
            hintText: 'Type a name…',
            prefixIcon: const Icon(Icons.person_search_rounded, size: 20),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      controller.clear();
                      setState(() => _selectedId = null);
                      widget.onChanged(null);
                    },
                  ),
          ),
          onChanged: (text) {
            if (_selectedId != null) {
              final match = _byId(_selectedId);
              if (match == null || match.name != text) {
                setState(() => _selectedId = null);
                widget.onChanged(null);
              }
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        final media = MediaQuery.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: AppPickerOptionsSurface(
            maxHeight: widget.maxOptionsHeight,
            child: SizedBox(
              width: media.size.width - 24,
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No client found',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                          0, 6, 0, 12 + media.viewPadding.bottom),
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final c = list[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 15,
                            backgroundColor: scheme.primaryContainer,
                            child: Text(
                              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onPrimaryContainer),
                            ),
                          ),
                          title: Text(c.name),
                          onTap: () => onSelected(c),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }
}
