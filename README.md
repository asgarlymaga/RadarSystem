# Tech Radar

A dark, Sci-Fi Flutter app that scans the environment three ways:

| Mode | Tech | UI |
|------|------|----|
| **A — Wireless Radar** | `flutter_blue_plus` (BLE) | Rotating sonar sweep, green, RSSI → distance blips |
| **B — Network Scanner** | `network_info_plus` + TCP probe | Concentric topology radar, blue, devices on rings by type |
| **C — Magnetic Field** | `sensors_plus` magnetometer | Pulsing bio-core, red, accelerating ping + vibration |
| **D — Secure Comms Hub**| UDP Broadcast + BLE Chat simulator | Dual-pane cyber purple/teal chat panels for LAN & BLE |

## Setup

The native platform folders (`android/`, `ios/`, `web/`) are already scaffolded
and the manifest/plist permissions are already applied. Just install packages
and run:

```bash
cd SimpleRadarSystem
flutter pub get
flutter run              # pick a device, or:
flutter run -d chrome    # web smoke-test (sensors inactive on web)
```

### Permissions (already applied)

- **Android** — [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)
  has the Bluetooth / location / network / vibration permissions.
- **iOS** — [`ios/Runner/Info.plist`](ios/Runner/Info.plist) has the Bluetooth,
  location, local-network and motion usage descriptions.

The originals also live in [`platform/`](platform/) for reference. Runtime
permission *requests* happen in
[`lib/core/permission_service.dart`](lib/core/permission_service.dart) when each
mode starts.

> Sensors (BLE, Wi-Fi socket scan, magnetometer, vibration) are **mobile-only**.
> The web build renders the UI but those plugins return no data — use an Android
> or iOS device for the full experience.

### Ping sound (Mode C)

Drop a short `ping.mp3` into [`assets/sounds/`](assets/sounds/) — see the note
there. The app runs without it (haptics still fire).

## Architecture

Simple, single-responsibility **ChangeNotifier controllers** (one per mode) held
by a `ChangeNotifierProvider` created on each screen's route, so streams start on
push and are disposed automatically on pop — no leaks. A single
`SettingsController` lives above `MaterialApp` (persisted via
`shared_preferences`) and is read by every mode.

### Settings & alerts

- **Settings screen** (gear icon on the home hub): adjustable **BLE radar range**
  (5–30 m, remaps every blip live), **EMF ambient baseline** (20–90 µT), and a
  **closest-device alert** toggle.
- **EMF live calibration**: the *Calibrate* button on the EMF screen snaps the
  baseline to the current filtered reading — hold the phone away from sources
  first for an accurate zero.
- **Closest-device alert** (BLE): the nearest device (strongest RSSI) is shown in
  a banner above the radar, and a medium haptic fires whenever the nearest device
  changes (toggle in settings).

### Secure Comms Hub (New Feature)

- **LAN Channel**: Utilizes dynamic, real-time UDP broadcasting/multicasting on Port `45454` allowing automatic discovery and communication of group members on the same local network subnet. It operates with a simulated fall-back connection in single-device or simulator environments so communications are always interactive.
- **BLE Secure Link**: Features full secure peer-to-peer (P2P) chat channels directly connecting to wireless devices discovered on the Wireless Radar. Initiates an encrypted link handshake (ECDH key exchange simulation) and runs interactive terminal communications with discovered devices through highly customizable responsive commands (e.g. diagnostics telemetry, decrypt overlays).

```
lib/
├── main.dart                     # app entry + theme wiring
├── theme/app_theme.dart          # dark Sci-Fi theme + per-mode accent colors
├── core/
│   ├── permission_service.dart   # BLE / Wi-Fi / EMF runtime permissions
│   └── settings_controller.dart  # persisted app-wide settings (provided at root)
├── models/radar_blip.dart        # generic (distance, angle) point on a radar
├── widgets/
│   ├── radar_grid_painter.dart   # static rings + crosshairs (shared)
│   ├── radar_sweep_painter.dart  # rotating sweep + glowing blips (shared)
│   ├── radar_view.dart           # animated disc + tap-to-select (shared)
│   └── status_bar.dart           # scan-state header (shared)
├── screens/
│   ├── home_screen.dart          # hub with 3 mode cards + settings entry
│   └── settings_screen.dart      # BLE range / EMF baseline / alert toggle
└── features/
    ├── ble/    ble_controller.dart · ble_radar_screen.dart
    ├── wifi/   wifi_controller.dart · wifi_scanner_screen.dart
    └── emf/    emf_controller.dart · emf_core_painter.dart · emf_detector_screen.dart
```

### Key design notes

- **RSSI → distance** (BLE): log-distance path-loss model
  `d = 10^((txPower - rssi) / (10·n))`, `txPower = -59`, `n = 2.5`, clamped to a
  15 m radar range. Each device gets a stable angle hashed from its MAC so blips
  don't jump between scans.
- **Wi-Fi placement**: real distance isn't measurable, so devices are placed on
  rings by *type* (router near center → clients at the edge). Discovery is a
  bounded-concurrency TCP-connect sweep of the `/24` subnet on common ports
  (a refused connection still proves a host is alive).
- **EMF ping cadence**: `|B| = √(x²+y²+z²)`, low-pass filtered; the ping/vibration
  interval scales from 1200 ms (calm) down to 120 ms (strong) and the timer is
  only rescheduled when the target interval shifts meaningfully.
