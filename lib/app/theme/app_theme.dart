import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// WorkLog visual identity: cool blue surfaces, glass card treatment,
/// navy primary actions, sky-blue highlights, Inter typography, and
/// soft rounded controls.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(_lightScheme, Brightness.light);

  /// Structured so Dark Mode is a drop-in later (Profile > Theme).
  static ThemeData dark() => _base(_darkScheme, Brightness.dark);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.forest,
    onPrimary: AppColors.ivory,
    primaryContainer: AppColors.mint,
    onPrimaryContainer: AppColors.forest,
    secondary: AppColors.lime,
    onSecondary: AppColors.charcoal,
    secondaryContainer: AppColors.limeSoft,
    onSecondaryContainer: AppColors.charcoal,
    tertiary: AppColors.forestLight,
    onTertiary: AppColors.ivory,
    error: AppColors.overdue,
    onError: Colors.white,
    errorContainer: Color(0xFFFADAD6),
    onErrorContainer: Color(0xFF7A1410),
    surface: AppColors.ivory,
    onSurface: AppColors.charcoal,
    onSurfaceVariant: AppColors.mutedText,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: AppColors.ivory,
    surfaceContainer: Color(0xFFE8F1F9),
    surfaceContainerHigh: Color(0xFFE2EDF7),
    surfaceContainerHighest: AppColors.inputFill,
    outline: Color(0xFF8297AB),
    outlineVariant: AppColors.border,
    shadow: Colors.black,
    inverseSurface: AppColors.charcoal,
    onInverseSurface: AppColors.ivory,
    inversePrimary: AppColors.lime,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.lime,
    onPrimary: AppColors.forest,
    primaryContainer: Color(0xFF203D5B),
    onPrimaryContainer: AppColors.mint,
    secondary: AppColors.lime,
    onSecondary: AppColors.charcoal,
    secondaryContainer: Color(0xFF233B52),
    onSecondaryContainer: AppColors.limeSoft,
    error: Color(0xFFFF8A80),
    onError: Color(0xFF3B0A08),
    surface: AppColors.darkSurface,
    onSurface: AppColors.ivory,
    onSurfaceVariant: Color(0xFFB6C6D7),
    surfaceContainerHigh: Color(0xFF20364B),
    surfaceContainerHighest: Color(0xFF263E55),
    outline: Color(0xFF8196AA),
    outlineVariant: Color(0xFF394F66),
  );

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final inter = GoogleFonts.interTextTheme();

    // Page headings 24–28 bold, section titles 16–18 semibold, body 14,
    // small labels 12–13.
    final textTheme = inter
        .copyWith(
          headlineLarge: inter.headlineLarge
              ?.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
          headlineMedium: inter.headlineMedium
              ?.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
          headlineSmall: inter.headlineSmall
              ?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
          titleLarge: inter.titleLarge
              ?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
          titleMedium: inter.titleMedium
              ?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
          titleSmall: inter.titleSmall
              ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
          bodyLarge: inter.bodyLarge?.copyWith(fontSize: 15),
          bodyMedium: inter.bodyMedium?.copyWith(fontSize: 14),
          bodySmall: inter.bodySmall?.copyWith(fontSize: 12.5),
          labelLarge: inter.labelLarge
              ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: inter.labelMedium
              ?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          labelSmall: inter.labelSmall
              ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final pill = const StadiumBorder();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isLight ? AppColors.beige : AppColors.darkBackground,
      textTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 72,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: isLight ? 2.5 : 0,
        color: scheme.surface.withValues(alpha: isLight ? 0.78 : 0.86),
        shadowColor: scheme.shadow.withValues(alpha: isLight ? 0.08 : 0),
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(
              color: scheme.outlineVariant
                  .withValues(alpha: isLight ? 0.72 : 0.8)),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
          color: scheme.outlineVariant.withValues(alpha: 0.6), space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? Colors.white.withValues(alpha: .78)
            : scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: .9), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle:
            TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle:
            TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .85)),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          elevation: const WidgetStatePropertyAll(10),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side:
                BorderSide(color: scheme.outlineVariant.withValues(alpha: .85)),
          )),
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      // Primary actions: full-width-friendly pills, forest fill, bold label.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 58),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
          shape: pill,
          textStyle: textTheme.labelLarge
              ?.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      // Secondary actions: mint surface with forest text.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.mint,
          foregroundColor: AppColors.forest,
          minimumSize: const Size(64, 50),
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: pill,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        highlightElevation: 8,
        shape: const StadiumBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.mint,
        selectedColor: AppColors.lime,
        labelStyle: textTheme.labelMedium,
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.lime,
          selectedForegroundColor: AppColors.charcoal,
          backgroundColor: AppColors.mint,
          foregroundColor: AppColors.forest,
          side: BorderSide.none,
          shape: const StadiumBorder(),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.lime : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.forest
                : scheme.outlineVariant),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        showCloseIcon: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: _FadeThroughTransitionsBuilder(),
          TargetPlatform.windows: _FadeThroughTransitionsBuilder(),
          TargetPlatform.linux: _FadeThroughTransitionsBuilder(),
          TargetPlatform.fuchsia: _FadeThroughTransitionsBuilder(),
        },
      ),
    );
  }
}

class _FadeThroughTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeInOut,
      ),
      child: child,
    );
  }
}
