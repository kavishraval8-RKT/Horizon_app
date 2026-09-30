import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import 'inventory_screen.dart';
import 'progress_screen.dart';
import 'requests_screen.dart';
import 'admin_ledger_screen.dart';

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
    final isAdmin = _pbService.isAdmin;

    // Build screens list based on admin status
    final screens = [
      const InventoryScreen(),
      const ProgressScreen(),
      const RequestsScreen(),
      if (isAdmin) const AdminLedgerScreen(),
    ];

    // Build navigation items based on admin status
    final navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.inventory),
        label: 'Inventory',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.track_changes),
        label: 'Progress',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.request_page),
        label: 'Requests',
      ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.assessment),
          label: 'Ledger',
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horizon'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: Colors.grey[900],
            onSelected: (String value) {
              switch (value) {
                case 'logout':
                  _pbService.logout();
                  Navigator.of(context).pushReplacementNamed('/login');
                  break;
                case 'profile':
                case 'password':
                case 'services':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Coming soon!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 12),
                    Text('User Details'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'password',
                child: Row(
                  children: [
                    Icon(Icons.lock_reset, size: 20),
                    SizedBox(width: 12),
                    Text('Reset Password'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'services',
                child: Row(
                  children: [
                    Icon(Icons.build_circle, size: 20),
                    SizedBox(width: 12),
                    Text('Services'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: navItems,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
