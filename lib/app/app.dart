import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/supabase_config.dart';
import '../core/widgets/setup_required_screen.dart';
import '../core/widgets/offline_startup_notice.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_provider.dart';

final _appScrollBehavior =
    const MaterialScrollBehavior().copyWith(overscroll: false);

class WorkLogApp extends ConsumerWidget {
  const WorkLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!SupabaseConfig.isConfigured) {
      return MaterialApp(
        title: 'WorkLog',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        scrollBehavior: _appScrollBehavior,
        home: const SetupRequiredScreen(),
      );
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'WorkLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: const Duration(milliseconds: 360),
      themeAnimationCurve: Curves.easeInOutCubic,
      scrollBehavior: _appScrollBehavior,
      routerConfig: router,
      builder: (context, child) => OfflineStartupNotice(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
