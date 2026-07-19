import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/radar_blip.dart';

/// Paints the rotating sweep arm plus the currently detected [blips].
///
/// The sweep is a fading conic gradient trailing behind a leading edge at
/// [sweepAngle] (radians). Blips glow brighter when the sweep passes over them.
class RadarSweepPainter extends CustomPainter {
  final double sweepAngle;
  final List<RadarBlip> blips;
  final Color color;

  RadarSweepPainter({
    required this.sweepAngle,
    required this.blips,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // --- Sweep arm with trailing gradient -------------------------------
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        transform: GradientRotation(sweepAngle - math.pi / 2),
        colors: [
          color.withValues(alpha: 0.45),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sweepPaint);

    // Bright leading line.
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawLine(
      center,
      center + Offset(radius * math.cos(sweepAngle), radius * math.sin(sweepAngle)),
      line,
    );

    // --- Blips -----------------------------------------------------------
    for (final blip in blips) {
      final p = blip.toOffset(radius);
      final pos = center + Offset(p.x, p.y);

      // Angular distance between the blip and the sweep -> fade the blip in
      // just after the sweep passes it, then let it decay.
      double delta = (sweepAngle - blip.angle) % (2 * math.pi);
      if (delta < 0) delta += 2 * math.pi;
      final freshness = (1.0 - delta / (2 * math.pi)).clamp(0.0, 1.0);
      final alpha = 0.25 + 0.75 * freshness;

      final glow = Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * freshness + 2);
      canvas.drawCircle(pos, 6 + 4 * freshness, glow);

      final dot = Paint()..color = color.withValues(alpha: alpha);
      canvas.drawCircle(pos, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant RadarSweepPainter old) =>
      old.sweepAngle != sweepAngle || old.blips != blips || old.color != color;
}
