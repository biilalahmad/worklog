import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Shared shell for auth screens: a simple contextual icon, title,
/// subtitle, and the screen's content without repeating the app branding.
class AuthScaffold extends StatelessWidget {
  final IconData headerIcon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? topLeft;
  final bool compactHeader;
  final String? greeting;
  final String? greetingSubtitle;
  const AuthScaffold({
    super.key,
    required this.headerIcon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.topLeft,
    this.compactHeader = false,
    this.greeting,
    this.greetingSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (compactHeader) return _buildCompact(context);
    return _buildClassic(context);
  }

  Widget _buildCompact(BuildContext context) {
    final baseTheme = Theme.of(context);
    final scheme = baseTheme.colorScheme;
    final isDark = baseTheme.brightness == Brightness.dark;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    );
    final formTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Poppins'),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E3148) : Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        prefixIconColor:
            isDark ? const Color(0xFFA8B8CC) : const Color(0xFF8297AB),
        hintStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: isDark ? const Color(0xFF9AACC0) : const Color(0xFF7589A1),
        ),
        labelStyle: baseTheme.textTheme.bodySmall?.copyWith(fontSize: 12),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(
              color: isDark ? AppColors.lime : AppColors.forest, width: 1.4),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.lime : AppColors.forest,
          foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
          minimumSize: const Size(64, AppSpacing.authButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.lime : AppColors.forest,
          textStyle: const TextStyle(fontFamily: 'Poppins'),
        ),
      ),
    );

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF172539) : const Color(0xFFE9F1F9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final tallHeader = greeting != null;
            final headerHeight = tallHeader
                ? (viewport.maxHeight - (keyboardOpen ? 500 : 460))
                    .clamp(keyboardOpen ? 88.0 : 120.0,
                        keyboardOpen ? 132.0 : 240.0)
                    .toDouble()
                : (viewport.maxHeight * 0.16).clamp(92.0, 132.0).toDouble();

            return Column(
              children: [
                SizedBox(
                  height: headerHeight,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.forest, AppColors.forestLight],
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          top: -28,
                          left: -28,
                          child: CustomPaint(
                            size: const Size(150, 135),
                            painter: _AuthLeafPainter(
                              AppColors.lime.withValues(alpha: 0.42),
                            ),
                          ),
                        ),
                        const Positioned(
                          right: -50,
                          top: -70,
                          child: _AuthGlow(size: 170),
                        ),
                        if (topLeft != null)
                          Positioned(top: 4, left: 4, child: topLeft!),
                        Positioned(
                          left: AppSpacing.authInner,
                          right: AppSpacing.authInner,
                          bottom: tallHeader ? 18 : 14,
                          child: tallHeader
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      greeting!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 32,
                                        height: 1.1,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (greetingSubtitle != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        greetingSubtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 24,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF172539)
                          : const Color(0xFFE9F1F9),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(36)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: LayoutBuilder(
                        builder: (context, bodyConstraints) =>
                            SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.authInner,
                            16,
                            AppSpacing.authInner,
                            16,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  math.max(0, bodyConstraints.maxHeight - 32),
                              maxWidth: 480,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (tallHeader) ...[
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 24,
                                      height: 1.25,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                Theme(data: formTheme, child: child),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildClassic(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 290,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.forest,
                      AppColors.forestLight.withValues(alpha: 0.92)
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(38)),
                ),
              ),
            ),
            if (topLeft != null) Positioned(top: 4, left: 4, child: topLeft!),
            Align(
              alignment: Alignment.topCenter,
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 480,
                      minHeight: viewport.maxHeight - 44,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 70,
                            height: 70,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                'assets/images/worklog_icon.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: Colors.white)),
                        const SizedBox(height: 5),
                        Text(subtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.78))),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.55)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.forest.withValues(alpha: 0.12),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthLeafPainter extends CustomPainter {
  const _AuthLeafPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final leaf = Path()
      ..moveTo(0, size.height * .12)
      ..cubicTo(size.width * .55, -size.height * .08, size.width * .98,
          size.height * .30, size.width * .82, size.height * .78)
      ..cubicTo(size.width * .45, size.height * .98, 0, size.height * .62, 0,
          size.height * .12)
      ..close();
    canvas.drawPath(leaf, Paint()..color = color);

    final vein = Path()
      ..moveTo(size.width * .10, size.height * .16)
      ..quadraticBezierTo(size.width * .45, size.height * .28, size.width * .70,
          size.height * .72);
    canvas.drawPath(
      vein,
      Paint()
        ..color = Colors.white.withValues(alpha: .25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AuthLeafPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _AuthGlow extends StatelessWidget {
  const _AuthGlow({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.07),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
      );
}

/// Inline error / info banner used across auth screens.
class AuthBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final Widget? trailing;

  const AuthBanner(
      {super.key, required this.message, this.isError = true, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isError ? scheme.errorContainer : AppColors.mint;
    final fg = isError ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: Text(message, style: TextStyle(color: fg))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Full-width provider button used on the auth forms.
class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(64, 44),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 20, height: 20, child: icon),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Continue with Google',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin-line "or sign up with" divider row.
class OrDivider extends StatelessWidget {
  final String label;
  const OrDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13)),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}
