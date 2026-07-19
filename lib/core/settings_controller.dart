import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide, persisted user settings. Provided once at the app root so every
/// mode reads the same live values.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    _bleRangeMeters = _prefs.getDouble(_kBleRange) ?? _defaultBleRange;
    _emfBaseline = _prefs.getDouble(_kEmfBaseline) ?? _defaultEmfBaseline;
    _closestAlertEnabled = _prefs.getBool(_kClosestAlert) ?? true;
  }

  static const _kBleRange = 'ble_range_meters';
  static const _kEmfBaseline = 'emf_baseline_ut';
  static const _kClosestAlert = 'closest_alert_enabled';

  static const double _defaultBleRange = 15;
  static const double _defaultEmfBaseline = 50;

  // Allowed UI ranges (also used by the sliders).
  static const double minBleRange = 5;
  static const double maxBleRange = 30;
  static const double minEmfBaseline = 20;
  static const double maxEmfBaseline = 90;

  final SharedPreferences _prefs;

  late double _bleRangeMeters;
  late double _emfBaseline;
  late bool _closestAlertEnabled;

  /// Outer radar radius in meters for the BLE mode.
  double get bleRangeMeters => _bleRangeMeters;

  /// Ambient magnetic field baseline in µT; anomalies are measured against it.
  double get emfBaseline => _emfBaseline;

  /// When true, a haptic fires whenever the nearest BLE device changes.
  bool get closestAlertEnabled => _closestAlertEnabled;

  void setBleRange(double meters) {
    _bleRangeMeters = meters.clamp(minBleRange, maxBleRange);
    _prefs.setDouble(_kBleRange, _bleRangeMeters);
    notifyListeners();
  }

  void setEmfBaseline(double ut) {
    _emfBaseline = ut.clamp(minEmfBaseline, maxEmfBaseline);
    _prefs.setDouble(_kEmfBaseline, _emfBaseline);
    notifyListeners();
  }

  void setClosestAlert(bool enabled) {
    _closestAlertEnabled = enabled;
    _prefs.setBool(_kClosestAlert, enabled);
    notifyListeners();
  }

  void resetDefaults() {
    setBleRange(_defaultBleRange);
    setEmfBaseline(_defaultEmfBaseline);
    setClosestAlert(true);
  }
}
