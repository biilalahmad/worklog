import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/utils/password_strength.dart';
import '../../../../core/widgets/auth_scaffold.dart';
import '../../../../core/widgets/social_icon_button.dart';
import '../providers/auth_providers.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;
  PasswordStrength _strength = PasswordStrength.tooShort;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(authRepositoryProvider).signUp(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            displayName: _nameCtrl.text.trim(),
          );
      if (!mounted) return;
      if (result.needsVerification) {
        context.pushReplacement('/check-email', extra: _emailCtrl.text.trim());
      }
      // Otherwise (email confirmation disabled on the project) the auth
      // stream already flips signed-in and the router takes over.
    } catch (e) {
      if (mounted) setState(() => _error = Failure.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = Failure.from(e).message);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _googleLoading;
    final strengthLabel = switch (_strength) {
      PasswordStrength.tooShort => null,
      PasswordStrength.weak => 'Weak',
      PasswordStrength.strong => 'Strong',
    };
    final strengthColor = _strength == PasswordStrength.strong
        ? Colors.green.shade700
        : Colors.orange.shade800;

    return AuthScaffold(
      headerIcon: Icons.person_add_alt_1_rounded,
      title: 'Create Account',
      subtitle: 'Track your work, get paid on time',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) AuthBanner(message: _error!),
            const Text('Name',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              enabled: !busy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  hintText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline)),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            const Text('Email',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              enabled: !busy,
              decoration: const InputDecoration(
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.mail_outline)),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                    child: Text('Password',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
                if (strengthLabel != null)
                  Text(strengthLabel,
                      style: TextStyle(
                          color: strengthColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              enabled: !busy,
              onChanged: (v) =>
                  setState(() => _strength = passwordStrengthOf(v)),
              decoration: InputDecoration(
                hintText: 'At least 8 characters',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => passwordValidationError(v),
            ),
            const SizedBox(height: 16),
            const Text('Confirm Password',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              enabled: !busy,
              decoration: InputDecoration(
                hintText: 'Re-enter your password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) =>
                  v != _passwordCtrl.text ? 'Passwords don\'t match' : null,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.ivory))
                  : const Text('Sign Up'),
            ),
            const SizedBox(height: 22),
            const OrDivider(label: 'or sign up with'),
            const SizedBox(height: 18),
            Center(
              child: SocialIconButton(
                tooltip: 'Continue with Google',
                icon: _googleLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const GoogleMark(),
                onPressed: busy ? null : _google,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Already have an account?',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                TextButton(
                  onPressed: busy ? null : () => context.pop(),
                  child: Text(
                    'Sign in',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
