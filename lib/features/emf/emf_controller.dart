import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';

import '../../core/settings_controller.dart';

/// Reads the magnetometer and turns field strength into a pulsing UI plus an
/// accelerating "ping" (sound + haptic) as the phone nears a magnetic source.
class EmfController extends ChangeNotifier {
  EmfController({required SettingsController settings}) : _settings = settings {
    _magnitude = _settings.emfBaseline;
    _smoothed = _settings.emfBaseline;
  }

  final SettingsController _settings;

  // Above this many uT over baseline we consider it a strong anomaly.
  static const double strongDelta = 80.0;

  /// User-configurable ambient baseline (Earth's field is roughly 25-65 µT).
  double get baseline => _settings.emfBaseline;

  StreamSubscription<MagnetometerEvent>? _magSub;
  Timer? _pingTimer;
  final AudioPlayer _player = AudioPlayer();
  bool _hasVibrator = false;

  late double _magnitude; // current |B| in uT
  late double _smoothed; // low-pass filtered value for a calm UI
  bool _running = false;

  double get magnitude => _magnitude;
  double get smoothed => _smoothed;
  bool get running => _running;

  /// 0..1 intensity of the anomaly relative to [strongDelta] over [baseline].
  double get intensity =>
      ((_smoothed - baseline) / strongDelta).clamp(0.0, 1.0);

  bool get isAnomaly => (_smoothed - baseline) > 8.0;

  Future<void> start() async {
    if (_running) return;
    _running = true;

    _hasVibrator = await Vibration.hasVibrator();
    await _player.setReleaseMode(ReleaseMode.stop);
    // Low latency so pings feel responsive.
    await _player.setPlayerMode(PlayerMode.lowLatency);

    _magSub = magnetometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onEvent, onError: (_) {});

    _updatePingTimer();
    notifyListeners();
  }

  void _onEvent(MagnetometerEvent e) {
    // Magnitude of the field vector: B = sqrt(x^2 + y^2 + z^2).
    _magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    // Exponential moving average removes jitter without much lag.
    _smoothed = _smoothed * 0.85 + _magnitude * 0.15;
    _updatePingTimer();
    notifyListeners();
  }

  /// The stronger the field, the shorter the interval between pings.
  Duration get _pingInterval {
    // 1200 ms when calm -> 120 ms at full intensity.
    final ms = (1200 - intensity * 1080).clamp(120.0, 1200.0);
    return Duration(milliseconds: ms.round());
  }

  Duration? _currentInterval;

  /// Reschedule the ping timer only when the target interval changes enough,
  /// so we are not tearing down a Timer on every sensor sample.
  void _updatePingTimer() {
    if (!_running) return;

    if (!isAnomaly) {
      _pingTimer?.cancel();
      _pingTimer = null;
      _currentInterval = null;
      return;
    }

    final target = _pingInterval;
    if (_currentInterval != null &&
        (_currentInterval!.inMilliseconds - target.inMilliseconds).abs() < 60) {
      return; // close enough, keep the existing timer
    }

    _currentInterval = target;
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(target, (_) => _ping());
  }

  Future<void> _ping() async {
    // Haptic feedback scaled by intensity.
    if (_hasVibrator) {
      Vibration.vibrate(duration: (20 + intensity * 60).round());
    } else {
      HapticFeedback.lightImpact();
    }
    // Sound ping (asset added in pubspec). Failures are non-fatal.
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/ping.mp3'), volume: 0.6 + 0.4 * intensity);
    } catch (_) {}
  }

  /// Set the ambient baseline to the current filtered reading. Call while the
  /// phone is away from any obvious magnetic source for an accurate zero.
  void calibrate() {
    _settings.setEmfBaseline(_smoothed);
    _updatePingTimer();
    notifyListeners();
  }

  void stop() {
    _running = false;
    _magSub?.cancel();
    _magSub = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _currentInterval = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Tear down sensor stream, timer and audio player to avoid leaks.
    _magSub?.cancel();
    _pingTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
