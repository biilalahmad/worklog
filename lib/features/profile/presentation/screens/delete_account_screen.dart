import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/domain/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/security_code_flow.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _clock = SecurityCodeClock();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  SecurityActionTicket? _ticket;

  @override
  void dispose() {
    _codeCtrl.dispose();
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
          .requestSecurityCode(action: 'delete_account');
      _codeCtrl.clear();
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
            action: 'delete_account',
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently delete your account?'),
        content: const Text(
          'This permanently deletes your account and associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ticket = _ticket;
    if (ticket == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).completeVerifiedAction(
            action: 'delete_account',
            email: ticket.email,
            ticket: ticket.value,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your account was deleted.')));
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = Failure.from(e).message;
          _ticket = null;
          _codeSent = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final email = ref.watch(authRepositoryProvider).currentUserEmail;
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.delete_forever_rounded,
                    size: 44, color: scheme.error),
                const SizedBox(height: 12),
                Text(
                  _ticket != null
                      ? 'Review before deleting your account'
                      : 'Verify your email before deleting your account',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_ticket == null) ...[
                  Text(
                    'We’ll send a one-time code to ${email ?? 'your registered email'}.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const VerificationCodeLimitNotice(action: 'delete_account'),
                  const SizedBox(height: 16),
                ],
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: scheme.error.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'Your account and all associated records will be permanently removed. This cannot be undone.',
                      style: TextStyle(color: scheme.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: scheme.error),
                    onPressed: _loading ? null : _delete,
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Delete account permanently'),
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
