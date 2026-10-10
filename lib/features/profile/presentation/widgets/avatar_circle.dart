import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';

/// Consistent avatar treatment used on Profile, Clients, and anywhere
/// else a person needs a circular avatar: photo if set, otherwise
/// initials on a colored circle.
class AvatarCircle extends StatelessWidget {
  static const _fallbackPalettes = [
    [AppColors.mint, AppColors.limeSoft],
    [AppColors.limeSoft, AppColors.beige],
    [AppColors.beige, AppColors.mint],
    [AppColors.ivory, AppColors.limeSoft],
    [AppColors.mint, AppColors.ivory],
  ];

  final String? imageUrl;
  final String initials;
  final double size;
  final Color? background;
  final String? seed;

  const AvatarCircle({
    super.key,
    this.imageUrl,
    required this.initials,
    this.size = 56,
    this.background,
    this.seed,
  });

  static String? firstNameFromEmail(String? email) {
    final localPart = email?.split('@').first.trim();
    if (localPart == null || localPart.isEmpty) return null;
    final tokens = localPart
        .split(RegExp(r'[._+\-\s]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;
    final token = tokens.first;
    return '${token[0].toUpperCase()}${token.substring(1)}';
  }

  static String? initialsFromEmail(String? email) {
    final name = firstNameFromEmail(email);
    return name == null ? null : name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imageUrl != null && imageUrl!.isNotEmpty;
    final seedValue = seed ?? initials;
    final colorIndex = seedValue.runes.fold<int>(0, (sum, rune) => sum + rune) %
        _fallbackPalettes.length;
    final palette = _fallbackPalettes[colorIndex];

    Widget frame(Widget child) => SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.82),
                  width: size * 0.035),
              boxShadow: [
                BoxShadow(
                    color: AppColors.forest.withValues(alpha: 0.12),
                    blurRadius: size * 0.16,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(size * 0.035),
              // Material's CircleBorder remains a true circle even when an
              // AppBar ancestor supplies asymmetric constraints.
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        );

    Widget fallback() => frame(
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: background,
              gradient: background == null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: palette)
                  : null,
            ),
            child: Center(
              child: Text(
                initials,
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.37,
                  letterSpacing: -size * 0.02,
                ),
              ),
            ),
          ),
        );

    if (!hasPhoto) return fallback();

    return frame(
      Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            gradient: background == null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: palette,
                  )
                : null,
          ),
          child: Center(
            child: Text(
              initials,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.forest,
                fontWeight: FontWeight.w900,
                fontSize: size * .37,
                letterSpacing: -size * .02,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
