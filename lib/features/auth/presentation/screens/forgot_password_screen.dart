import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/auth_scaffold.dart';
import '../providers/auth_providers.dart';
import '../widgets/security_code_flow.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _clock = SecurityCodeClock();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _clock.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_codeSent && !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestSecurityCode(
            action: 'reset_password',
            email: _emailCtrl.text.trim(),
          );
      _codeCtrl.clear();
      _clock.start();
      if (mounted) setState(() => _codeSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = Failure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ticket = await ref.read(authRepositoryProvider).verifySecurityCode(
            action: 'reset_password',
            email: _emailCtrl.text.trim(),
            code: _codeCtrl.text,
          );
      if (mounted) context.go('/reset-password', extra: ticket);
    } catch (e) {
      if (mounted) setState(() => _error = Failure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      headerIcon: Icons.lock_reset_rounded,
      title: _codeSent ? 'Verify your email' : 'Reset password',
      subtitle: _codeSent
          ? 'Enter the code sent to your email.'
          : 'Enter the email linked to your WorkLog account to receive a reset code.',
      compactHeader: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) AuthBanner(message: _error!),
            const VerificationCodeLimitNotice(
              action: 'reset_password',
              compact: true,
            ),
            const SizedBox(height: AppSpacing.authFieldGap),
            if (!_codeSent) ...[
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) => value == null ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(value.trim())
                    ? 'Enter a valid email address'
                    : null,
              ),
              const SizedBox(height: AppSpacing.authFieldGap),
              FilledButton(
                onPressed: _loading ? null : _requestCode,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.ivory),
                      )
                    : const Text('Send verification code'),
              ),
            ] else ...[
              SecurityCodePanel(
                controller: _codeCtrl,
                clock: _clock,
                busy: _loading,
                onVerify: _verifyCode,
                onResend: _requestCode,
                verifyLabel: 'Verify and continue',
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _codeSent = false;
                            _error = null;
                            _clock.reset();
                          }),
                  child: const Text('Use a different email'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _loading ? null : () => context.go('/login'),
                child: const Text('Back to Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
