import 'package:flutter/material.dart';

/// Single source of truth for WorkLog's design tokens. Screens should
/// read colors from `Theme.of(context).colorScheme` where possible and
/// use these constants for anything the ColorScheme can't express
/// (status colors, blue highlight, spacing, radii). Nothing here is
/// hardcoded per-screen, so Dark Mode / rebranding only touches this
/// file and `app_theme.dart`.
class AppColors {
  AppColors._();

  static const beige = Color(0xFFEAF2F9); // cool blue app background
  static const ivory = Color(0xFFF8FBFE); // cool glass surfaces
  static const forest = Color(0xFF183B62); // deep navy primary
  static const forestLight = Color(0xFF3B6C9D); // gradient end
  static const lime = Color(0xFF63B3ED); // sky-blue active accent
  static const limeSoft = Color(0xFFDCEEFF); // selected glass pill
  static const mint = Color(0xFFE4F0FA); // pale blue secondary surfaces
  static const charcoal = Color(0xFF182A3D); // text
  static const mutedText = Color(0xFF60758B); // supporting text
  static const border = Color(0xFFC9D9E8); // blue-grey edge
  static const inputFill = Color(0xFFEAF2F8); // text field fill
  static const navBar = Color(0xD9F8FBFE); // translucent frosted navigation

  // Semantic status colors remain distinct from the blue accent.
  static const paid = Color(0xFF2E7D32);
  static const pending = Color(0xFFE59A0B);
  static const overdue = Color(0xFFD32F2F);

  // Dark-mode-ready counterparts (used once dark mode is switched on).
  static const darkBackground = Color(0xFF101C2B);
  static const darkSurface = Color(0xFF1A2B3D);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  static const double cardRadius = 26;
  static const double fieldRadius = 18;
  static const double pageGutter = 16;

  /// Extra bottom padding so scrollable content clears the floating nav.
  static const double navClearance = 112;
}
