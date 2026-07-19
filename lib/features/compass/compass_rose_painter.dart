import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../geo/geo_targets.dart';

/// A rotating compass rose. The dial rotates opposite the [headingDeg] so the
/// current heading stays under the fixed top pointer. Landmark [readings] are
/// drawn as colored bearing needles that also rotate with the dial.
class CompassRosePainter extends CustomPainter {
  final double headingDeg;
  final List<GeoReading> readings;

  CompassRosePainter({required this.headingDeg, this.readings = const []});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 16;

    // Outer ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.emfRed.withValues(alpha: 0.5),
    );

    // Fixed top pointer (points at whatever the device faces).
    final pointer = Path()
      ..moveTo(center.dx, center.dy - radius - 12)
      ..lineTo(center.dx - 9, center.dy - radius + 6)
      ..lineTo(center.dx + 9, center.dy - radius + 6)
      ..close();
    canvas.drawPath(pointer, Paint()..color = AppColors.emfRed);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-headingDeg * math.pi / 180); // rotate the dial

    // Tick marks every 15°, longer + labeled every 45°.
    for (int deg = 0; deg < 360; deg += 15) {
      final a = deg * math.pi / 180 - math.pi / 2;
      final major = deg % 45 == 0;
      final r1 = radius - (major ? 16 : 8);
      final p1 = Offset(math.cos(a) * r1, math.sin(a) * r1);
      final p2 = Offset(math.cos(a) * radius, math.sin(a) * radius);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = AppColors.textMuted.withValues(alpha: major ? 0.9 : 0.4)
          ..strokeWidth = major ? 2 : 1,
      );
    }

    // Cardinal letters.
    const cardinals = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};
    cardinals.forEach((deg, label) {
      final a = deg * math.pi / 180 - math.pi / 2;
      final pos = Offset(math.cos(a) * (radius - 34), math.sin(a) * (radius - 34));
      _text(canvas, label, pos,
          color: label == 'N' ? AppColors.emfRed : AppColors.textPrimary, size: 18);
    });

    // Landmark bearing needles.
    for (final r in readings) {
      final a = r.bearingDeg * math.pi / 180 - math.pi / 2;
      final tip = Offset(math.cos(a) * (radius - 44), math.sin(a) * (radius - 44));
      canvas.drawLine(
        Offset.zero,
        tip,
        Paint()
          ..color = r.target.color.withValues(alpha: 0.9)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(tip, 6, Paint()..color = r.target.color);
      _icon(canvas, r.target.icon, tip, r.target.color);
    }

    canvas.restore();
  }

  void _text(Canvas canvas, String s, Offset pos,
      {required Color color, double size = 14}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  void _icon(Canvas canvas, IconData icon, Offset pos, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 14,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2 - 14));
  }

  @override
  bool shouldRepaint(covariant CompassRosePainter old) =>
      old.headingDeg != headingDeg || old.readings != readings;
}
