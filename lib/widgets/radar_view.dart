import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/radar_blip.dart';
import 'radar_grid_painter.dart';
import 'radar_sweep_painter.dart';

/// A self-contained animated radar disc: static grid + rotating sweep + blips,
/// with tap detection that maps a screen tap back to the nearest blip.
class RadarView extends StatefulWidget {
  final List<RadarBlip> blips;
  final Color color;

  /// Seconds for one full 360 degree sweep.
  final double sweepSeconds;
  final ValueChanged<RadarBlip>? onBlipTap;

  const RadarView({
    super.key,
    required this.blips,
    required this.color,
    this.sweepSeconds = 4,
    this.onBlipTap,
  });

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.sweepSeconds * 1000).round()),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose(); // stop the ticker to avoid leaks
    super.dispose();
  }

  /// Find the blip closest to a local tap within a small hit radius.
  void _handleTap(TapUpDetails details, Size size) {
    if (widget.onBlipTap == null || widget.blips.isEmpty) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    RadarBlip? best;
    double bestDist = 28; // px hit tolerance
    for (final blip in widget.blips) {
      final p = blip.toOffset(radius);
      final pos = center + Offset(p.x, p.y);
      final d = (pos - details.localPosition).distance;
      if (d < bestDist) {
        bestDist = d;
        best = blip;
      }
    }
    if (best != null) widget.onBlipTap!(best);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onTapUp: (d) => _handleTap(d, size),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final angle = _controller.value * 2 * math.pi;
                return CustomPaint(
                  painter: RadarGridPainter(color: widget.color),
                  foregroundPainter: RadarSweepPainter(
                    sweepAngle: angle,
                    blips: widget.blips,
                    color: widget.color,
                  ),
                  size: size,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
