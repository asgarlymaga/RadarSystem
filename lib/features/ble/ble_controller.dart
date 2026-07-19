import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/permission_service.dart';
import '../../core/settings_controller.dart';
import '../../models/radar_blip.dart';
import 'ble_classifier.dart';

/// Detected BLE device enriched with classification, a smoothed signal and an
/// estimated distance.
class BleDevice {
  final String id; // MAC / remoteId
  final String name;
  final int rssi; // latest raw RSSI
  final double smoothedRssi; // EMA-filtered RSSI for stable distance
  final int? txPower; // advertised TX power, if any
  final double angle; // stable radar angle for this device
  final int serviceCount;
  final BleClassification classification;
  final DateTime lastSeen;

  BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.smoothedRssi,
    required this.txPower,
    required this.angle,
    required this.serviceCount,
    required this.classification,
    required this.lastSeen,
  });

  String get displayName => name.isEmpty ? classification.typeLabel : name;
  String get manufacturer => classification.manufacturer;
  String get typeLabel => classification.typeLabel;

  /// Log-distance path-loss model on the *smoothed* RSSI:
  ///   distance = 10 ^ ((measuredPower - rssi) / (10 * n))
  /// measuredPower = reference RSSI at 1 m. We use the advertised TX power when
  /// it is present and plausible, otherwise a typical -59 dBm default.
  double get estimatedMeters {
    final measuredPower =
        (txPower != null && txPower! < 0 && txPower! > -100) ? txPower! : -59;
    const n = 2.5; // environmental path-loss exponent (2 = free space)
    final d = math.pow(10, (measuredPower - smoothedRssi) / (10 * n)).toDouble();
    return d.clamp(0.1, 30.0);
  }

  double normalizedDistance(double rangeMeters) =>
      (estimatedMeters / rangeMeters).clamp(0.05, 1.0);

  RadarBlip toBlip(double rangeMeters) => RadarBlip(
        id: id,
        label: displayName,
        subtitle: id,
        distance: normalizedDistance(rangeMeters),
        angle: angle,
        rssi: rssi,
      );
}

/// High-level BLE state the UI switches on.
enum BleState {
  starting, // requesting permissions / waiting for adapter
  scanning,
  bluetoothOff, // adapter is off/turning — offer to enable it
  unsupported, // no BLE hardware
  unauthorized, // permission denied
  error,
}

/// Owns the BLE scan lifecycle and exposes the current device set to the UI.
class BleController extends ChangeNotifier {
  BleController({required SettingsController settings, PermissionService? permissions})
      : _settings = settings,
        _permissions = permissions ?? const PermissionService();

  final PermissionService _permissions;
  final SettingsController _settings;

  final Map<String, BleDevice> _devices = {};
  final Map<String, double> _rssiEma = {}; // per-device smoothed RSSI

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  BleState _state = BleState.starting;
  String? _error;
  String? _closestId;

  BleState get state => _state;
  String? get error => _error;
  bool get scanning => _state == BleState.scanning;
  bool get isBluetoothOff => _state == BleState.bluetoothOff;

  List<BleDevice> get devices {
    final list = _devices.values.toList()
      ..sort((a, b) => b.smoothedRssi.compareTo(a.smoothedRssi));
    return list;
  }

  /// Nearest device = strongest (smoothed) RSSI. Null when nothing is detected.
  BleDevice? get closest => devices.isEmpty ? null : devices.first;

  List<RadarBlip> get blips =>
      devices.map((d) => d.toBlip(_settings.bleRangeMeters)).toList();

  double _angleFor(String id) => (id.hashCode % 360) * math.pi / 180;

  Future<void> start() async {
    _error = null;
    _setState(BleState.starting);

    final granted = await _permissions.requestBlePermissions();
    if (!granted) {
      _setState(BleState.unauthorized);
      return;
    }

    if (!(await FlutterBluePlus.isSupported)) {
      _setState(BleState.unsupported);
      return;
    }

    // The adapter-state stream drives everything: it emits the current state
    // immediately, so we start scanning only once the adapter is actually ON.
    // This is what keeps a PlatformException from ever being thrown.
    _adapterSub ??= FlutterBluePlus.adapterState.listen(_onAdapterState);
  }

