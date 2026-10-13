import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Circular gauge showing the backend's compliance score (0-100).
/// The colour is only a visual hint; the number comes from the backend.
class ScoreGauge extends StatelessWidget {
  const ScoreGauge({super.key, required this.score, this.size = 150});

  final int? score;
  final double size;

  Color get _color {
    final s = score;
    if (s == null) return AppColors.neutral;
    if (s >= 75) return AppColors.low;
    if (s >= 50) return AppColors.medium;
    return AppColors.critical;
  }

  @override
  Widget build(BuildContext context) {
    final fraction = ((score ?? 0).clamp(0, 100)) / 100.0;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _GaugePainter(value, _color),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  score == null ? '--' : '$score',
                  style: TextStyle(
                      fontSize: size * 0.30,
                      fontWeight: FontWeight.w800,
                      color: _color),
                ),
                Text(score == null ? 'no score' : 'out of 100',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.border;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (fraction > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = color;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, arc);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}
