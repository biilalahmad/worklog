import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/client.dart';
import '../providers/client_providers.dart';

/// Add/edit a client. Pass an existing [client] to edit, or null to
/// create a new one.
class ClientFormScreen extends ConsumerStatefulWidget {
  final Client? client;
  const ClientFormScreen({super.key, this.client});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.client?.name ?? '');
  late final _emailCtrl =
      TextEditingController(text: widget.client?.email ?? '');
  late final _phoneCtrl =
      TextEditingController(text: widget.client?.phone ?? '');
  late final _notesCtrl =
      TextEditingController(text: widget.client?.notes ?? '');
  late final _retainerAmountCtrl = TextEditingController(
      text: widget.client?.retainerAmountMinor != null
          ? Money(widget.client!.retainerAmountMinor!,
                  widget.client!.retainerCurrency ?? 'PKR')
              .asDouble
              .toStringAsFixed(2)
          : '');
  bool _saving = false;
  late bool _isRetainer = widget.client?.isRetainer ?? false;
  late String _retainerCurrency =
      widget.client?.retainerCurrency ?? supportedCurrencies.first;
  late int _retainerDay = widget.client?.retainerDayOfMonth ?? 1;
  String _countryCode = '+92';

  static const _countryCodes = <(String, String, String)>[
    ('Pakistan', '+92', 'PK'),
    ('United Arab Emirates', '+971', 'AE'),
    ('Saudi Arabia', '+966', 'SA'),
    ('United Kingdom', '+44', 'GB'),
    ('United States', '+1', 'US'),
    ('India', '+91', 'IN'),
  ];

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    if (widget.client == null) {
      _retainerCurrency = ref.read(defaultCurrencyProvider);
    }
    final phone = _phoneCtrl.text.trim();
    for (final item in _countryCodes) {
      if (phone.startsWith(item.$2)) {
        _countryCode = item.$2;
        _phoneCtrl.text = phone.substring(item.$2.length);
        break;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _retainerAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(clientRepositoryProvider);
    final retainerAmountMinor = _isRetainer
        ? Money.toMinorUnits(
            double.tryParse(_retainerAmountCtrl.text.trim()) ?? 0,
            _retainerCurrency)
        : null;
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        final updated = widget.client!.copyWith(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty
              ? null
              : '$_countryCode${_phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '')}',
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          isRetainer: _isRetainer,
          retainerAmountMinor: retainerAmountMinor,
          retainerCurrency: _retainerCurrency,
          retainerDayOfMonth: _retainerDay,
        );
        await repo.updateClient(updated);
      } else {
        final newClient = Client(
          id: '',
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty
              ? null
              : '$_countryCode${_phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '')}',
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          isRetainer: _isRetainer,
          retainerAmountMinor: retainerAmountMinor,
          retainerCurrency: _retainerCurrency,
          retainerDayOfMonth: _retainerDay,
        );
        await repo.addClient(newClient);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.save(e).message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Client' : 'New Client')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Client Name *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                  labelText: 'Email', hintText: 'name@example.com'),
              validator: (v) {
                final email = v?.trim() ?? '';
                if (email.isEmpty) return null;
                return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)
                    ? null
                    : 'Enter a valid email address';
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              SizedBox(
                width: 138,
                child: AppSelectField<String>(
                  value: _countryCode,
                  label: 'Country',
                  options: _countryCodes
                      .map((item) => AppSelectOption(
                            value: item.$2,
                            label: '${item.$1} ${item.$2}',
                            displayLabel: item.$2,
                            leading: _CountryFlag(code: item.$3),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _countryCode = value ?? _countryCode),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Phone number', hintText: '300 1234567'),
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.isEmpty) return null;
                  return digits.length >= 7 && digits.length <= 14
                      ? null
                      : 'Enter a valid phone number';
                },
              )),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Retainer client'),
              subtitle:
                  const Text('Auto-generate a recurring invoice each month'),
              value: _isRetainer,
              onChanged: (v) => setState(() => _isRetainer = v),
            ),
            if (_isRetainer) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _retainerAmountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Monthly amount *'),
                      validator: (v) {
                        if (!_isRetainer) return null;
                        if (v == null ||
                            double.tryParse(v.trim()) == null ||
                            double.parse(v.trim()) <= 0) {
                          return 'Enter an amount';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppSelectField<String>(
                      value: _retainerCurrency,
                      label: 'Currency',
                      options: supportedCurrencies
                          .map((c) => AppSelectOption(value: c, label: c))
                          .toList(),
                      onChanged: (v) => setState(
                          () => _retainerCurrency = v ?? _retainerCurrency),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppSelectField<int>(
                value: _retainerDay,
                label: 'Bill on day of month',
                options: List.generate(28, (i) => i + 1)
                    .map((d) => AppSelectOption(value: d, label: 'Day $d'))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _retainerDay = v ?? _retainerDay),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Save Changes' : 'Add Client'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryFlag extends StatelessWidget {
  const _CountryFlag({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(26, 18),
        painter: _CountryFlagPainter(code),
      );
}

class _CountryFlagPainter extends CustomPainter {
  const _CountryFlagPainter(this.code);
  final String code;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final clip = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.save();
    canvas.clipRRect(clip);
    final white = Paint()..color = Colors.white;
    final red = Paint()..color = const Color(0xffd62828);
    final green = Paint()..color = const Color(0xff08783e);
    switch (code) {
      case 'PK':
        canvas.drawRect(rect, Paint()..color = const Color(0xff01411c));
        canvas.drawRect(
            Rect.fromLTWH(0, 0, size.width * .24, size.height), white);
        canvas.drawCircle(Offset(size.width * .64, size.height * .48),
            size.height * .30, white);
        canvas.drawCircle(Offset(size.width * .70, size.height * .42),
            size.height * .27, Paint()..color = const Color(0xff01411c));
      case 'AE':
        canvas.drawRect(rect, white);
        canvas.drawRect(
            Rect.fromLTWH(
                size.width * .25, 0, size.width * .75, size.height / 3),
            green);
        canvas.drawRect(
            Rect.fromLTWH(size.width * .25, size.height * 2 / 3,
                size.width * .75, size.height / 3),
            Paint()..color = Colors.black);
        canvas.drawRect(
            Rect.fromLTWH(0, 0, size.width * .25, size.height), red);
      case 'SA':
        canvas.drawRect(rect, green);
        canvas.drawRect(
            Rect.fromLTWH(size.width * .35, size.height * .57, size.width * .42,
                size.height * .08),
            white);
      case 'GB':
        canvas.drawRect(rect, Paint()..color = const Color(0xff012169));
        final whiteLine = Paint()
          ..color = Colors.white
          ..strokeWidth = size.height * .28;
        final redLine = Paint()
          ..color = const Color(0xffc8102e)
          ..strokeWidth = size.height * .11;
        canvas.drawLine(
            Offset.zero, Offset(size.width, size.height), whiteLine);
        canvas.drawLine(
            Offset(size.width, 0), Offset(0, size.height), whiteLine);
        canvas.drawRect(
            Rect.fromLTWH(size.width * .42, 0, size.width * .16, size.height),
            white);
        canvas.drawRect(
            Rect.fromLTWH(0, size.height * .39, size.width, size.height * .22),
            white);
        canvas.drawRect(
            Rect.fromLTWH(size.width * .46, 0, size.width * .08, size.height),
            red);
        canvas.drawRect(
            Rect.fromLTWH(0, size.height * .44, size.width, size.height * .12),
            red);
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), redLine);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), redLine);
      case 'US':
        canvas.drawRect(rect, white);
        for (var i = 0; i < 7; i++) {
          canvas.drawRect(
              Rect.fromLTWH(
                  0, i * size.height / 7, size.width, size.height / 14),
              red);
        }
        canvas.drawRect(
            Rect.fromLTWH(0, 0, size.width * .48, size.height * .55),
            Paint()..color = const Color(0xff1b3a70));
      case 'IN':
        canvas.drawRect(rect, white);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 3),
            Paint()..color = const Color(0xffff9933));
        canvas.drawRect(
            Rect.fromLTWH(0, size.height * 2 / 3, size.width, size.height / 3),
            green);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2),
            size.height * .16, Paint()..color = const Color(0xff1b3a70));
      default:
        canvas.drawRect(rect, white);
    }
    canvas.restore();
    canvas.drawRRect(
        clip,
        Paint()
          ..color = Colors.black.withValues(alpha: .14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7);
  }

  @override
  bool shouldRepaint(covariant _CountryFlagPainter oldDelegate) =>
      oldDelegate.code != code;
}
