import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../widgets/radar_view.dart';
import '../../widgets/status_bar.dart';
import 'wifi_controller.dart';

/// Mode B — Network Scanner (Wi-Fi). Concentric topology radar, blue theme.
class WifiScannerScreen extends StatelessWidget {
  const WifiScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WifiController()..start(),
      child: const _WifiBody(),
    );
  }
}

class _WifiBody extends StatelessWidget {
  const _WifiBody();

  IconData _iconFor(DeviceKind kind) {
    switch (kind) {
      case DeviceKind.router:
        return Icons.router;
      case DeviceKind.printer:
        return Icons.print;
      case DeviceKind.computer:
        return Icons.computer;
      case DeviceKind.mobile:
        return Icons.smartphone;
      case DeviceKind.unknown:
        return Icons.devices_other;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<WifiController>();

    return Scaffold(
      appBar: AppBar(title: const Text('NETWORK SCANNER')),
      body: SafeArea(
        child: Column(
          children: [
            StatusBar(
              color: AppColors.wifiBlue,
              icon: Icons.wifi_find,
              active: ctrl.scanning,
              activeLabel: 'MAPPING ${(ctrl.progress * 100).round()}%',
              trailing: '${ctrl.devices.length} hosts',
              error: ctrl.error,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: RadarView(
                blips: ctrl.blips,
                color: AppColors.wifiBlue,
                sweepSeconds: 6, // slower, calmer network sweep
              ),
            ),
            if (ctrl.scanning)
              LinearProgressIndicator(
                value: ctrl.progress,
                backgroundColor: AppColors.surface,
                color: AppColors.wifiBlue,
                minHeight: 2,
              ),
            const Divider(height: 1, color: AppColors.surfaceHigh),
            Expanded(
              child: ctrl.devices.isEmpty
                  ? Center(
                      child: Text(
                          ctrl.scanning ? 'Mapping the network...' : 'No hosts found',
                          style: const TextStyle(color: AppColors.textMuted)))
                  : ListView.separated(
                      itemCount: ctrl.devices.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.surface),
                      itemBuilder: (context, i) {
                        final d = ctrl.devices[i];
                        return ListTile(
                          leading: Icon(_iconFor(d.kind), color: AppColors.wifiBlue),
                          title: Text(d.hostname ?? d.ip,
                              style: const TextStyle(color: AppColors.textPrimary)),
                          subtitle: Text('${d.ip}  •  ports: ${d.openPorts.join(', ')}',
                              style: const TextStyle(color: AppColors.textMuted)),
                          trailing: Text(d.kind.name,
                              style: const TextStyle(color: AppColors.wifiBlue)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
