import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One set of colours per appearance. Same "mission control" style in both:
/// a warm neutral background, one launch-orange accent, hairline borders.
class Palette {
  final Brightness brightness;
  final Color bg, surface, line, text, muted, accent, onAccent, ok, warn, danger;
  /// Department identity: telemetry cyan (avionics), anodized violet (mechanical)
  final Color avionics, mechanical;
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
    required this.avionics,
    required this.mechanical,
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
  avionics: Color(0xFF4CC2E6),
  mechanical: Color(0xFFB59CFF),
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
  avionics: Color(0xFF0A7BA3), // darkened to keep 4.5:1 on paper
  mechanical: Color(0xFF6A4BD6),
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

  /// A colour washed into the card surface, for icon tiles and track backgrounds.
  static Color tint(Color c, [double amount = 0.16]) => Color.lerp(p.surface, c, amount)!;

  static Color dept(String department) =>
      department == 'Mechanical' ? p.mechanical : (department == 'Avionics' ? p.avionics : p.muted);
}

IconData deptIcon(String department) =>
    department == 'Mechanical' ? Icons.precision_manufacturing_outlined : Icons.memory_outlined;

/// Category icons by what the word usually means in a rocketry store; folder otherwise.
IconData categoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('sensor')) return Icons.sensors;
  if (c.contains('radio') || c.contains('telemetry') || c.contains('antenna')) return Icons.settings_input_antenna;
  if (c.contains('computer') || c.contains('board') || c.contains('electronic')) return Icons.developer_board;
  if (c.contains('batter') || c.contains('power')) return Icons.battery_charging_full;
  if (c.contains('fasten') || c.contains('screw') || c.contains('bolt')) return Icons.hardware_outlined;
  if (c.contains('tool')) return Icons.handyman_outlined;
  if (c.contains('motor') || c.contains('propuls')) return Icons.local_fire_department_outlined;
  if (c.contains('recovery') || c.contains('parachute')) return Icons.paragliding;
  if (c.contains('structure') || c.contains('airframe') || c.contains('tube')) return Icons.view_in_ar_outlined;
  if (c == 'uncategorized') return Icons.inbox_outlined;
  return Icons.folder_outlined;
}

/// Durations collapse to zero when the phone's "remove animations" setting is on.
Duration motion(BuildContext context, int ms) =>
    MediaQuery.of(context).disableAnimations ? Duration.zero : Duration(milliseconds: ms);

/// Confident deceleration for arrivals (no bounce).
const easeOutExpo = Cubic(0.16, 1, 0.3, 1);

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
  final IconData? icon;
  const StatusTag(this.label, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
        decoration: BoxDecoration(
          color: C.tint(color, 0.14),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
          ],
        ),
      );
}

/// An icon on a soft wash of its own colour. The one decorative device in the app:
/// colour here always means something (department, status, destination).
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconTile(this.icon, this.color, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: C.tint(color),
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
        child: Icon(icon, color: color, size: size * 0.55),
      );
}

/// Section heading in sentence case, with an optional muted count.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 12),
        child: Row(
          children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.text)),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(trailing!, style: mono.copyWith(color: C.muted, fontSize: 13)),
            ],
          ],
        ),
      );
}

/// Segmented ok / low / out bar that fills from the left when it first appears.
class HealthBar extends StatelessWidget {
  final int ok, low, out;
  final Color okColor;
  final double height;
  const HealthBar(
      {super.key, required this.ok, required this.low, required this.out, required this.okColor, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final total = ok + low + out;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: C.tint(C.muted, 0.18),
        alignment: Alignment.centerLeft,
        child: total == 0
            ? null
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: motion(context, 700),
                curve: easeOutExpo,
                builder: (context, t, _) => FractionallySizedBox(
                  widthFactor: t,
                  child: Row(
                    children: [
                      // Small gaps between segments read as an instrument, not a blob
                      if (ok > 0) Expanded(flex: ok, child: Container(color: okColor)),
                      if (ok > 0 && low + out > 0) const SizedBox(width: 2),
                      if (low > 0) Expanded(flex: low, child: Container(color: C.warn)),
                      if (low > 0 && out > 0) const SizedBox(width: 2),
                      if (out > 0) Expanded(flex: out, child: Container(color: C.danger)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
