import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_bar.dart';
import 'emf_controller.dart';
import 'emf_core_painter.dart';

/// Mode C — Magnetic Field Detector (EMF). Pulsing bio-radar core, red theme.
class EmfDetectorScreen extends StatelessWidget {
  const EmfDetectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          EmfController(settings: context.read<SettingsController>())..start(),
      child: const _EmfBody(),
    );
  }
}

class _EmfBody extends StatefulWidget {
  const _EmfBody();

  @override
  State<_EmfBody> createState() => _EmfBodyState();
}

class _EmfBodyState extends State<_EmfBody> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EmfController>();
    // Speed up the ripple animation as the field intensifies.
    _pulse.duration =
        Duration(milliseconds: (1600 - ctrl.intensity * 1200).round().clamp(400, 1600));

    return Scaffold(
      appBar: AppBar(title: const Text('EMF DETECTOR')),
      body: SafeArea(
        child: Column(
          children: [
            StatusBar(
              color: AppColors.emfRed,
              icon: Icons.sensors,
              active: ctrl.running,
              activeLabel: ctrl.isAnomaly ? 'ANOMALY DETECTED' : 'MONITORING',
              trailing: '${ctrl.smoothed.toStringAsFixed(1)} µT',
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => CustomPaint(
                        painter: EmfCorePainter(
                          pulse: _pulse.value,
                          intensity: ctrl.intensity,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ctrl.smoothed.toStringAsFixed(0),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text('µT',
                                  style: TextStyle(color: Colors.white70, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _Gauge(
              intensity: ctrl.intensity,
              value: ctrl.smoothed,
              baseline: ctrl.baseline,
              onCalibrate: () {
                ctrl.calibrate();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surfaceHigh,
                    content: Text(
                      'Baseline calibrated to ${ctrl.baseline.toStringAsFixed(0)} µT',
                      style: const TextStyle(color: AppColors.emfRed),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Horizontal strength gauge with baseline marker + calibration button.
class _Gauge extends StatelessWidget {
  final double intensity;
  final double value;
  final double baseline;
  final VoidCallback onCalibrate;

  const _Gauge({
    required this.intensity,
    required this.value,
    required this.baseline,
    required this.onCalibrate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('FIELD STRENGTH',
                  style: TextStyle(color: AppColors.textMuted, letterSpacing: 2)),
              OutlinedButton.icon(
                onPressed: onCalibrate,
                icon: const Icon(Icons.tune, size: 16, color: AppColors.emfRed),
                label: const Text('CALIBRATE', style: TextStyle(color: AppColors.emfRed)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.emfRed),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: intensity,
              minHeight: 14,
              backgroundColor: AppColors.surfaceHigh,
              color: Color.lerp(Colors.orange, AppColors.emfRed, intensity),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Baseline ~${baseline.toStringAsFixed(0)} µT  •  move slowly near walls/wires',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
