import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/backend_connection.dart';
import '../../../../core/widgets/no_internet_screen.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// Short, bounded gate while the signed-in profile is loaded. Returning users
/// with a completed local profile are routed directly to their cached app.
class LaunchingScreen extends ConsumerStatefulWidget {
  const LaunchingScreen({super.key});

  @override
  ConsumerState<LaunchingScreen> createState() => _LaunchingScreenState();
}

class _LaunchingScreenState extends ConsumerState<LaunchingScreen> {
  static const _loadTimeout = Duration(seconds: 10);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timeout;
  bool _showOffline = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    BackendConnection.instance.startupGateVisible.value = true;
    _startTimeout();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasTransport =
          results.any((result) => result != ConnectivityResult.none);
      if (hasTransport && _showOffline && !_retrying) {
        unawaited(_retry());
      }
    });
  }

  void _startTimeout() {
    _timeout?.cancel();
    _timeout = Timer(_loadTimeout, () {
      if (mounted) setState(() => _showOffline = true);
    });
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);

    final reachable =
        await BackendConnection.instance.check(Supabase.instance.client);
    if (!mounted) return;
    if (!reachable) {
      setState(() {
        _retrying = false;
        _showOffline = true;
      });
      return;
    }

    // Recreate both streams after a successful real backend check. This lets
    // the router transition as soon as profile/onboarding data is received.
    ref.invalidate(profileProvider);
    ref.invalidate(onboardingDoneProvider);
    setState(() {
      _retrying = false;
      _showOffline = false;
    });
    _startTimeout();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile.hasError || _showOffline) {
      return NoInternetScreen(
        isRetrying: _retrying,
        onRetry: _retry,
      );
    }

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/worklog_icon.png',
                  width: 48,
                  height: 48,
                  semanticLabel: 'WorkLog',
                ),
                const SizedBox(height: 18),
                Text('Getting your workspace ready',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 18),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    BackendConnection.instance.startupGateVisible.value = false;
    _timeout?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
