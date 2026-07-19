import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/settings_controller.dart';
import 'features/geo/location_controller.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sci-Fi apps look best locked to portrait with a dark system UI.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // Load persisted settings before the first frame.
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs);

  runApp(TechRadarApp(settings: settings));
}

class TechRadarApp extends StatelessWidget {
  final SettingsController settings;
  const TechRadarApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    // SettingsController + LocationController live above MaterialApp so every
    // mode shares them. Location loads immediately so the home dashboard is
    // ready when the app opens.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => LocationController()..load()),
      ],
      child: MaterialApp(
        title: 'Tech Radar',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
