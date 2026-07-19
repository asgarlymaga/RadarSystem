import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../geo/geo_targets.dart';
import '../geo/location_controller.dart';
import 'compass_controller.dart';
import 'compass_rose_painter.dart';

/// Mode: Compass. Tilt-compensated heading with landmark bearing needles.
class CompassScreen extends StatelessWidget {
  const CompassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CompassController()..start(),
      child: const _CompassBody(),
    );
  }
}

class _CompassBody extends StatelessWidget {
  const _CompassBody();

  @override
  Widget build(BuildContext context) {
    final compass = context.watch<CompassController>();
    // Shared location (from the app root) supplies bearings to the landmarks.
    final loc = context.watch<LocationController>();
    final readings =
        loc.status == LocationStatus.ready ? loc.readings : const <GeoReading>[];

    return Scaffold(
      appBar: AppBar(title: const Text('COMPASS')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text('${compass.heading.toStringAsFixed(0)}°  ${compass.cardinal}',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: CustomPaint(
                      painter: CompassRosePainter(
                        headingDeg: compass.heading,
                        readings: readings,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (readings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Enable location on the home screen to show bearings to the '
                  'Kaaba, Pyramids and Poles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              )
            else
              _Legend(readings: readings, heading: compass.heading),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Lists each landmark with its bearing and the turn (relative direction) from
/// the current heading.
class _Legend extends StatelessWidget {
  final List<GeoReading> readings;
  final double heading;

  const _Legend({required this.readings, required this.heading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: readings.map((r) {
          // Relative angle to rotate a small arrow toward the target.
          final rel = ((r.bearingDeg - heading) + 360) % 360;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Transform.rotate(
                  angle: rel * 3.1415926535 / 180,
                  child: Icon(Icons.navigation, color: r.target.color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(r.target.name,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                ),
                Text('${r.bearingDeg.toStringAsFixed(0)}°',
                    style: TextStyle(color: r.target.color, fontSize: 13)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
