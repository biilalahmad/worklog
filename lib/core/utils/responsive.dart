import 'package:flutter/widgets.dart';

/// Central breakpoints so every screen agrees on what counts as
/// "mobile", "tablet" and "desktop" instead of each screen picking its
/// own magic number.
class Breakpoints {
  Breakpoints._();

  static const compact = 600.0; // phones
  static const medium = 905.0; // small tablets / split-screen
  static const expanded = 1240.0; // desktop
}

extension ResponsiveContext on BuildContext {
  double get _width => MediaQuery.sizeOf(this).width;

  bool get isCompact => _width < Breakpoints.compact;
  bool get isMedium => _width >= Breakpoints.compact && _width < Breakpoints.expanded;
  bool get isExpanded => _width >= Breakpoints.expanded;

  /// True once there's enough width for a side rail instead of a
  /// bottom bar (tablets in landscape and up).
  bool get useSideNavigation => _width >= Breakpoints.compact;
}
