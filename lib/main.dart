import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'app/theme/theme_mode_provider.dart';
import 'core/config/supabase_config.dart';
import 'core/errors/app_error_handlers.dart';
import 'features/clients/presentation/providers/client_providers.dart';
import 'features/onboarding/presentation/providers/first_launch_provider.dart';
import 'features/reminders/presentation/providers/notification_provider.dart';
import 'services/notifications/notification_service.dart';

Future<void> main() async {
  installGlobalErrorHandlers();
  await runZonedGuarded(_initializeAndRun, (error, stack) {
    if (kDebugMode) {
      debugPrint('Uncaught application error: $error');
      debugPrintStack(stackTrace: stack);
    }
  });
}

Future<void> _initializeAndRun() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final preferences = await SharedPreferences.getInstance();
  final firstLaunchComplete =
      preferences.getBool(firstLaunchPreferenceKey) ?? false;
  final savedTheme =
      themeModeFromPreference(preferences.getString(themeModePreferenceKey));

  final notificationService = NotificationService();
  await notificationService.init();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  // Built manually (rather than via runApp(ProviderScope(...))) so the
  // router exists before runApp — needed to wire a notification tap to
  // real navigation. WorkLogApp reads routerProvider from this exact
  // same container, so there's only ever one GoRouter instance.
  final container = ProviderContainer(
    overrides: [
      notificationServiceProvider.overrideWithValue(notificationService),
      themeModeProvider
          .overrideWith((ref) => ThemeModeController(savedTheme, preferences)),
      firstLaunchCompleteProvider.overrideWith((ref) => firstLaunchComplete),
    ],
  );

  if (SupabaseConfig.isConfigured) {
    final router = container.read(routerProvider);
    notificationService.onNotificationTap = (payload) {
      if (payload == null || payload.isEmpty) {
        router.go('/reminders');
      } else if (payload.startsWith('project:')) {
        unawaited(_openOverdueProject(
            container, router, payload.substring('project:'.length)));
      } else {
        router.go('/reminders?open=${Uri.encodeQueryComponent(payload)}');
      }
    };
    final launchPayload = notificationService.takeLaunchPayload();
    if (launchPayload != null) {
      notificationService.onNotificationTap?.call(launchPayload);
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WorkLogApp(),
    ),
  );
}

Future<void> _openOverdueProject(
  ProviderContainer container,
  GoRouter router,
  String projectId,
) async {
  try {
    final project = await container
        .read(projectRepositoryProvider)
        .watchProject(projectId)
        .firstWhere((project) => project != null)
        .timeout(const Duration(seconds: 4));
    router.go('/clients/${Uri.encodeComponent(project!.clientId)}');
  } catch (_) {
    router.go('/finance/pending');
  }
}
