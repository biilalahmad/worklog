import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/offline_data_store.dart';
import '../utils/refresh_with_network.dart';

/// Check connectivity after first paint so offline launches get the same
/// brief, non-blocking notice without delaying startup.
class OfflineStartupNotice extends StatefulWidget {
  const OfflineStartupNotice({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineStartupNotice> createState() => _OfflineStartupNoticeState();
}

class _OfflineStartupNoticeState extends State<OfflineStartupNotice> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<AuthState>? _authSub;
  Timer? _offlineTimer;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      unawaited(_syncPending());
    });
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivity);
    unawaited(_checkConnectivity());
    unawaited(_syncPending());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!await hasInternetForWorkLog() && mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text('Please try connecting to the internet.')),
                ],
              ),
            ),
          );
      }
    });
  }

  Future<void> _checkConnectivity() async {
    _onConnectivity(await Connectivity().checkConnectivity());
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final connected =
        results.any((result) => result != ConnectivityResult.none);
    _offlineTimer?.cancel();
    if (connected) {
      if (mounted && _offline) setState(() => _offline = false);
      unawaited(_syncPending());
      return;
    }
    _offlineTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _offline = true);
    });
  }

  Future<void> _syncPending() async {
    if (!await hasInternetForWorkLog()) return;
    try {
      final synced = await OfflineDataStore.instance
          .syncPendingWrites(Supabase.instance.client);
      if (!synced && mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                  'Some offline changes need attention. Tap Retry when ready.'),
              duration: Duration(seconds: 4),
            ),
          );
      }
    } catch (_) {
      // Keep the durable outbox intact; the next reconnect/auth event retries.
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(child: widget.child),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _offline ? 0 : -56,
            left: 0,
            right: 0,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                            'Offline — changes are saved on this device and will sync when you reconnect.'),
                      ),
                      TextButton(
                        onPressed: () => unawaited(_syncPending()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _authSub?.cancel();
    _offlineTimer?.cancel();
    super.dispose();
  }
}
