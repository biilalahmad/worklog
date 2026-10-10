import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/auth_scaffold.dart';
import '../providers/auth_providers.dart';

/// Shown right after signup — NOT logged into the app yet. The user
/// must tap the verification link in their email before they can log in.
class CheckEmailScreen extends ConsumerStatefulWidget {
  final String email;
  const CheckEmailScreen({super.key, required this.email});

  @override
  ConsumerState<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<CheckEmailScreen> {
  static const _cooldownSeconds = 45;
  int _secondsLeft = 0;
  Timer? _timer;
  bool _sending = false;
  String? _info;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _secondsLeft = _cooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _info = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendVerification(widget.email);
      if (mounted) setState(() => _info = 'Verification email sent again.');
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => _info = Failure.from(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onCooldown = _secondsLeft > 0;
    return AuthScaffold(
      headerIcon: Icons.mark_email_read_outlined,
      title: 'Check your email',
      subtitle: 'We sent a verification link to\n${widget.email}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.mint, borderRadius: BorderRadius.circular(18)),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.forest),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tap "Verify Your Account" in that email. You’ll see a success message on the WorkLog website, then return here to log in. The link expires in 24 hours.',
                    style: TextStyle(color: AppColors.forest),
                  ),
                ),
              ],
            ),
          ),
          if (_info != null) ...[
            const SizedBox(height: 16),
            Text(_info!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: (_sending || onCooldown) ? null : _resend,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            label: Text(onCooldown
                ? 'Resend in ${_secondsLeft}s'
                : 'Resend verification email'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }
}
