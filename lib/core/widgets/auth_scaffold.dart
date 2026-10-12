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
  const AuthScaffold({
    super.key,
    required this.headerIcon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.topLeft,
    this.compactHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compactHeader) return _buildCompact(context);
    return _buildClassic(context);
  }

  Widget _buildCompact(BuildContext context) {
    final baseTheme = Theme.of(context);
    final scheme = baseTheme.colorScheme;
    final formTheme = baseTheme.copyWith(
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        labelStyle: baseTheme.textTheme.bodySmall?.copyWith(fontSize: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.authButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: baseTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final headerHeight =
                (viewport.maxHeight * 0.175).clamp(112.0, 136.0).toDouble();
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: headerHeight,
                  child: const ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.forest,
                                  AppColors.forestLight,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -34,
                          top: -64,
                          child: _AuthGlow(size: 164),
                        ),
                        Positioned(
                          left: -38,
                          bottom: -92,
                          child: _AuthGlow(size: 142),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  children: [
                    SizedBox(
                      height: headerHeight,
                      child: Stack(
                        children: [
                          if (topLeft != null)
                            Positioned(top: 4, left: 4, child: topLeft!),
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 56),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/worklog_icon.png',
                                    width: 20,
                                    height: 20,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    title,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: baseTheme.textTheme.headlineSmall
                                        ?.copyWith(
                                      fontSize: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (subtitle.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: baseTheme.textTheme.bodySmall
                                          ?.copyWith(
                                        fontSize: 11,
                                        color: Colors.white
                                            .withValues(alpha: 0.84),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, bodyConstraints) =>
                            SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.authOuter),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: bodyConstraints.maxHeight,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: math.max(
                                    0,
                                    math.min(
                                      480,
                                      bodyConstraints.maxWidth -
                                          2 * AppSpacing.authOuter,
                                    ),
                                  ),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.authInner,
                                    8,
                                    AppSpacing.authInner,
                                    8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surface,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: scheme.outlineVariant
                                          .withValues(alpha: 0.55),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.forest
                                            .withValues(alpha: 0.12),
                                        blurRadius: 26,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: Theme(data: formTheme, child: child),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
