import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tech_radar/core/settings_controller.dart';
import 'package:tech_radar/main.dart';

void main() {
  testWidgets('Home screen shows the radar modes', (tester) async {
    // SettingsController needs SharedPreferences; use in-memory mock values.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(TechRadarApp(settings: SettingsController(prefs)));
    await tester.pump(); // let the location future settle (no plugin in tests)

    expect(find.text('TECH RADAR'), findsOneWidget);
    expect(find.text('COMPASS'), findsOneWidget);
    expect(find.text('WIRELESS RADAR'), findsOneWidget);

    // The home is a lazy ListView; scroll the later cards into view.
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('MAGNETIC FIELD'), 250,
        scrollable: scrollable);
    expect(find.text('MAGNETIC FIELD'), findsOneWidget);
    expect(find.text('NETWORK SCANNER'), findsOneWidget);
  });

  test('SettingsController clamps values to allowed ranges', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsController(prefs);

    s.setBleRange(999);
    expect(s.bleRangeMeters, SettingsController.maxBleRange);

    s.setEmfBaseline(0);
    expect(s.emfBaseline, SettingsController.minEmfBaseline);
  });
}
