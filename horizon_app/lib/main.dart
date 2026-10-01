import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/pocketbase_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize PocketBase with persistent auth storage
  await PocketBaseService().init();
  await loadThemeMode();

  runApp(const HorizonApp());
}

class HorizonApp extends StatefulWidget {
  const HorizonApp({super.key});

  @override
  State<HorizonApp> createState() => _HorizonAppState();
}

class _HorizonAppState extends State<HorizonApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    themeMode.addListener(_rebuild);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeMode.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  // Phone switched light/dark: matters when the setting is "System"
  @override
  void didChangePlatformBrightness() => _rebuild();

  @override
  Widget build(BuildContext context) {
    final systemDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    final dark = switch (themeMode.value) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => systemDark,
    };
    C.p = dark ? darkPalette : lightPalette;

    return MaterialApp(
      // Screens read colours from C directly, so rebuild the whole tree when they change.
      key: ValueKey(dark),
      title: 'Horizon',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(C.p),
      home: PocketBaseService().isAuthenticated ? const HomeScreen() : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
