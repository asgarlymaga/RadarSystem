import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Draws the static "hardware" of a radar: concentric range rings, cross-hairs
/// and faint radial spokes. Shared by all three modes; only the [color] changes.
class RadarGridPainter extends CustomPainter {
  final Color color;
  final int ringCount;

  const RadarGridPainter({required this.color, this.ringCount = 4});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.25);

    // Background glow so the disc reads as a lit screen.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.10), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);

    // Concentric range rings.
    for (int i = 1; i <= ringCount; i++) {
      canvas.drawCircle(center, radius * i / ringCount, ringPaint);
    }

    // Cross-hairs.
    canvas.drawLine(
        Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), ringPaint);
    canvas.drawLine(
        Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), ringPaint);

    // Radial spokes every 30 degrees.
    final spoke = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (int deg = 0; deg < 360; deg += 30) {
      final a = deg * math.pi / 180;
      canvas.drawLine(
        center,
        center + Offset(radius * math.cos(a), radius * math.sin(a)),
        spoke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadarGridPainter old) =>
      old.color != color || old.ringCount != ringCount;
}
