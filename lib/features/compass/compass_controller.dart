import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Computes a tilt-compensated compass heading by fusing the accelerometer
/// (gravity vector) and magnetometer, using the AOSP getRotationMatrix /
/// getOrientation approach. Heading is 0° = geographic-ish north (magnetic),
/// increasing clockwise.
class CompassController extends ChangeNotifier {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  // Latest raw sensor vectors.
  double _ax = 0, _ay = 0, _az = 9.81;
  double _mx = 0, _my = 0, _mz = 0;
  bool _hasMag = false;

  // Circular smoothing (averaging angles via their sin/cos avoids the 359->0
  // wrap-around glitch).
  double _sinEma = 0, _cosEma = 1;
  double _heading = 0;
  bool _running = false;

  double get heading => _heading;
  bool get running => _running;

  /// Nearest cardinal / inter-cardinal label for the current heading.
  String get cardinal {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[(((_heading + 22.5) % 360) ~/ 45)];
  }

  void start() {
    if (_running) return;
    _running = true;
    // accelerometerEventStream INCLUDES gravity (needed for tilt compensation).
    _accelSub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen((e) {
      _ax = e.x;
      _ay = e.y;
      _az = e.z;
      _recompute();
    }, onError: (_) {});
    _magSub = magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen((e) {
      _mx = e.x;
      _my = e.y;
      _mz = e.z;
      _hasMag = true;
      _recompute();
    }, onError: (_) {});
  }

  void _recompute() {
    if (!_hasMag) return;

    // H = M x A  (cross product of magnetic field and gravity)
    var hx = _my * _az - _mz * _ay;
    var hy = _mz * _ax - _mx * _az;
    var hz = _mx * _ay - _my * _ax;
    final normH = math.sqrt(hx * hx + hy * hy + hz * hz);
    if (normH < 0.1) return; // device is close to free-fall / bad reading

    hx /= normH;
    hy /= normH;
    hz /= normH;

    final invA = 1.0 / math.sqrt(_ax * _ax + _ay * _ay + _az * _az);
    final ax = _ax * invA, az = _az * invA;

    // M = A x H, second row of the rotation matrix. Only My is needed for the
    // azimuth = atan2(Hy, My).
    final my = az * hx - ax * hz;

    // azimuth = atan2(Hy, My)
    final azimuth = math.atan2(hy, my);
    final rad = azimuth; // radians

    // Smooth via sin/cos EMA, then convert back to a 0..360 heading.
    _sinEma = _sinEma * 0.8 + math.sin(rad) * 0.2;
    _cosEma = _cosEma * 0.8 + math.cos(rad) * 0.2;
    _heading = (math.atan2(_sinEma, _cosEma) * 180 / math.pi + 360) % 360;

    notifyListeners();
  }

  void stop() {
    _running = false;
    _accelSub?.cancel();
    _magSub?.cancel();
    _accelSub = null;
    _magSub = null;
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _magSub?.cancel();
    super.dispose();
  }
}
