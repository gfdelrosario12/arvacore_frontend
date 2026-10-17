import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../alerts/presentation/alerts_screen.dart';
import '../../analytics/presentation/system_evaluation_dashboard_screen.dart';
import '../../diagnostics/presentation/device_diagnostics_screen.dart';
import '../../field/presentation/field_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../irrigation/presentation/manual_control_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../telemetry_stream/presentation/screens/telemetry_stream_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return AppStrings.appTitle;
      case 1:
        return AppStrings.navField;
      case 2:
        return AppStrings.navManualControl;
      case 3:
        return AppStrings.navResearch;
      case 4:
        return AppStrings.navSettings;
      default:
        return AppStrings.appTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        onNavigateToControl: () => _onTabSelected(2),
        onNavigateToField: () => _onTabSelected(1),
      ),
      const FieldScreen(),
      const ManualControlScreen(),
      const SystemEvaluationDashboardScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_getAppBarTitle(_currentIndex)),
        actions: [
          IconButton(
            icon: const Icon(Icons.stream_outlined),
            tooltip: 'ESP32 Telemetry Stream',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TelemetryStreamScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.health_and_safety_outlined),
            tooltip: 'Device Diagnostics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeviceDiagnosticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Badge(
              label: Text('2'),
              child: Icon(Icons.notifications_outlined),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AlertsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: AppStrings.navHome,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view),
              label: AppStrings.navField,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.touch_app_outlined),
              activeIcon: Icon(Icons.touch_app),
              label: AppStrings.navManualControl,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.science_outlined),
              activeIcon: Icon(Icons.science),
              label: AppStrings.navResearch,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: AppStrings.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
