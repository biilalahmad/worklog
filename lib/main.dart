import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'app/theme/theme_mode_provider.dart';
import 'core/config/supabase_config.dart';
import 'features/onboarding/presentation/providers/first_launch_provider.dart';
import 'features/reminders/presentation/providers/notification_provider.dart';
import 'services/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      // A specific reminder can't be safely deep-linked to without
      // first loading it (and the app may be cold-starting right
      // now) — opening the reminders list is the robust fallback the
      // spec calls for when the exact reminder can't be resolved.
      router.go('/reminders');
    };
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WorkLogApp(),
    ),
  );
}
