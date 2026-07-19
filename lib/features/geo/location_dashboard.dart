import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import 'geo_math.dart';
import 'geo_radar_painter.dart';
import 'location_controller.dart';

/// Shown on the home screen at launch: your coordinates + a visual of your
/// distance to the Equator, both Poles, the Kaaba and the Pyramids of Giza.
class LocationDashboard extends StatelessWidget {
  const LocationDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<LocationController>();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.wifiBlue.withValues(alpha: 0.3)),
      ),
      child: _content(context, ctrl),
    );
  }

  Widget _content(BuildContext context, LocationController ctrl) {
    switch (ctrl.status) {
      case LocationStatus.loading:
        return const _Centered(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.wifiBlue)),
              SizedBox(width: 12),
              Text('Locating you...', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        );

      case LocationStatus.serviceDisabled:
        return _Problem(
          message: 'Location services are off.',
          buttonLabel: 'OPEN LOCATION SETTINGS',
          onPressed: () async {
            await ctrl.openSettings();
            await ctrl.load();
          },
        );

      case LocationStatus.denied:
        return _Problem(
          message: 'Location permission was denied.',
          buttonLabel: 'RETRY',
          onPressed: ctrl.load,
        );

      case LocationStatus.deniedForever:
        return _Problem(
          message: 'Location permission is permanently denied. Enable it in app settings.',
          buttonLabel: 'OPEN APP SETTINGS',
          onPressed: ctrl.openAppSettings,
        );

      case LocationStatus.error:
        return _Problem(
          message: ctrl.error ?? 'Location error.',
          buttonLabel: 'RETRY',
          onPressed: ctrl.load,
        );

      case LocationStatus.ready:
        return _ready(context, ctrl);
    }
  }

  Widget _ready(BuildContext context, LocationController ctrl) {
    final lat = ctrl.latitude!;
    final lon = ctrl.longitude!;
    final maxKm = ctrl.readings.fold<double>(1, (m, r) => r.distanceKm > m ? r.distanceKm : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.my_location, color: AppColors.wifiBlue, size: 18),
            const SizedBox(width: 8),
            const Text('MY POSITION',
                style: TextStyle(color: AppColors.wifiBlue, letterSpacing: 2)),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh, color: AppColors.textMuted, size: 18),
              onPressed: ctrl.load,
            ),
          ],
        ),
        Text(
          '${_dms(lat, true)}   ${_dms(lon, false)}',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        ),
        Text(
          '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            height: 200,
            width: 200,
            child: CustomPaint(painter: GeoRadarPainter(readings: ctrl.readings)),
          ),
        ),
        const SizedBox(height: 12),
        ...ctrl.readings.map((r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(r.target.icon, color: r.target.color, size: 18),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 120,
                    child: Text(r.target.name,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (r.distanceKm / maxKm).clamp(0.02, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceHigh,
                        color: r.target.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 76,
                    child: Text(formatKm(r.distanceKm),
                        textAlign: TextAlign.right,
                        style: TextStyle(color: r.target.color, fontSize: 12)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  /// Degrees-minutes-seconds with hemisphere letter.
  static String _dms(double value, bool isLat) {
    final hemi = isLat ? (value >= 0 ? 'N' : 'S') : (value >= 0 ? 'E' : 'W');
    final abs = value.abs();
    final d = abs.floor();
    final m = ((abs - d) * 60).floor();
    final s = ((abs - d - m / 60) * 3600);
    return "$d°$m'${s.toStringAsFixed(1)}\"$hemi";
  }
}

class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 60, child: Center(child: child));
}

class _Problem extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _Problem(
      {required this.message, required this.buttonLabel, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_off, color: AppColors.wifiBlue, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message, style: const TextStyle(color: AppColors.textMuted))),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.wifiBlue),
              foregroundColor: AppColors.wifiBlue,
            ),
            child: Text(buttonLabel),
          ),
        ),
      ],
    );
  }
}
