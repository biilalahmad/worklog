import 'dart:async';

import 'package:flutter/material.dart';

/// UI countdown only. The Edge Function and private database challenge
/// enforce the real expiry; this timer never authorizes a security action.
class SecurityCodeClock extends ChangeNotifier {
  SecurityCodeClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  Timer? _timer;
  DateTime? _expiresAt;
  DateTime? _resendAt;

  bool get active => _expiresAt != null && secondsRemaining > 0;
  int get secondsRemaining => _secondsUntil(_expiresAt);
  int get resendSeconds => _secondsUntil(_resendAt);

  void start() {
    _timer?.cancel();
    final now = _now();
    _expiresAt = now.add(const Duration(seconds: 180));
    _resendAt = now.add(const Duration(seconds: 60));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  /// Refreshes the display countdown. Exposed so tests can advance a fake
  /// clock without waiting three real minutes; this is never server authority.
  void tick() {
    notifyListeners();
    if (secondsRemaining == 0 && resendSeconds == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _expiresAt = null;
    _resendAt = null;
    notifyListeners();
  }

  int _secondsUntil(DateTime? deadline) {
    if (deadline == null) return 0;
    final seconds = deadline.difference(_now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  String format(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class SecurityCodePanel extends StatelessWidget {
  const SecurityCodePanel({
    super.key,
    required this.controller,
    required this.clock,
    required this.busy,
    required this.onVerify,
    required this.onResend,
    this.verifyLabel = 'Verify code',
  });

  final TextEditingController controller;
  final SecurityCodeClock clock;
  final bool busy;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final String verifyLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: clock,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: controller,
            enabled: !busy && clock.active,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Email verification code',
              hintText: 'Enter the code from your email',
              prefixIcon: Icon(Icons.password_rounded),
              counterText: '',
            ),
            validator: (value) =>
                value == null || !RegExp(r'^\d{6,10}$').hasMatch(value.trim())
                    ? 'Enter the 6–10 digit code from your email'
                    : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.timer_outlined,
                  size: 17, color: scheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  clock.active
                      ? 'Code expires in ${clock.format(clock.secondsRemaining)}'
                      : 'Code expired. Request a new one.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed: busy || clock.resendSeconds > 0 ? null : onResend,
                child: Text(clock.resendSeconds > 0
                    ? 'Resend ${clock.resendSeconds}s'
                    : 'Resend code'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy || !clock.active ? null : onVerify,
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(verifyLabel),
          ),
        ],
      ),
    );
  }
}

class VerificationCodeLimitNotice extends StatelessWidget {
  const VerificationCodeLimitNotice({super.key, required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subject = switch (action) {
      'change_password' => 'password-change',
      'delete_account' => 'account-deletion',
      _ => 'password reset',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'For your security, you can request up to 7 $subject verification codes every 24 hours.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class VerifiedEmailNotice extends StatelessWidget {
  const VerifiedEmailNotice({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.verified_user_rounded, color: scheme.primary, size: 30),
          const SizedBox(height: 8),
          Text(
            'Email verified',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
