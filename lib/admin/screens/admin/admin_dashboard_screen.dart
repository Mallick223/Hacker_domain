import 'package:flutter/material.dart';
import 'live_tab.dart';
import 'incidents_tab.dart';
import 'users_tab.dart';
import 'analytics_tab.dart';
import '../../theme/admin_theme.dart';

/// Entry point for the admin dashboard. Wrap navigation to this screen
/// in whatever admin-auth check you use (see note in README section below).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _index = 0;

  static const _titles = ['Live Tracking', 'Incidents', 'Users', 'Analytics'];

  static const _tabs = [
    LiveTab(),
    IncidentsTab(),
    UsersTab(),
    AnalyticsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: adminTheme,
      child: Scaffold(
        appBar: AppBar(title: Text(_titles[_index])),
        body: IndexedStack(index: _index, children: _tabs),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Live'),
            BottomNavigationBarItem(icon: Icon(Icons.warning_amber_outlined), label: 'Incidents'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Users'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Analytics'),
          ],
        ),
      ),
    );
  }
}
