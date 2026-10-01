import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One set of colours per appearance. Same "mission control" style in both:
/// a warm neutral background, one launch-orange accent, hairline borders.
class Palette {
  final Brightness brightness;
  final Color bg, surface, line, text, muted, accent, onAccent, ok, warn, danger;
  const Palette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.ok,
    required this.warn,
    required this.danger,
  });
}

const darkPalette = Palette(
  brightness: Brightness.dark,
  bg: Color(0xFF0E0E0C),
  surface: Color(0xFF181816),
  line: Color(0xFF2A2A27),
  text: Color(0xFFEDEAE3),
  muted: Color(0xFF8A867E),
  accent: Color(0xFFFF5A1F),
  onAccent: Color(0xFF0E0E0C),
  ok: Color(0xFF7BC47F),
  warn: Color(0xFFE5B33B),
  danger: Color(0xFFE5484D),
);

const lightPalette = Palette(
  brightness: Brightness.light,
  bg: Color(0xFFF6F5F1), // warm paper
  surface: Color(0xFFFFFFFF),
  line: Color(0xFFE2E0DA),
  text: Color(0xFF161614),
  muted: Color(0xFF6E6A62),
  accent: Color(0xFFE0480E), // deeper orange: readable on white
  onAccent: Color(0xFFFFFFFF),
  ok: Color(0xFF2E7D32),
  warn: Color(0xFFA86B00),
  danger: Color(0xFFC62828),
);

/// Current colours. main.dart swaps [p] and rebuilds the app when the appearance changes.
class C {
  static Palette p = darkPalette;
  static Color get bg => p.bg;
  static Color get surface => p.surface;
  static Color get line => p.line;
  static Color get text => p.text;
  static Color get muted => p.muted;
  static Color get accent => p.accent;
  static Color get ok => p.ok;
  static Color get warn => p.warn;
  static Color get danger => p.danger;
}

/// Appearance setting (System / Dark / Light), saved on the device.
final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
const _themeKey = 'theme_mode';

Future<void> loadThemeMode() async {
  final saved = (await SharedPreferences.getInstance()).getString(_themeKey);
  themeMode.value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.dark);
}

Future<void> setThemeMode(ThemeMode mode) async {
  themeMode.value = mode;
  await (await SharedPreferences.getInstance()).setString(_themeKey, mode.name);
}

/// Monospace for numbers (quantities, times) so columns line up like instrument readouts.
const mono = TextStyle(fontFamily: 'monospace', fontFeatures: [FontFeature.tabularFigures()]);

ThemeData buildTheme(Palette p) {
  const radius = BorderRadius.all(Radius.circular(4));
  final hairline = BorderSide(color: p.line);
  final base = ThemeData(useMaterial3: true, brightness: p.brightness);

  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme(
      brightness: p.brightness,
      onSecondary: p.onAccent,
      onError: p.onAccent,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent,
      surface: p.surface,
      onSurface: p.text,
      error: p.danger,
      outline: p.line,
    ),
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.text, letterSpacing: 0.2),
      shape: Border(bottom: hairline),
      systemOverlayStyle: p.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      labelStyle: TextStyle(color: p.muted),
      hintStyle: TextStyle(color: p.muted),
      border: OutlineInputBorder(borderRadius: radius, borderSide: hairline),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: hairline),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.accent)),
      errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: p.danger)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        side: hairline,
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.text)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      shape: Border(top: hairline),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
    ),
    // Light mode uses dark "inverse" snackbars so white text also reads on the red error ones
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.brightness == Brightness.dark ? p.surface : p.text,
      contentTextStyle: TextStyle(color: p.brightness == Brightness.dark ? p.text : p.bg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius, side: hairline),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    datePickerTheme: DatePickerThemeData(backgroundColor: p.surface),
    timePickerTheme: TimePickerThemeData(backgroundColor: p.surface),
  );
}

/// Status shown as coloured text with a hairline outline, not a filled blob.
class StatusTag extends StatelessWidget {
  final String label;
  final Color color;
  const StatusTag(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label.toUpperCase(),
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      );
}
