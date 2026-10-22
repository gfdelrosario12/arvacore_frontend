import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../alerts/presentation/alerts_screen.dart';
import '../../alerts/presentation/providers/alert_provider.dart';
import '../../alerts/presentation/widgets/global_alert_overlay.dart';
import '../../analytics/presentation/system_evaluation_dashboard_screen.dart';
import '../../diagnostics/presentation/device_diagnostics_screen.dart';
import '../../field/presentation/field_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../irrigation/presentation/manual_control_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../telemetry_stream/presentation/screens/telemetry_stream_screen.dart';

/// Global revision notifier triggered whenever any screen mutates node pairing,
/// zone assignment, or field topology so all tabs synchronize immediately.
final ValueNotifier<int> globalNodeSyncNotifier = ValueNotifier<int>(0);

/// Index of the Home tab inside the shell navigation.
const int homeTabIndex = 0;

/// Notifies the screens about the tab that is currently visible.
///
/// The shell keeps every tab alive inside an [IndexedStack], so a background tab has to
/// stop its own periodic work explicitly. The Home Dashboard uses this to pause its
/// 5-second telemetry poll while it is not visible and to refresh immediately when the
/// user returns to it.
final ValueNotifier<int> globalActiveTabNotifier = ValueNotifier<int>(homeTabIndex);

void notifyGlobalNodeStateChanged() {
  globalNodeSyncNotifier.value++;
}

class AppShell extends StatefulWidget {
  final AlertNotifier? alertNotifier;

  const AppShell({super.key, this.alertNotifier});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  late final AlertNotifier _alertNotifier;

  @override
  void initState() {
    super.initState();
    _alertNotifier = widget.alertNotifier ?? AlertNotifier(enablePolling: true);
    _alertNotifier.addListener(_onAlertStateChanged);
    globalNodeSyncNotifier.addListener(_onGlobalMutation);
  }

  void _onAlertStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onGlobalMutation() {
    if (mounted) {
      _alertNotifier.syncIncremental();
    }
  }

  @override
  void dispose() {
    globalNodeSyncNotifier.removeListener(_onGlobalMutation);
    _alertNotifier.removeListener(_onAlertStateChanged);
    if (widget.alertNotifier == null) {
      _alertNotifier.dispose();
    }
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      globalActiveTabNotifier.value = index;
      notifyGlobalNodeStateChanged();
    }
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

    final theme = Theme.of(context);
    final unreadCount = _alertNotifier.state.unreadCount;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
            tooltip: 'System Notifications',
            icon: unreadCount > 0
                ? Badge(
                    label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                    child: const Icon(Icons.notifications_outlined),
                  )
                : const Icon(Icons.notifications_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AlertsScreen(notifier: _alertNotifier),
                ),
              );
              if (mounted) {
                _alertNotifier.fetchAlerts();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: GlobalAlertOverlay(
          notifier: _alertNotifier,
          child: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.borderOf(context), width: 1),
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
