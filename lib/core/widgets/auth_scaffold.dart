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
  const AuthScaffold({
    super.key,
    required this.headerIcon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.topLeft,
  });

  @override
  Widget build(BuildContext context) {
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
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
                            child: ColoredBox(
                              color: AppColors.forest,
                              child: Icon(headerIcon,
                                  color: AppColors.lime, size: 32),
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
                                  color: Colors.white.withValues(alpha: 0.78))),
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
          ],
        ),
      ),
    );
  }
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
