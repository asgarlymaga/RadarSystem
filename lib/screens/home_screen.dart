import 'package:flutter/material.dart';

import '../features/ble/ble_radar_screen.dart';
import '../features/emf/emf_detector_screen.dart';
import '../features/compass/compass_screen.dart';
import '../features/geo/location_dashboard.dart';
import '../features/wifi/wifi_scanner_screen.dart';
import '../features/comms/comms_hub_screen.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

/// Main screen: Sci-Fi hub with three large mode cards.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.settings, color: AppColors.textMuted),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _Header(),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const LocationDashboard(),
                  const SizedBox(height: 18),
                  _ModeCard(
                    title: 'SECURE COMMS',
                    subtitle: 'LAN Broadcast • BLE Chat P2P',
                    icon: Icons.chat_bubble_outline,
                    color: Colors.purpleAccent,
                    onTap: () => _open(context, const CommsHubScreen()),
                  ),
                  const SizedBox(height: 18),
                  _ModeCard(
                    title: 'COMPASS',
                    subtitle: 'Heading + bearings to landmarks',
                    icon: Icons.explore,
                    color: AppColors.emfRed,
                    onTap: () => _open(context, const CompassScreen()),
                  ),
                  const SizedBox(height: 18),
                  _ModeCard(
                    title: 'WIRELESS RADAR',
                    subtitle: 'BLE • smartwatches, headphones, TVs',
                    icon: Icons.bluetooth_searching,
                    color: AppColors.bleGreen,
                    onTap: () => _open(context, const BleRadarScreen()),
                  ),
                  const SizedBox(height: 18),
                  _ModeCard(
                    title: 'NETWORK SCANNER',
                    subtitle: 'Wi-Fi • routers, printers, PCs',
                    icon: Icons.wifi_tethering,
                    color: AppColors.wifiBlue,
                    onTap: () => _open(context, const WifiScannerScreen()),
                  ),
                  const SizedBox(height: 18),
                  _ModeCard(
                    title: 'MAGNETIC FIELD',
                    subtitle: 'EMF • hidden wires & magnets',
                    icon: Icons.blur_on,
                    color: AppColors.emfRed,
                    onTap: () => _open(context, const EmfDetectorScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.radar, size: 56, color: AppColors.bleGreen.withValues(alpha: 0.9)),
        const SizedBox(height: 12),
        const Text('TECH RADAR',
            style: TextStyle(
                fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 6, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('ENVIRONMENT SCANNER SUITE',
            style: TextStyle(color: AppColors.textMuted, letterSpacing: 3, fontSize: 11)),
      ],
    );
  }
}

/// A large, glowing, tappable mode card.
class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [AppColors.surfaceHigh, AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.4),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 18, spreadRadius: 1),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.6)),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
