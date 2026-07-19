import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../core/permission_service.dart';
import '../../models/radar_blip.dart';

/// A rough classification used to pick an icon and which radar ring to plot on.
enum DeviceKind { router, computer, printer, mobile, unknown }

class NetworkDevice {
  final String ip;
  final String? hostname;
  final DeviceKind kind;
  final List<int> openPorts;
  final double angle;

  NetworkDevice({
    required this.ip,
    required this.hostname,
    required this.kind,
    required this.openPorts,
    required this.angle,
  });

  /// Wi-Fi cannot give real distance, so we place devices on rings by *type*:
  /// the router sits near the center, infrastructure in the middle, clients out.
  double get ringDistance {
    switch (kind) {
      case DeviceKind.router:
        return 0.18;
      case DeviceKind.printer:
        return 0.5;
      case DeviceKind.computer:
        return 0.72;
      case DeviceKind.mobile:
        return 0.9;
      case DeviceKind.unknown:
        return 0.6;
    }
  }

  RadarBlip toBlip() => RadarBlip(
        id: ip,
        label: hostname ?? ip,
        subtitle: ip,
        distance: ringDistance,
        angle: angle,
      );
}

/// Scans the local /24 subnet by attempting short TCP connections to a handful
/// of common service ports on each host. Any connection (or connection-refused)
/// proves a host is alive.
class WifiController extends ChangeNotifier {
  WifiController({PermissionService? permissions})
      : _permissions = permissions ?? const PermissionService();

  final PermissionService _permissions;

  // Ports mapped to a best-guess device kind.
  static const Map<int, DeviceKind> _probePorts = {
    80: DeviceKind.router,
    443: DeviceKind.router,
    9100: DeviceKind.printer, // raw printing
    631: DeviceKind.printer, // IPP
    445: DeviceKind.computer, // SMB
    22: DeviceKind.computer, // SSH
    3389: DeviceKind.computer, // RDP
    62078: DeviceKind.mobile, // iOS sync
  };

  final Map<String, NetworkDevice> _devices = {};
  bool _scanning = false;
  double _progress = 0;
  String? _error;
  String? _gatewayIp;
  bool _cancelled = false;

  List<NetworkDevice> get devices => _devices.values.toList()
    ..sort((a, b) => _ipKey(a.ip).compareTo(_ipKey(b.ip)));
  List<RadarBlip> get blips => devices.map((d) => d.toBlip()).toList();
  bool get scanning => _scanning;
  double get progress => _progress;
  String? get error => _error;

  int _ipKey(String ip) {
    final parts = ip.split('.');
    return int.tryParse(parts.isEmpty ? '0' : parts.last) ?? 0;
  }

  double _angleFor(String ip) => (ip.hashCode % 360) * math.pi / 180;

  Future<void> start() async {
    _error = null;
    _cancelled = false;
    _devices.clear();
    _progress = 0;

    final granted = await _permissions.requestWifiPermissions();
    if (!granted) {
      _error = 'Location permission is required to read the Wi-Fi network.';
      notifyListeners();
      return;
    }

    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    _gatewayIp = await info.getWifiGatewayIP();
    if (ip == null || !ip.contains('.')) {
      _error = 'Not connected to a Wi-Fi network.';
      notifyListeners();
      return;
    }

    final subnet = ip.substring(0, ip.lastIndexOf('.')); // e.g. 192.168.1
    _scanning = true;
    notifyListeners();

    // Probe hosts .1 .. .254 with bounded concurrency so we don't exhaust
    // sockets on constrained devices.
    const batchSize = 32;
    for (int base = 1; base <= 254 && !_cancelled; base += batchSize) {
      final futures = <Future<void>>[];
      for (int i = base; i < base + batchSize && i <= 254; i++) {
        futures.add(_probeHost('$subnet.$i'));
      }
      await Future.wait(futures);
      _progress = (base + batchSize) / 254;
      notifyListeners();
    }

    _scanning = false;
    _progress = 1;
    notifyListeners();
  }

  Future<void> _probeHost(String ip) async {
    final foundPorts = <int>[];
    DeviceKind kind = DeviceKind.unknown;

    for (final entry in _probePorts.entries) {
      if (_cancelled) return;
      try {
        final socket = await Socket.connect(ip, entry.key,
            timeout: const Duration(milliseconds: 300));
        socket.destroy();
        foundPorts.add(entry.key);
        kind = entry.value;
      } on SocketException catch (e) {
        // "Connection refused" still proves the host exists.
        if (e.osError?.errorCode == 111 ||
            (e.message.toLowerCase().contains('refused'))) {
          foundPorts.add(entry.key);
        }
      } catch (_) {
        // timeout / unreachable -> host likely down for this port
      }
    }

    if (foundPorts.isEmpty) return;

    // The gateway is always the router regardless of open ports.
    if (ip == _gatewayIp) kind = DeviceKind.router;

    String? hostname;
    try {
      final res = await InternetAddress(ip)
          .reverse()
          .timeout(const Duration(milliseconds: 400));
      hostname = res.host == ip ? null : res.host;
    } catch (_) {}

    _devices[ip] = NetworkDevice(
      ip: ip,
      hostname: hostname,
      kind: kind,
      openPorts: foundPorts,
      angle: _angleFor(ip),
    );
    notifyListeners();
  }

  void stop() {
    _cancelled = true;
    _scanning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelled = true; // stop the scan loop before the object goes away
    super.dispose();
  }
}
