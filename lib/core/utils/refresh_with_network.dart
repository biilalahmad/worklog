import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/failure.dart';
import 'backend_connection.dart';

Future<void> refreshWithNetworkMessage(
    BuildContext context, Future<void> Function() refresh) async {
  // Local-cache fallbacks can make a refresh future complete successfully
  // while the server is still unreachable, so confirm WorkLog connectivity
  // before treating Retry as successful.
  final reachable =
      await BackendConnection.instance.check(Supabase.instance.client);
  if (!reachable) {
    if (context.mounted) _showOfflineMessage(context);
    return;
  }

  try {
    await refresh();
    BackendConnection.instance.reportAvailable();
  } catch (error) {
    if (!context.mounted) return;
    if (Failure.from(error).isNetwork) {
      BackendConnection.instance.reportUnavailable();
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
      const SnackBar(
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(Icons.wifi_off_rounded, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('Please try connecting to the internet.')),
          ],
        ),
      ),
    );
}
