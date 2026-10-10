import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// A thin banner that appears at the top of the screen when the
/// device has no network connection.
///
/// `connectivity_plus` only reports the *type* of connection (wifi/
/// cellular/none), not whether it's actually working — and brief
/// blips during network handoffs (e.g. wifi -> cellular) can report
/// "none" for a fraction of a second even with a perfectly stable
/// connection. Showing the banner immediately on every blip is what
/// caused the false "Disconnected" reports. This widget instead waits
/// for "none" to persist for a full 2.5s before showing anything, and
/// hides the banner the instant connectivity is reported again — so
/// it only ever fires for a genuine, sustained outage, and always
/// recovers automatically.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounce;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _sub = Connectivity().onConnectivityChanged.listen(_onChange);
  }

  Future<void> _checkInitial() async {
    final result = await Connectivity().checkConnectivity();
    _onChange(result);
  }

  void _onChange(List<ConnectivityResult> results) {
    final isNone = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    _debounce?.cancel();
    if (!isNone) {
      // Recover immediately — no need to debounce good news.
      if (mounted && _offline) setState(() => _offline = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _offline = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();
    return Material(
      color: Colors.orange.shade700,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No internet connection — new changes won\'t be saved until the connection returns.',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
