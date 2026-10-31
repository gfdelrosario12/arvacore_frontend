import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/arva_logo.dart';
import '../../alerts/presentation/alerts_screen.dart';
import '../../alerts/presentation/providers/alert_provider.dart';
import '../../alerts/presentation/widgets/global_alert_overlay.dart';
import '../../analytics/presentation/system_evaluation_dashboard_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../irrigation/presentation/manual_control_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../sensors/presentation/screens/sensors_screen.dart';
import '../../farming_chat/presentation/farming_chatbot_screen.dart';

/// Global revision notifier triggered whenever any screen mutates node pairing,
/// zone assignment, or field topology so all tabs synchronize immediately.
final ValueNotifier<int> globalNodeSyncNotifier = ValueNotifier<int>(0);

/// Index of the Home tab inside the shell navigation.
const int homeTabIndex = 0;

/// Notifies the screens about the tab that is currently visible.
final ValueNotifier<int> globalActiveTabNotifier = ValueNotifier<int>(
  homeTabIndex,
);

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
  bool _isSidebarCollapsed = false;
  late final AlertNotifier _alertNotifier;

  final List<_NavigationDestinationItem> _destinations = const [
    _NavigationDestinationItem(
      label: AppStrings.navHome,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _NavigationDestinationItem(
      label: AppStrings.navAiAssistant,
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
    ),
    _NavigationDestinationItem(
      label: AppStrings.navSensors,
      icon: Icons.sensors_outlined,
      selectedIcon: Icons.sensors,
    ),
    _NavigationDestinationItem(
      label: AppStrings.navManualControl,
      icon: Icons.touch_app_outlined,
      selectedIcon: Icons.touch_app,
    ),
    _NavigationDestinationItem(
      label: AppStrings.navResearch,
      icon: Icons.science_outlined,
      selectedIcon: Icons.science,
    ),
    _NavigationDestinationItem(
      label: AppStrings.navSettings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _alertNotifier = widget.alertNotifier ?? AlertNotifier(enablePolling: true);
    _alertNotifier.addListener(_onAlertStateChanged);
    globalNodeSyncNotifier.addListener(_onGlobalMutation);
  }

  void _onAlertStateChanged() {
    if (mounted) setState(() {});
  }

  void _onGlobalMutation() {
    if (mounted) _alertNotifier.syncIncremental();
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
    if (index >= 0 && index < _destinations.length) {
      return _destinations[index].label;
    }
    return AppStrings.appTitle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppDimensions.breakpointTablet;
    final isTablet =
        width >= AppDimensions.breakpointMobile &&
        width < AppDimensions.breakpointTablet;
    final unreadCount = _alertNotifier.state.unreadCount;

    final List<Widget> screens = [
      HomeScreen(
        onNavigateToControl: () => _onTabSelected(3),
        onNavigateToField: () => _onTabSelected(2),
        onNavigateToAi: () => _onTabSelected(1),
      ),
      const FarmingChatbotScreen(),
      SensorsScreen(
        onNavigateToControl: () => _onTabSelected(3),
        onNavigateToAi: (prompt) => _onTabSelected(1),
      ),
      const ManualControlScreen(),
      const SystemEvaluationDashboardScreen(),
      const SettingsScreen(),
    ];

    final appBarActions = [
      IconButton(
        icon: const Icon(Icons.sensors_outlined),
        tooltip: 'ArvaCore Sensors & Field',
        onPressed: () => _onTabSelected(2),
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
      const SizedBox(width: AppDimensions.spaceSm),
    ];

    if (isDesktop) {
      // Purpose-Built Desktop/Web Experience: Sidebar Navigation with Content Viewport
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: GlobalAlertOverlay(
          notifier: _alertNotifier,
          child: Row(
            children: [
              _buildDesktopSidebar(theme),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: Column(
                  children: [
                    _buildDesktopTopBar(theme, appBarActions),
                    const Divider(height: 1, thickness: 1),
                    Expanded(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: screens,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (isTablet) {
      // Tablet Navigation Rail Experience
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(_getAppBarTitle(_currentIndex)),
          actions: appBarActions,
        ),
        body: GlobalAlertOverlay(
          notifier: _alertNotifier,
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onTabSelected,
                labelType: NavigationRailLabelType.selected,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: ArvaLogo(size: 28),
                ),
                destinations: _destinations.map((d) {
                  return NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label, style: const TextStyle(fontSize: 11)),
                  );
                }).toList(),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: IndexedStack(index: _currentIndex, children: screens),
              ),
            ],
          ),
        ),
      );
    } else {
      // Mobile-First Bottom Navigation Bar Experience
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(_getAppBarTitle(_currentIndex)),
          actions: appBarActions,
        ),
        body: SafeArea(
          child: GlobalAlertOverlay(
            notifier: _alertNotifier,
            child: IndexedStack(index: _currentIndex, children: screens),
          ),
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            final isVeryNarrow = constraints.maxWidth < 420;
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.borderOf(context), width: 1),
                ),
              ),
              child: isVeryNarrow
                  ? _buildScrollableMobileTabBar(theme)
                  : BottomNavigationBar(
                      type: BottomNavigationBarType.fixed,
                      currentIndex: _currentIndex,
                      onTap: _onTabSelected,
                      items: _destinations.map((d) {
                        return BottomNavigationBarItem(
                          icon: Icon(d.icon),
                          activeIcon: Icon(d.selectedIcon),
                          label: d.label,
                        );
                      }).toList(),
                    ),
            );
          },
        ),
      );
    }
  }

  Widget _buildDesktopSidebar(ThemeData theme) {
    final sidebarWidth = _isSidebarCollapsed
        ? AppDimensions.webRailWidth
        : AppDimensions.webSidebarWidth;

    return Material(
      color: theme.colorScheme.surface,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _isSidebarCollapsed ? 12 : 20,
                vertical: 16,
              ),
              child: Row(
                mainAxisAlignment: _isSidebarCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.spaceBetween,
                children: [
                  if (_isSidebarCollapsed)
                    IconButton(
                      icon: const ArvaLogo(size: 28),
                      tooltip: 'Expand Navigation (ArvaCore)',
                      onPressed: () => setState(() => _isSidebarCollapsed = false),
                    )
                  else ...[
                    const ArvaLogo(size: 32),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ArvaCore',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Smart Irrigation & AI Decision',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      tooltip: 'Collapse sidebar',
                      onPressed: () => setState(() => _isSidebarCollapsed = true),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            if (!_isSidebarCollapsed) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'FARM MANAGEMENT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: theme.hintColor,
                  ),
                ),
              ),
            ],
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: _isSidebarCollapsed ? 8 : 8,
                  vertical: 4,
                ),
                itemCount: _destinations.length,
                separatorBuilder: (_, index) {
                  if (index == 3 && !_isSidebarCollapsed) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Text(
                        'SYSTEM & CONTROLS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: theme.hintColor,
                        ),
                      ),
                    );
                  }
                  return const SizedBox(height: 2);
                },
                itemBuilder: (context, index) {
                  final d = _destinations[index];
                  final isSelected = _currentIndex == index;
                  final itemColor = isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent;

                  if (_isSidebarCollapsed) {
                    return Tooltip(
                      message: d.label,
                      preferBelow: false,
                      child: InkWell(
                        onTap: () => _onTabSelected(index),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: itemColor,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Icon(
                            isSelected ? d.selectedIcon : d.icon,
                            size: 22,
                            color: isSelected ? AppColors.primary : theme.iconTheme.color,
                          ),
                        ),
                      ),
                    );
                  }

                  return Material(
                    color: itemColor,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusSm,
                        ),
                      ),
                      leading: Icon(
                        isSelected ? d.selectedIcon : d.icon,
                        size: 20,
                        color: isSelected
                            ? AppColors.primary
                            : theme.iconTheme.color,
                      ),
                      title: Text(
                        d.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                      onTap: () => _onTabSelected(index),
                    ),
                  );
                },
              ),
            ),
            if (!_isSidebarCollapsed)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zero Direct Actuation',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Safety Interlocks Active',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    tooltip: 'Expand navigation sidebar',
                    onPressed: () => setState(() => _isSidebarCollapsed = false),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar(ThemeData theme, List<Widget> actions) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(
              _getAppBarTitle(_currentIndex),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMd),
          ...actions,
        ],
      ),
    );
  }

  Widget _buildScrollableMobileTabBar(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_destinations.length, (index) {
          final d = _destinations[index];
          final isSelected = _currentIndex == index;
          return InkWell(
            onTap: () => _onTabSelected(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              constraints: const BoxConstraints(minWidth: 64),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? d.selectedIcon : d.icon,
                    size: 22,
                    color: isSelected
                        ? AppColors.primary
                        : theme.bottomNavigationBarTheme.unselectedItemColor ??
                              Colors.grey,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : theme
                                    .bottomNavigationBarTheme
                                    .unselectedItemColor ??
                                Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavigationDestinationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavigationDestinationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
