import 'dart:math' as math;

/// A generic "blip" plotted on any of the radar screens.
///
/// [distance] is normalized in the range 0.0 (dead center) .. 1.0 (outer edge).
/// [angle] is in radians and decides where around the circle the blip sits.
class RadarBlip {
  final String id;
  final String label;
  final String subtitle;
  final double distance; // 0..1 normalized from center
  final double angle; // radians
  final int rssi; // raw signal strength (BLE); 0 if not applicable

  const RadarBlip({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.distance,
    required this.angle,
    this.rssi = 0,
  });

  /// Cartesian offset (dx, dy) for a radar of the given [radius].
  /// The center of the radar is assumed to be (0,0) by the caller.
  math.Point<double> toOffset(double radius) {
    final r = distance.clamp(0.0, 1.0) * radius;
    return math.Point<double>(r * math.cos(angle), r * math.sin(angle));
  }

  RadarBlip copyWith({double? distance, double? angle, int? rssi}) => RadarBlip(
        id: id,
        label: label,
        subtitle: subtitle,
        distance: distance ?? this.distance,
        angle: angle ?? this.angle,
        rssi: rssi ?? this.rssi,
      );
}
