import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../theme/app_theme.dart';

/// Best-guess category for a detected BLE device.
enum BleCategory {
  phone('Phone', Icons.smartphone),
  computer('Computer', Icons.computer),
  watch('Smartwatch', Icons.watch),
  wearable('Wearable', Icons.fitness_center),
  audio('Audio / Headphones', Icons.headphones),
  speaker('Speaker', Icons.speaker),
  tv('TV / Display', Icons.tv),
  input('Keyboard / Mouse', Icons.keyboard),
  sensor('Sensor', Icons.sensors),
  tag('Tracker / Tag', Icons.location_searching),
  beacon('Beacon', Icons.podcasts),
  unknown('Unknown device', Icons.bluetooth);

  const BleCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Result of classifying an advertisement.
class BleClassification {
  final BleCategory category;
  final String manufacturer;

  const BleClassification(this.category, this.manufacturer);

  IconData get icon => category.icon;
  String get typeLabel => category.label;
}

/// Turns raw advertisement data into a human-readable device type and vendor.
///
/// Strategy (most reliable first): GAP appearance → advertised service UUIDs →
/// name keywords → manufacturer default.
class BleClassifier {
  const BleClassifier._();

  /// Bluetooth SIG company identifiers (subset of the most common vendors).
  static const Map<int, String> _companies = {
    0x004C: 'Apple',
    0x0075: 'Samsung',
    0x0006: 'Microsoft',
    0x00E0: 'Google',
    0x0059: 'Nordic',
    0x000F: 'Broadcom',
    0x0002: 'Intel',
    0x012D: 'Sony',
    0x0087: 'Garmin',
    0x0157: 'Huami (Amazfit)',
    0x038F: 'Xiaomi',
    0x01D7: 'Qualcomm',
    0x00D2: 'Logitech',
    0x004F: 'Bose',
    0x0131: 'Cypress',
    0x0499: 'Ruuvi',
    0x0171: 'Amazon',
    0x0118: 'JBL / Harman',
  };

  /// Common 16-bit service UUIDs that hint at a device type.
  static BleCategory? _fromServiceUuids(List<Guid> uuids) {
    for (final g in uuids) {
      final s = g.str.toLowerCase();
      if (s.contains('1812')) return BleCategory.input; // HID
      if (s.contains('180d')) return BleCategory.wearable; // Heart Rate
      if (s.contains('1814')) return BleCategory.wearable; // Running Speed
      if (s.contains('1816')) return BleCategory.wearable; // Cycling
      if (s.contains('fed1') || s.contains('fdf0')) return BleCategory.audio;
    }
    return null;
  }

  /// GAP appearance -> category (appearance >> 6 is the category id).
  static BleCategory? _fromAppearance(int? appearance) {
    if (appearance == null || appearance == 0) return null;
    switch (appearance >> 6) {
      case 1:
        return BleCategory.phone;
      case 2:
        return BleCategory.computer;
      case 3:
      case 4:
        return BleCategory.watch;
      case 5:
        return BleCategory.tv; // Display
      case 10:
        return BleCategory.audio; // Media Player
      case 13:
      case 14:
        return BleCategory.wearable; // HR / BP sensors
      case 15:
        return BleCategory.input; // HID
      case 49:
        return BleCategory.wearable; // outdoor sports
      case 51:
        return BleCategory.audio; // Audio Source/Sink family
      default:
        return null;
    }
  }

  static BleCategory? _fromName(String name) {
    final n = name.toLowerCase();
    if (n.isEmpty) return null;

    bool has(List<String> kws) => kws.any(n.contains);

    if (has(['airpod', 'buds', 'headphone', 'headset', 'earbud', 'earphone',
        'wf-', 'wh-', 'jabra', 'bose', 'beats', 'quietcomfort'])) {
      return BleCategory.audio;
    }
    if (has(['speaker', 'soundbar', 'jbl', 'flip', 'charge', 'boombox', 'sonos'])) {
      return BleCategory.speaker;
    }
    if (has(['watch', 'gtr', 'gts', 'versa', 'fitbit', 'garmin', 'amazfit', 'galaxy watch'])) {
      return BleCategory.watch;
    }
    if (has(['band', 'mi band', 'miband', 'tracker', 'whoop', 'ring'])) {
      return BleCategory.wearable;
    }
    if (has(['tv', 'bravia', 'aquos', 'roku', 'chromecast', 'firetv', 'fire tv', 'shield'])) {
      return BleCategory.tv;
    }
    if (has(['iphone', 'galaxy', 'pixel', 'redmi', 'oneplus', 'xperia', 'huawei p', 'phone'])) {
      return BleCategory.phone;
    }
    if (has(['macbook', 'imac', 'thinkpad', 'laptop', 'desktop', 'pc-', 'notebook'])) {
      return BleCategory.computer;
    }
    if (has(['keyboard', 'mouse', 'kbd', 'trackpad', 'magic '])) {
      return BleCategory.input;
    }
    if (has(['tile', 'airtag', 'smarttag', 'beacon'])) {
      return BleCategory.tag;
    }
    return null;
  }

  /// Classify an advertisement, returning a category + manufacturer name.
  static BleClassification classify({
    required String name,
    required int? appearance,
    required List<Guid> serviceUuids,
    required Map<int, List<int>> manufacturerData,
  }) {
    // Manufacturer from the first company id in the manufacturer data.
    String manufacturer = 'Unknown';
    if (manufacturerData.isNotEmpty) {
      final companyId = manufacturerData.keys.first;
      manufacturer = _companies[companyId] ??
          '0x${companyId.toRadixString(16).padLeft(4, '0').toUpperCase()}';
    }

    final category = _fromAppearance(appearance) ??
        _fromServiceUuids(serviceUuids) ??
        _fromName(name) ??
        // Apple with no other hints and manufacturer data is usually a beacon
        // (iBeacon / AirTag / Find My) or a phone broadcasting.
        (manufacturerData.isNotEmpty ? BleCategory.beacon : BleCategory.unknown);

    return BleClassification(category, manufacturer);
  }

  /// Accent color used for the category chip.
  static Color colorFor(BleCategory c) {
    switch (c) {
      case BleCategory.unknown:
      case BleCategory.beacon:
        return AppColors.textMuted;
      default:
        return AppColors.bleGreen;
    }
  }
}
