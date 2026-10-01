import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/pocketbase_service.dart';
import 'account_screen.dart';
import 'inventory_screen.dart';
import 'progress_screen.dart';
import 'requests_screen.dart';
import 'admin_ledger_screen.dart';
import 'services_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _pbService = PocketBaseService();

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ('Inventory', InventoryScreen()),
      ('Progress', ProgressScreen()),
      ('Requests', RequestsScreen()),
      if (_pbService.isAdmin) ('Ledger', AdminLedgerScreen()),
      ('More', _MoreScreen()),
    ];
    final index = _currentIndex.clamp(0, tabs.length - 1);

    return Scaffold(
      body: tabs[index].$2,
      // Plain text tabs with an accent underline on the active one
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: C.bg,
          border: Border(top: BorderSide(color: C.line)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = i),
                    child: Padding(
                      padding: EdgeInsets.only(top: 14, bottom: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tabs[i].$1,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                              color: i == index ? C.text : C.muted,
                            ),
                          ),
                          SizedBox(height: 6),
                          Container(
                            height: 2,
                            width: 18,
                            color: i == index ? C.accent : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

    Widget row(String title, String subtitle, VoidCallback onTap, {Color? color}) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
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
            'Services',
            'Book shared equipment',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesScreen())),
          ),
          row(
            'Account',
            name.isNotEmpty ? name : (user?.getStringValue('email') ?? 'Details and password'),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 10),
            child: Text('APPEARANCE', style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
          ),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: C.accent,
              selectedForegroundColor: C.p.onAccent,
              side: BorderSide(color: C.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
            ],
            selected: {themeMode.value},
            onSelectionChanged: (s) => setThemeMode(s.first),
          ),
          const SizedBox(height: 24),
          row(
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
