import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks whether WorkLog's authenticated Supabase endpoint is reachable.
/// Device Wi-Fi status alone is not enough to establish internet access.
class BackendConnection {
  BackendConnection._();

  static final BackendConnection instance = BackendConnection._();

  final ValueNotifier<bool?> isAvailable = ValueNotifier<bool?>(null);
  final ValueNotifier<bool> startupGateVisible = ValueNotifier<bool>(false);
  Future<bool>? _probe;

  Future<bool> check(SupabaseClient client) {
    final current = _probe;
    if (current != null) return current;
    final check = _check(client);
    _probe = check;
    return check.whenComplete(() => _probe = null);
  }

  Future<bool> _check(SupabaseClient client) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      isAvailable.value = null;
      return false;
    }

    try {
      final transport = await Connectivity().checkConnectivity();
      if (transport.isEmpty ||
          transport.every((result) => result == ConnectivityResult.none)) {
        isAvailable.value = false;
        return false;
      }

      await client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      isAvailable.value = true;
      return true;
    } catch (_) {
      isAvailable.value = false;
      return false;
    }
  }

  void reportUnavailable() => isAvailable.value = false;

  void reportAvailable() => isAvailable.value = true;
}
