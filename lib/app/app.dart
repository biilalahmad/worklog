import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/supabase_config.dart';
import '../core/widgets/setup_required_screen.dart';
import '../core/widgets/offline_startup_notice.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_provider.dart';

class WorkLogScrollBehavior extends MaterialScrollBehavior {
  const WorkLogScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

const _appScrollBehavior = WorkLogScrollBehavior();

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
        builder: _buildRoot,
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
      builder: (context, child) => _buildRoot(
        context,
        OfflineStartupNotice(child: child ?? const SizedBox.shrink()),
      ),
    );
  }

  Widget _buildRoot(BuildContext context, Widget? child) {
    final media = MediaQuery.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final style = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isLight ? Brightness.dark : Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: MediaQuery(
        data: media.copyWith(
          textScaler: media.textScaler.clamp(maxScaleFactor: 1.3),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
