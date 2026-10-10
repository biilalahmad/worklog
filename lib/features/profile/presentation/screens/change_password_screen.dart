import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/utils/password_strength.dart';
import '../../../auth/domain/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/security_code_flow.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _clock = SecurityCodeClock();
  bool _codeSent = false;
  bool _obscure = true;
  bool _obscureCurrent = true;
  bool _loading = false;
  String? _error;
  SecurityActionTicket? _ticket;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _clock.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestSecurityCode(action: 'change_password');
      _codeCtrl.clear();
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      _clock.start();
      if (mounted) {
        setState(() {
          _codeSent = true;
          _ticket = null;
        });
      }
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
            action: 'change_password',
            code: _codeCtrl.text,
          );
      if (mounted) {
        setState(() => _ticket = ticket);
      }
    } catch (e) {
      if (mounted) setState(() => _error = Failure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ticket = _ticket;
    if (ticket == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).completeVerifiedAction(
            action: 'change_password',
            email: ticket.email,
            ticket: ticket.value,
            currentPassword: _currentCtrl.text,
            newPassword: _newCtrl.text,
          );
      if (mounted) {
        AppSnackBar.show(context, message: 'Password updated successfully');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final failure = Failure.from(e);
        const retryWithoutNewCode = {
          'password_policy',
          'password_reuse',
          'invalid_current_password',
          'password_change_limit',
          'password_verification_unavailable',
        };
        setState(() {
          _error = failure.message;
          // These checks happen before the ticket is consumed, so the user can
          // correct their password without having to request another code.
          if (!retryWithoutNewCode.contains(failure.code)) {
            _ticket = null;
            _codeSent = false;
            _currentCtrl.clear();
            _newCtrl.clear();
            _confirmCtrl.clear();
          }
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authRepositoryProvider).currentUserEmail;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_ticket != null)
                  const VerifiedEmailNotice(
                    subtitle: 'Set your new password below.',
                  )
                else ...[
                  const VerificationCodeLimitNotice(action: 'change_password'),
                  const SizedBox(height: 14),
                  Text(
                    'We’ll send a one-time code to ${email ?? 'your registered email'} before allowing a password change.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(_error!,
                        style: TextStyle(color: scheme.onErrorContainer)),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_ticket == null && !_codeSent)
                  FilledButton.icon(
                    onPressed: _loading ? null : _requestCode,
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Send verification code'),
                  )
                else if (_ticket == null)
                  SecurityCodePanel(
                    controller: _codeCtrl,
                    clock: _clock,
                    busy: _loading,
                    onVerify: _verifyCode,
                    onResend: _requestCode,
                    verifyLabel: 'Verify email',
                  )
                else ...[
                  TextFormField(
                    controller: _currentCtrl,
                    obscureText: _obscureCurrent,
                    enabled: !_loading,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your current password'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newCtrl,
                    obscureText: _obscure,
                    enabled: !_loading,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      hintText: '8+ characters, including a letter and number',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (value) {
                      final policyError = passwordValidationError(value);
                      if (policyError != null) return policyError;
                      if (value == _currentCtrl.text) {
                        return 'New password must differ from your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscure,
                    enabled: !_loading,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) =>
                        value != _newCtrl.text ? 'Passwords don’t match' : null,
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.ivory),
                          )
                        : const Text('Update Password'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
