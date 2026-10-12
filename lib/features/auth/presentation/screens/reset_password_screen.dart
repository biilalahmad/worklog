import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/password_strength.dart';
import '../../../../core/widgets/auth_scaffold.dart';
import '../../domain/auth_repository.dart';
import '../providers/auth_providers.dart';

/// This screen requires a server-issued ticket created only after Supabase
/// validates the recovery OTP. A direct route/deep link cannot set a password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.ticket});

  final SecurityActionTicket? ticket;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ticket = widget.ticket;
    if (ticket == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).completeVerifiedAction(
            action: 'reset_password',
            email: ticket.email,
            ticket: ticket.value,
            newPassword: _passwordCtrl.text,
          );
      ref.read(passwordRecoveryProvider.notifier).state = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated. Please sign in.')));
        context.go('/login');
      }
    } catch (e) {
      if (mounted) setState(() => _error = Failure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    if (ticket == null) {
      return AuthScaffold(
        headerIcon: Icons.password_rounded,
        title: 'Verification required',
        subtitle: '',
        compactHeader: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => context.go('/forgot-password'),
              child: const Text('Request a verification code'),
            ),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to Login')),
          ],
        ),
      );
    }

    return AuthScaffold(
      headerIcon: Icons.password_rounded,
      title: 'Set a new password',
      subtitle: '',
      compactHeader: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) AuthBanner(message: _error!),
            TextFormField(
              controller: _passwordCtrl,
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
              validator: passwordValidationError,
            ),
            const SizedBox(height: AppSpacing.authFieldGap),
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
                  value != _passwordCtrl.text ? 'Passwords don’t match' : null,
            ),
            const SizedBox(height: AppSpacing.authFieldGap),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.ivory),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }
}
