import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';

/// Centralised permission handling for the three radar modes.
///
/// Android splits Bluetooth permissions by SDK level:
///   * API <= 30  -> needs location (fine) to scan for BLE.
///   * API >= 31  -> needs bluetoothScan + bluetoothConnect (and location for
///                   scans that derive location, unless neverForLocation flag).
/// We request the superset and let the OS ignore what it does not need.
class PermissionService {
  const PermissionService();

  /// Bluetooth + location, required for [FlutterBluePlus] scanning.
  Future<bool> requestBlePermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // On iOS only bluetooth matters; on Android we accept if the granular
    // permissions OR the legacy location permission is granted.
    return statuses.values.any((s) => s.isGranted);
  }

  /// Wi-Fi LAN scanning needs location to read the SSID / gateway on Android.
  Future<bool> requestWifiPermissions() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// The magnetometer needs no runtime permission, but we keep the hook so the
  /// UI can call every mode the same way.
  Future<bool> requestEmfPermissions() async => true;
}
