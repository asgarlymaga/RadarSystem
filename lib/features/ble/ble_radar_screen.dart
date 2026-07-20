import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/radar_view.dart';
import '../../widgets/status_bar.dart';
import '../comms/comms_hub_screen.dart';
import 'ble_controller.dart';

/// Mode A — Wireless Radar (BLE). Sonar-style sweep, green theme.
class BleRadarScreen extends StatelessWidget {
  const BleRadarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Controller is created here and auto-disposed by Provider on pop.
      create: (context) =>
          BleController(settings: context.read<SettingsController>())..start(),
      child: const _BleRadarBody(),
    );
  }
}

class _BleRadarBody extends StatelessWidget {
  const _BleRadarBody();

  void _showDeviceSheet(BuildContext context, BleDevice d) {
    final range = context.read<SettingsController>().bleRangeMeters;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (modalContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(d.classification.icon, color: AppColors.bleGreen, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(d.displayName,
                      style: const TextStyle(
                          color: AppColors.bleGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _kv('Type', d.typeLabel),
            _kv('Manufacturer', d.manufacturer),
            _kv('MAC / ID', d.id),
            _kv('Signal (live)', '${d.rssi} dBm'),
            _kv('Signal (smoothed)', '${d.smoothedRssi.toStringAsFixed(1)} dBm'),
            if (d.txPower != null) _kv('TX power', '${d.txPower} dBm'),
            _kv('Services advertised', '${d.serviceCount}'),
            _kv('Approx. distance',
                '${d.estimatedMeters.toStringAsFixed(1)} m  (range ${range.toStringAsFixed(0)} m)'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.security, color: AppColors.background),
                label: const Text('SECURE CHAT LINK'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bleGreen,
                  foregroundColor: AppColors.background,
                ),
                onPressed: () {
                  Navigator.pop(modalContext); // Dismiss modal sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommsHubScreen(
                        initialBleDeviceId: d.id,
                        initialBleDeviceName: d.displayName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 150,
                child: Text(k, style: const TextStyle(color: AppColors.textMuted))),
            Expanded(child: Text(v, style: const TextStyle(color: AppColors.textPrimary))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<BleController>();

    return Scaffold(
      appBar: AppBar(title: const Text('WIRELESS RADAR')),
      body: SafeArea(child: _buildBody(context, ctrl)),
    );
  }

  Widget _buildBody(BuildContext context, BleController ctrl) {
    // Full-screen states that replace the radar.
    switch (ctrl.state) {
      case BleState.bluetoothOff:
        return _MessagePanel(
          icon: Icons.bluetooth_disabled,
          title: 'Bluetooth is off',
          message: 'Turn on Bluetooth to scan for nearby wireless devices.',
          buttonLabel: 'TURN ON BLUETOOTH',
          onPressed: ctrl.requestEnableBluetooth,
        );
      case BleState.unauthorized:
        return _MessagePanel(
          icon: Icons.lock_outline,
          title: 'Permission needed',
          message: 'Bluetooth and location permissions are required to scan.',
          buttonLabel: 'RETRY',
          onPressed: ctrl.retry,
        );
      case BleState.unsupported:
        return const _MessagePanel(
          icon: Icons.error_outline,
          title: 'Bluetooth unavailable',
          message: 'This device has no Bluetooth LE hardware.',
        );
      case BleState.error:
        return _MessagePanel(
          icon: Icons.warning_amber,
          title: 'Something went wrong',
          message: ctrl.error ?? 'Unknown error.',
          buttonLabel: 'RETRY',
          onPressed: ctrl.retry,
        );
      case BleState.starting:
      case BleState.scanning:
        return _buildRadar(context, ctrl);
    }
  }

  Widget _buildRadar(BuildContext context, BleController ctrl) {
    return Column(
      children: [
        StatusBar(
          color: AppColors.bleGreen,
          active: ctrl.scanning,
          activeLabel: ctrl.scanning ? 'SCANNING' : 'STARTING',
          trailing: '${ctrl.devices.length} detected',
        ),
        if (ctrl.closest != null)
          _ClosestBanner(
            device: ctrl.closest!,
            onTap: () => _showDeviceSheet(context, ctrl.closest!),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: RadarView(
            blips: ctrl.blips,
            color: AppColors.bleGreen,
            onBlipTap: (b) {
              final dev = ctrl.devices.where((d) => d.id == b.id);
              if (dev.isNotEmpty) _showDeviceSheet(context, dev.first);
            },
          ),
        ),
        const Divider(height: 1, color: AppColors.surfaceHigh),
        Expanded(
          child: ctrl.devices.isEmpty
              ? const Center(
                  child: Text('Searching for BLE devices...',
                      style: TextStyle(color: AppColors.textMuted)))
              : ListView.separated(
                  itemCount: ctrl.devices.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.surface),
                  itemBuilder: (context, i) {
                    final d = ctrl.devices[i];
                    return ListTile(
                      leading: Icon(d.classification.icon, color: AppColors.bleGreen),
                      title: Text(d.displayName,
                          style: const TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text(
                          '${d.typeLabel} • ${d.manufacturer}\n${d.id}',
                          style: const TextStyle(color: AppColors.textMuted)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${d.estimatedMeters.toStringAsFixed(1)} m',
                              style: const TextStyle(color: AppColors.bleGreen)),
                          Text('${d.rssi} dBm',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () => _showDeviceSheet(context, d),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Full-screen informational panel with an optional action button.
class _MessagePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.bleGreen.withValues(alpha: 0.8)),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted)),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.bluetooth),
                label: Text(buttonLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bleGreen,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Highlights the nearest detected device at the top of the radar.
class _ClosestBanner extends StatelessWidget {
  final BleDevice device;
  final VoidCallback onTap;

  const _ClosestBanner({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.bleGreen.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.bleGreen.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(device.classification.icon, color: AppColors.bleGreen, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CLOSEST',
                      style: TextStyle(
                          color: AppColors.bleGreen, fontSize: 10, letterSpacing: 2)),
                  Text('${device.displayName}  •  ${device.typeLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary)),
                ],
              ),
            ),
            Text('${device.estimatedMeters.toStringAsFixed(1)} m',
                style: const TextStyle(
                    color: AppColors.bleGreen, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
