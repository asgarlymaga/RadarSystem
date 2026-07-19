import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'geo_targets.dart';

/// Plots landmarks around "you" (center) by their bearing (angle) and distance
/// (radius). Optionally rotated by [headingDeg] so the top of the radar points
/// where the device is facing (used by the compass screen); pass 0 for a
/// classic north-up map.
class GeoRadarPainter extends CustomPainter {
  final List<GeoReading> readings;
  final double headingDeg;

  GeoRadarPainter({required this.readings, this.headingDeg = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 14;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.textMuted.withValues(alpha: 0.3);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, ring);
    }

    // Cardinal markers (N rotates opposite to the heading).
    const cardinals = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};
    cardinals.forEach((deg, label) {
      final a = _screenAngle(deg.toDouble());
      final pos = center + Offset(math.cos(a), math.sin(a)) * (radius + 2);
      _text(canvas, label, pos,
          color: label == 'N' ? AppColors.emfRed : AppColors.textMuted, size: 12);
    });

    // Normalize distances so the farthest landmark sits near the edge.
    final maxKm = readings.fold<double>(
        1, (m, r) => math.max(m, r.distanceKm));
    for (final r in readings) {
      // sqrt scale spreads out the near landmarks a bit.
      final norm = math.sqrt(r.distanceKm / maxKm).clamp(0.12, 1.0);
      final a = _screenAngle(r.bearingDeg);
      final pos = center + Offset(math.cos(a), math.sin(a)) * (radius * norm);

      final glow = Paint()
        ..color = r.target.color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(pos, 7, glow);
      canvas.drawCircle(pos, 4, Paint()..color = r.target.color);
    }

    // "You" at the center.
    canvas.drawCircle(center, 5, Paint()..color = AppColors.textPrimary);
    canvas.drawCircle(
        center,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.textPrimary.withValues(alpha: 0.6));
  }

  /// Convert a geographic bearing (0=N, clockwise) into a canvas angle, with
  /// north at the top and the whole view rotated by [-headingDeg].
  double _screenAngle(double bearing) {
    final rot = (bearing - headingDeg) * math.pi / 180.0;
    return rot - math.pi / 2; // 0 deg -> pointing up
  }

  void _text(Canvas canvas, String s, Offset pos,
      {required Color color, double size = 12}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GeoRadarPainter old) =>
      old.readings != readings || old.headingDeg != headingDeg;
}
