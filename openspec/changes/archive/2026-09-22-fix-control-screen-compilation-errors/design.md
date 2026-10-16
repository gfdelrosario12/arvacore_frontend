## Implementation Design

### 1. `AppShell` (`lib/features/shell/presentation/app_shell.dart`)
- Remove `import '../../control/presentation/control_screen.dart';`.
- Remove `AppStrings.navControl` return case in `_getAppBarTitle`.
- Update `screens` list to 4 screens: `HomeScreen`, `FieldScreen`, `ManualControlScreen`, `SettingsScreen`.
- Update `BottomNavigationBar` items to 4 items: Home, Field, Manual Control, Settings.

### 2. `AlertDetailScreen` (`lib/features/alerts/presentation/alert_detail_screen.dart`)
- Remove `import '../../control/presentation/control_screen.dart';`.
- Remove unreachable `'Open Control Screen';` return line in `_getActionLabel()`.
- Fix `_handleActionNavigation` to pass a single `MaterialPageRoute` pushing `const ManualControlScreen()`.

### 3. `DeviceDetailDialog` (`lib/features/diagnostics/presentation/widgets/device_detail_dialog.dart`)
- Remove `import '../../../control/presentation/control_screen.dart';`.
- Fix `Navigator.of(context).push` call to pass a single `MaterialPageRoute(builder: (context) => const ManualControlScreen())`.
- Remove duplicated `child: const Text('Open Control Screen')`.

### 4. `ZoneAnalysisScreen` (`lib/features/zones/presentation/zone_analysis_screen.dart`)
- Remove `import '../../control/presentation/control_screen.dart';`.
- Fix `MaterialPageRoute` builder argument to `builder: (context) => const ManualControlScreen()`.

### 5. `AwdAnalyticsScreen` (`lib/features/awd/presentation/awd_analytics_screen.dart`)
- Remove `import '../../control/presentation/control_screen.dart';`.
- Fix `MaterialPageRoute` builder argument to `builder: (context) => const ManualControlScreen()`.

### 6. `ManualControlScreen` (`lib/features/irrigation/presentation/manual_control_screen.dart`)
- Remove duplicate positional string argument in `Text(...)` header widget.

### 7. Test Suite Updates
- Clean up duplicate `ControlScreen` imports and invocations in `test/responsive_validation_test.dart`, `test/unit/control_screen_auto_irrigation_test.dart`, and `test/central_control_test.dart`.

