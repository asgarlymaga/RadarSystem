import 'package:flutter/material.dart';

import 'geo_math.dart';

/// A landmark/reference the dashboard measures distance and bearing to.
class GeoTarget {
  final String name;
  final IconData icon;
  final Color color;

  const GeoTarget(this.name, this.icon, this.color);
}

/// A computed distance + bearing from the user's position to a target.
class GeoReading {
  final GeoTarget target;
  final double distanceKm;
  final double bearingDeg; // 0 = geographic north, clockwise

  const GeoReading(this.target, this.distanceKm, this.bearingDeg);
}

/// Fixed geographic landmarks.
class GeoTargets {
  GeoTargets._();

  // Kaaba, Masjid al-Haram, Mecca.
  static const double kaabaLat = 21.4224779;
  static const double kaabaLon = 39.8251832;

  // Great Pyramid of Giza, Egypt.
  static const double gizaLat = 29.9791800;
  static const double gizaLon = 31.1342000;

  static const kaaba = GeoTarget('Kaaba (Mecca)', Icons.mosque, Color(0xFFE9C46A));
  static const pyramids =
      GeoTarget('Pyramids of Giza', Icons.change_history, Color(0xFFE8A33D));
  static const equator = GeoTarget('Equator', Icons.horizontal_rule, Color(0xFF2AC3A2));
  static const northPole = GeoTarget('North Pole', Icons.ac_unit, Color(0xFF7FB8FF));
  static const southPole = GeoTarget('South Pole', Icons.ac_unit, Color(0xFFB79CFF));

  /// Compute all readings for the given position.
  static List<GeoReading> readingsFor(double lat, double lon) {
    return [
      GeoReading(
        kaaba,
        haversineKm(lat, lon, kaabaLat, kaabaLon),
        bearingDeg(lat, lon, kaabaLat, kaabaLon),
      ),
      GeoReading(
        pyramids,
        haversineKm(lat, lon, gizaLat, gizaLon),
        bearingDeg(lat, lon, gizaLat, gizaLon),
      ),
      GeoReading(
        equator,
        distanceToEquatorKm(lat),
        lat >= 0 ? 180 : 0, // equator is due south if you're north, else due north
      ),
      GeoReading(
        northPole,
        distanceToNorthPoleKm(lat),
        0, // due north
      ),
      GeoReading(
        southPole,
        distanceToSouthPoleKm(lat),
        180, // due south
      ),
    ];
  }
}
