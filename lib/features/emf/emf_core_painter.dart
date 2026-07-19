import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A glowing central core that pulses with the magnetic field. [pulse] is a
/// 0..1 animation phase, [intensity] is the field strength 0..1.
class EmfCorePainter extends CustomPainter {
  final double pulse;
  final double intensity;

  EmfCorePainter({required this.pulse, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;

    // Color shifts from calm blue-ish red to hot red as intensity rises.
    final coreColor = Color.lerp(
      const Color(0xFF6B2230),
      AppColors.emfRed,
      intensity,
    )!;

    // Outward ripple rings driven by the pulse phase, faster when intense.
    const rippleCount = 3;
    for (int i = 0; i < rippleCount; i++) {
      final phase = (pulse + i / rippleCount) % 1.0;
      final r = maxR * phase;
      final alpha = (1.0 - phase) * (0.15 + 0.5 * intensity);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = coreColor.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(center, r, ring);
    }

    // The core itself breathes with the pulse and swells with intensity.
    final breathe = 0.9 + 0.1 * math.sin(pulse * 2 * math.pi);
    final coreR = maxR * (0.12 + 0.28 * intensity) * breathe;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          coreColor.withValues(alpha: 0.9),
          coreColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: coreR * 2.4));
    canvas.drawCircle(center, coreR * 2.4, glow);

    final core = Paint()..color = coreColor;
    canvas.drawCircle(center, coreR, core);
  }

  @override
  bool shouldRepaint(covariant EmfCorePainter old) =>
      old.pulse != pulse || old.intensity != intensity;
}
