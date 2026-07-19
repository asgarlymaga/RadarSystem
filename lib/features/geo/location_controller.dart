import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'geo_targets.dart';

enum LocationStatus { loading, ready, serviceDisabled, denied, deniedForever, error }

/// Loads the device's GPS position once and derives distances/bearings to the
/// fixed landmarks. Provided at the app root so it is ready when the app opens.
class LocationController extends ChangeNotifier {
  LocationStatus _status = LocationStatus.loading;
  Position? _position;
  List<GeoReading> _readings = const [];
  String? _error;

  LocationStatus get status => _status;
  Position? get position => _position;
  List<GeoReading> get readings => _readings;
  String? get error => _error;

  double? get latitude => _position?.latitude;
  double? get longitude => _position?.longitude;

  Future<void> load() async {
    _status = LocationStatus.loading;
    notifyListeners();

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _status = LocationStatus.serviceDisabled;
        notifyListeners();
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _status = LocationStatus.deniedForever;
        notifyListeners();
        return;
      }
      if (perm == LocationPermission.denied) {
        _status = LocationStatus.denied;
        notifyListeners();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _position = pos;
      _readings = GeoTargets.readingsFor(pos.latitude, pos.longitude);
      _status = LocationStatus.ready;
    } catch (e) {
      _error = 'Could not get your location. $e';
      _status = LocationStatus.error;
    }
    notifyListeners();
  }

  /// Open the OS location settings so the user can enable the service /
  /// grant permission, then callers can retry [load].
  Future<void> openSettings() => Geolocator.openLocationSettings();
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
