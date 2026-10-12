import 'package:flutter/material.dart';

/// A circular white/light social auth button (Google, etc.) — matches
/// the reference sign-up screen's row of round provider icons.
class SocialIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String tooltip;

  const SocialIconButton(
      {super.key,
      required this.icon,
      required this.onPressed,
      required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 1,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 48, height: 48, child: Center(child: icon)),
        ),
      ),
    );
  }
}

/// "G" mark drawn with CustomPaint so no logo asset/network fetch is
/// needed for the Google button.
class GoogleMark extends StatelessWidget {
  final double size;
  const GoogleMark({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GoogleMarkPainter()));
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final stroke = size.width * 0.22;
    final rect = Rect.fromCircle(center: Offset(r, r), radius: r - stroke / 2);
    final colors = [
      const Color(0xFF4285F4), // blue (top-right)
      const Color(0xFF34A853), // green (bottom-right)
      const Color(0xFFFBBC05), // yellow (bottom-left)
      const Color(0xFFEA4335), // red (top-left)
    ];
    const sweep = 1.5708; // 90deg
    var start = -0.35;
    for (final c in colors) {
      final paint = Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep + 0.06, false, paint);
      start += sweep;
    }
    // Cross-bar of the "G"
    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
        Rect.fromLTWH(r, r - stroke * 0.28, r - stroke * 0.15, stroke * 0.56),
        barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
