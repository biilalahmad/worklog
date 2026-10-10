import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../errors/failure.dart';

/// Fast transport hint only. Never probe a remote endpoint before refresh:
/// the real request is the source of truth and can fall back to local data.
Future<bool> hasInternetForWorkLog() async {
  final transport = await Connectivity().checkConnectivity();
  return transport.isNotEmpty &&
      transport.any((result) => result != ConnectivityResult.none);
}

Future<void> refreshWithNetworkMessage(
    BuildContext context, Future<void> Function() refresh) async {
  try {
    await refresh();
  } catch (error) {
    if (!context.mounted) return;
    if (Failure.from(error).isNetwork) {
      _showOfflineMessage(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Failure.from(error).message)),
      );
    }
  }
}

void _showOfflineMessage(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        content: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('Please try connecting to the internet.')),
          ],
        ),
      ),
    );
}
