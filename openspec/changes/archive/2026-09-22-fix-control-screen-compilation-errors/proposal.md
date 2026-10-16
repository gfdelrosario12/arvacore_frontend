## Why

Following the removal of the standalone `ControlScreen` in favor of consolidated `ManualControlScreen`, residual imports and duplicate widget/navigation arguments were left behind in several UI screens and test files, causing Flutter compilation failures. This change resolves all syntax and import errors across the application and test suites.

## What Changes

- Clean up invalid imports of non-existent `lib/features/control/presentation/control_screen.dart`.
- Eliminate duplicated positional arguments and duplicated named arguments (`builder`, `child`, `push`) across UI screens (`app_shell.dart`, `alert_detail_screen.dart`, `device_detail_dialog.dart`, `zone_analysis_screen.dart`, `awd_analytics_screen.dart`, `manual_control_screen.dart`).
- Clean up test files (`responsive_validation_test.dart`, `control_screen_auto_irrigation_test.dart`, `central_control_test.dart`) to remove references to `ControlScreen` and target `ManualControlScreen`.

## Capabilities

### New Capabilities

*(None)*

### Modified Capabilities

*(None)*

## Impact

- **UI Screens**: `lib/features/shell/presentation/app_shell.dart`, `lib/features/alerts/presentation/alert_detail_screen.dart`, `lib/features/diagnostics/presentation/widgets/device_detail_dialog.dart`, `lib/features/zones/presentation/zone_analysis_screen.dart`, `lib/features/awd/presentation/awd_analytics_screen.dart`, `lib/features/irrigation/presentation/manual_control_screen.dart`.
- **Tests**: `test/responsive_validation_test.dart`, `test/unit/control_screen_auto_irrigation_test.dart`, `test/central_control_test.dart`.

