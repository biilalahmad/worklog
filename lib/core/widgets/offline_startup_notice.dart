import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/offline_data_store.dart';
import '../utils/backend_connection.dart';

/// Monitors real Supabase reachability, keeps offline status visible, and
/// retries the user-scoped outbox after a successful reconnect.
class OfflineStartupNotice extends StatefulWidget {
  const OfflineStartupNotice({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineStartupNotice> createState() => _OfflineStartupNoticeState();
}

class _OfflineStartupNoticeState extends State<OfflineStartupNotice> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<AuthState>? _authSub;
  bool _checking = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    BackendConnection.instance.isAvailable.addListener(_onStatusChanged);
    BackendConnection.instance.startupGateVisible.addListener(_onStatusChanged);
    OfflineDataStore.instance.pendingWritesRevision
        .addListener(_onStatusChanged);
    _authSub = _client.auth.onAuthStateChange.listen((_) {
      unawaited(_checkAndSync());
    });
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivity);
    unawaited(_checkAndSync());
  }

  void _onStatusChanged() {
    if (!mounted) return;

    // Startup gate state can change from a descendant's initState/dispose
    // while Flutter is mounting or unmounting this ancestor. Defer those
    // notifications until the current frame is unlocked.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      setState(() {});
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    if (_client.auth.currentUser == null) return;
    final connected =
        results.any((result) => result != ConnectivityResult.none);
    if (!connected) {
      BackendConnection.instance.reportUnavailable();
      return;
    }
    unawaited(_checkAndSync());
  }

  Future<void> _checkAndSync() async {
    if (_checking) return;
    if (_client.auth.currentUser == null) {
      BackendConnection.instance.isAvailable.value = null;
      return;
    }

    _checking = true;
    if (mounted) setState(() {});
    try {
      final online = await BackendConnection.instance.check(_client);
      if (online) {
        final synced =
            await OfflineDataStore.instance.syncPendingWrites(_client);
        if (!synced && mounted) {
          ScaffoldMessenger.maybeOf(context)
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                    'Some saved changes need attention. Tap Retry when ready.'),
                duration: Duration(seconds: 4),
              ),
            );
        }
      }
    } catch (_) {
      // The durable, user-scoped queue remains available for the next retry.
    } finally {
      _checking = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final unavailable = BackendConnection.instance.isAvailable.value == false &&
        _client.auth.currentUser != null &&
        !BackendConnection.instance.startupGateVisible.value;

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: unavailable
              ? Material(
                  color: colors.surfaceContainerHigh,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              color: colors.onSurface, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: FutureBuilder<int>(
                                key: ValueKey(OfflineDataStore
                                    .instance.pendingWritesRevision.value),
                                future: OfflineDataStore.instance
                                    .pendingCount(_client),
                                builder: (context, snapshot) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'No internet connection',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    if ((snapshot.data ?? 0) > 0)
                                      Text(
                                        '${snapshot.data} changes waiting to sync',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _checking
                                ? null
                                : () => unawaited(_checkAndSync()),
                            child: _checking
                                ? SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary,
                                    ),
                                  )
                                : const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }

  @override
  void dispose() {
    BackendConnection.instance.isAvailable.removeListener(_onStatusChanged);
    BackendConnection.instance.startupGateVisible
        .removeListener(_onStatusChanged);
    OfflineDataStore.instance.pendingWritesRevision
        .removeListener(_onStatusChanged);
    _connectivitySub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
