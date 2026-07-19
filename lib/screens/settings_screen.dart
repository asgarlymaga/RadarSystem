import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/settings_controller.dart';
import '../theme/app_theme.dart';

/// Adjust BLE radar range, EMF baseline and the closest-device alert.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
        actions: [
          TextButton(
            onPressed: s.resetDefaults,
            child: const Text('RESET', style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionCard(
              accent: AppColors.bleGreen,
              icon: Icons.bluetooth_searching,
              title: 'WIRELESS RADAR',
              children: [
                _SliderTile(
                  label: 'Radar range',
                  value: s.bleRangeMeters,
                  min: SettingsController.minBleRange,
                  max: SettingsController.maxBleRange,
                  divisions: 25,
                  accent: AppColors.bleGreen,
                  valueLabel: '${s.bleRangeMeters.toStringAsFixed(0)} m',
                  onChanged: s.setBleRange,
                  hint: 'Distance mapped to the outer edge of the radar.',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionCard(
              accent: AppColors.emfRed,
              icon: Icons.sensors,
              title: 'MAGNETIC FIELD',
              children: [
                _SliderTile(
                  label: 'Ambient baseline',
                  value: s.emfBaseline,
                  min: SettingsController.minEmfBaseline,
                  max: SettingsController.maxEmfBaseline,
                  divisions: 70,
                  accent: AppColors.emfRed,
                  valueLabel: '${s.emfBaseline.toStringAsFixed(0)} µT',
                  onChanged: s.setEmfBaseline,
                  hint: 'Anomalies are measured above this value. '
                      'Use "Calibrate" inside the EMF screen for an exact reading.',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionCard(
              accent: AppColors.wifiBlue,
              icon: Icons.notifications_active,
              title: 'ALERTS',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.wifiBlue,
                  title: const Text('Closest-device alert',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text(
                      'Vibrate when the nearest Bluetooth device changes.',
                      style: TextStyle(color: AppColors.textMuted)),
                  value: s.closestAlertEnabled,
                  onChanged: s.setClosestAlert,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.accent,
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: accent, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color accent;
  final String valueLabel;
  final String hint;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.accent,
    required this.valueLabel,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textPrimary)),
            Text(valueLabel, style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accent,
            thumbColor: accent,
            overlayColor: accent.withValues(alpha: 0.2),
            inactiveTrackColor: AppColors.surfaceHigh,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Text(hint, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}
