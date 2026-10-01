import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/pocketbase_service.dart';
import 'account_screen.dart';
import 'inventory_screen.dart';
import 'progress_screen.dart';
import 'requests_screen.dart';
import 'admin_ledger_screen.dart';
import 'services_screen.dart';
import '../update_check.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _pbService = PocketBaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkForUpdate(context));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('Inventory', Icons.inventory_2_outlined, Icons.inventory_2, InventoryScreen()),
      ('Progress', Icons.insights_outlined, Icons.insights, ProgressScreen()),
      ('Requests', Icons.shopping_cart_outlined, Icons.shopping_cart, RequestsScreen()),
      if (_pbService.isAdmin) ('Ledger', Icons.receipt_long_outlined, Icons.receipt_long, AdminLedgerScreen()),
      ('More', Icons.grid_view_outlined, Icons.grid_view_rounded, _MoreScreen()),
    ];
    final index = _currentIndex.clamp(0, tabs.length - 1);
    final slide = motion(context, 320);

    return Scaffold(
      // Soft cross-fade between tabs; content barely rises so the switch reads as a change of view
      body: AnimatedSwitcher(
        duration: motion(context, 220),
        switchInCurve: easeOutExpo,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(tabs[index].$1), child: tabs[index].$4),
      ),
      bottomNavigationBar: Container(
        color: C.bg,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth / tabs.length;
            return Stack(
              children: [
                // The dock's top hairline, with an orange segment that travels to the active tab
                Positioned(left: 0, right: 0, top: 0, child: Container(height: 1, color: C.line)),
                AnimatedPositioned(
                  duration: slide,
                  curve: easeOutExpo,
                  top: 0,
                  left: index * w + (w - 28) / 2,
                  child: Container(
                    width: 28,
                    height: 2,
                    decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(1)),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (i == index) return;
                            HapticFeedback.selectionClick();
                            setState(() => _currentIndex = i);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedScale(
                                  scale: i == index ? 1.1 : 1.0,
                                  duration: motion(context, 200),
                                  curve: easeOutExpo,
                                  child: AnimatedSwitcher(
                                    duration: motion(context, 160),
                                    child: Icon(
                                      i == index ? tabs[i].$3 : tabs[i].$2,
                                      key: ValueKey(i == index),
                                      size: 22,
                                      color: i == index ? C.accent : C.muted,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AnimatedDefaultTextStyle(
                                  duration: motion(context, 200),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    letterSpacing: 0.2,
                                    fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                                    color: i == index ? C.text : C.muted,
                                  ),
                                  child: Text(tabs[i].$1, maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context) {
    final user = PocketBaseService().currentUser;
    final name = user?.getStringValue('name') ?? '';

    Widget row(IconData icon, Color tone, String title, String subtitle, VoidCallback onTap, {Color? color}) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  IconTile(icon, tone),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontSize: 16, color: color ?? C.text, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(color: C.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: color ?? C.muted),
                ],
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          row(
            Icons.event_available_outlined,
            C.ok,
            'Services',
            'Book shared equipment',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesScreen())),
          ),
          row(
            Icons.person_outline,
            C.accent,
            'Account',
            name.isNotEmpty ? name : (user?.getStringValue('email') ?? 'Details and password'),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
          const SectionTitle('Appearance'),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: C.accent,
              selectedForegroundColor: C.p.onAccent,
              side: BorderSide(color: C.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined, size: 18), label: Text('System')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined, size: 18), label: Text('Dark')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined, size: 18), label: Text('Light')),
            ],
            selected: {themeMode.value},
            onSelectionChanged: (s) => setThemeMode(s.first),
          ),
          const SizedBox(height: 24),
          row(
            Icons.logout,
            C.danger,
            'Log out',
            'Sign out of this device',
            () {
              PocketBaseService().logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            color: C.danger,
          ),
        ],
      ),
    );
  }
}
