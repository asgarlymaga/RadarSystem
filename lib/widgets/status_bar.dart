import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Header strip showing scan state, a detected count and any error. Shared by
/// all three radar modes so the chrome stays consistent.
class StatusBar extends StatelessWidget {
  final Color color;
  final bool active;
  final String activeLabel;
  final String idleLabel;
  final String trailing;
  final String? error;
  final IconData icon;

  const StatusBar({
    super.key,
    required this.color,
    required this.active,
    required this.trailing,
    this.activeLabel = 'SCANNING',
    this.idleLabel = 'IDLE',
    this.error,
    this.icon = Icons.radar,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        width: double.infinity,
        color: AppColors.emfRed.withValues(alpha: 0.15),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: AppColors.emfRed, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(error!, style: const TextStyle(color: AppColors.emfRed))),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(active ? icon : Icons.pause_circle, color: color, size: 18),
          const SizedBox(width: 8),
          Text(active ? activeLabel : idleLabel,
              style: TextStyle(color: color, letterSpacing: 2)),
          const Spacer(),
          Text(trailing, style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
