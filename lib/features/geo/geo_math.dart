import 'dart:math' as math;

/// Mean Earth radius in kilometers (used for great-circle math).
const double kEarthRadiusKm = 6371.0088;

double _rad(double deg) => deg * math.pi / 180.0;
double _deg(double rad) => rad * 180.0 / math.pi;

/// Great-circle (Haversine) distance in km between two lat/lon points.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return kEarthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Initial great-circle bearing in degrees (0 = geographic north, clockwise).
double bearingDeg(double lat1, double lon1, double lat2, double lon2) {
  final dLon = _rad(lon2 - lon1);
  final y = math.sin(dLon) * math.cos(_rad(lat2));
  final x = math.cos(_rad(lat1)) * math.sin(_rad(lat2)) -
      math.sin(_rad(lat1)) * math.cos(_rad(lat2)) * math.cos(dLon);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Distance in km from a latitude to the Equator (straight along the meridian).
double distanceToEquatorKm(double lat) => _rad(lat.abs()) * kEarthRadiusKm;

/// Distance in km to the North Pole along the meridian.
double distanceToNorthPoleKm(double lat) => _rad(90 - lat) * kEarthRadiusKm;

/// Distance in km to the South Pole along the meridian.
double distanceToSouthPoleKm(double lat) => _rad(90 + lat) * kEarthRadiusKm;

/// Human-friendly km formatting.
String formatKm(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  if (km < 100) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}
