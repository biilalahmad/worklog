import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/offline_data_store.dart';
import '../utils/backend_connection.dart';
import 'no_internet_screen.dart';

/// Monitors real Supabase reachability and retries the user-scoped outbox
/// after a successful reconnect without adding a persistent top banner.
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
  bool _retrying = false;
  bool _recovering = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _authSub = _client.auth.onAuthStateChange.listen((_) {
      unawaited(_checkAndSync());
    });
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivity);
    unawaited(_checkAndSync());
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
    }
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
    });

    var online = false;
    try {
      final transport = await Connectivity().checkConnectivity();
      online = transport.isNotEmpty &&
          transport.any((result) => result != ConnectivityResult.none);
      if (online && _client.auth.currentUser != null) {
        if (mounted) setState(() => _recovering = true);
        online = await BackendConnection.instance.check(_client);
      }

      if (!online) {
        BackendConnection.instance.reportUnavailable();
        return;
      }

      BackendConnection.instance.reportAvailable();
      final synced = await OfflineDataStore.instance.syncPendingWrites(_client);
      if (!synced && mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                  'Some saved changes need attention. They will retry when the connection is ready.'),
              duration: Duration(seconds: 4),
            ),
          );
      }
      // Give subscriptions a brief chance to read their local snapshots and
      // reconnect before returning the user to the workspace.
      await Future<void>.delayed(const Duration(milliseconds: 350));
    } catch (_) {
      online = false;
      BackendConnection.instance.reportUnavailable();
    } finally {
      if (mounted) {
        setState(() {
          _retrying = false;
          _recovering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: BackendConnection.instance.isAvailable,
      builder: (context, isAvailable, _) {
        final signedIn = _client.auth.currentUser != null;
        if (signedIn && isAvailable == false && !_recovering) {
          return NoInternetScreen(
            isRetrying: _retrying,
            onRetry: _retry,
          );
        }
        if (_recovering) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF183B60),
                ),
              ),
            ),
          );
        }
        return widget.child;
      },
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