  void _onAdapterState(BluetoothAdapterState s) {
    switch (s) {
      case BluetoothAdapterState.on:
        _beginScan();
        break;
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.turningOff:
      case BluetoothAdapterState.turningOn:
        _stopScanInternal();
        _devices.clear();
        _rssiEma.clear();
        _setState(BleState.bluetoothOff);
        break;
      case BluetoothAdapterState.unauthorized:
        _setState(BleState.unauthorized);
        break;
      case BluetoothAdapterState.unavailable:
        _setState(BleState.unsupported);
        break;
      case BluetoothAdapterState.unknown:
        // transient; keep whatever state we are in
        break;
    }
  }

  Future<void> _beginScan() async {
    if (_state == BleState.scanning) return;
    try {
      _scanSub ??= FlutterBluePlus.scanResults.listen(
        _onResults,
        onError: (e) {
          _error = _friendly(e);
          _setState(BleState.error);
        },
      );
      await FlutterBluePlus.startScan(
        continuousUpdates: true, // keep RSSI fresh for live distance
        androidScanMode: AndroidScanMode.lowLatency,
      );
      _setState(BleState.scanning);
    } catch (e) {
      // Never surface a raw PlatformException to the user.
      _error = _friendly(e);
      _setState(BleState.error);
    }
  }

  void _onResults(List<ScanResult> results) {
    final now = DateTime.now();
    for (final r in results) {
      final id = r.device.remoteId.str;
      final adv = r.advertisementData;
      final name =
          r.device.platformName.isNotEmpty ? r.device.platformName : adv.advName;

      // Exponential moving average smooths out RSSI jitter for stable distance.
      final prev = _rssiEma[id];
      final smoothed = prev == null ? r.rssi.toDouble() : prev * 0.7 + r.rssi * 0.3;
      _rssiEma[id] = smoothed;

      _devices[id] = BleDevice(
        id: id,
        name: name,
        rssi: r.rssi,
        smoothedRssi: smoothed,
        txPower: adv.txPowerLevel,
        angle: _angleFor(id),
        serviceCount: adv.serviceUuids.length,
        classification: BleClassifier.classify(
          name: name,
          appearance: adv.appearance,
          serviceUuids: adv.serviceUuids,
          manufacturerData: adv.manufacturerData,
        ),
        lastSeen: now,
      );
    }

    // Drop devices not seen for a while so stale blips fade out.
    _devices.removeWhere((id, d) {
      final gone = now.difference(d.lastSeen).inSeconds > 10;
      if (gone) _rssiEma.remove(id);
      return gone;
    });

    _checkClosestAlert();
    notifyListeners();
  }

  /// Fire a haptic when the nearest device changes (if the alert is enabled).
  void _checkClosestAlert() {
    final nearest = closest;
    if (nearest == null) {
      _closestId = null;
      return;
    }
    if (nearest.id != _closestId) {
      _closestId = nearest.id;
      if (_settings.closestAlertEnabled) HapticFeedback.mediumImpact();
    }
  }

  /// Ask the OS to enable Bluetooth. On Android this shows the system dialog;
  /// on iOS it is not permitted, so we fall back to a friendly instruction.
  Future<void> requestEnableBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      _error = 'Please turn on Bluetooth from the system settings, then retry.';
      _setState(BleState.error);
    }
  }

  /// Re-run the whole start flow (used by the "Retry" button on error states).
  Future<void> retry() async {
    await _stopScanInternal();
    await start();
  }

  String _friendly(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('bluetooth must be turned on') || msg.contains('adapter')) {
      return 'Bluetooth is turned off.';
    }
    if (msg.contains('permission')) return 'Bluetooth permission is required.';
    return 'Bluetooth scan failed. Please try again.';
  }

  void _setState(BleState s) {
    _state = s;
    notifyListeners();
  }

  Future<void> _stopScanInternal() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
  }

  Future<void> stop() async {
    await _stopScanInternal();
    notifyListeners();
  }

  @override
  void dispose() {
    // Cancel every stream so we never call notifyListeners after disposal.
    _scanSub?.cancel();
    _adapterSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}
