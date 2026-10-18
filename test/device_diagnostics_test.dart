import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/diagnostics/data/repositories/diagnostics_repository.dart';
import 'package:aquaflow_frontend/features/diagnostics/domain/models/models.dart';
import 'package:aquaflow_frontend/features/diagnostics/presentation/device_diagnostics_screen.dart';
import 'package:aquaflow_frontend/features/diagnostics/presentation/providers/diagnostics_provider.dart';

void main() {
  group('Diagnostics repository and notifier', () {
    test('provides four read-only nodes, one gateway, and one controller', () async {
      final devices = await MockDiagnosticsRepository().fetchDeviceDiagnostics();

      expect(devices.where((device) => device.category == DeviceCategory.sensorNode), hasLength(4));
      expect(devices.where((device) => device.category == DeviceCategory.gateway), hasLength(1));
      expect(devices.where((device) => device.category == DeviceCategory.centralController), hasLength(1));
      expect(devices.where((device) => device.category == DeviceCategory.sensorNode).every((device) => device.targetScope.startsWith('Q')), isTrue);
      expect(devices.singleWhere((device) => device.category == DeviceCategory.centralController).targetScope, 'ENTIRE FIELD');
    });

    test('tracks standardized health counts and category filters', () async {
      final notifier = DiagnosticsNotifier();
      addTearDown(notifier.dispose);

      await notifier.fetchDiagnostics();

      expect(notifier.state.healthyCount, 4);
      expect(notifier.state.warningCount, 2);
      expect(notifier.state.errorCount, 0);
      notifier.setCategoryFilter(DeviceCategory.sensorNode);
      expect(notifier.state.filteredDevices, hasLength(4));
    });
  });

  group('DeviceDiagnosticsScreen', () {
    testWidgets('renders all hardware sections and diagnostic metrics', (tester) async {
      final notifier = DiagnosticsNotifier();
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(home: DeviceDiagnosticsScreen(key: const ValueKey('normal'), notifier: notifier)),
      );
      await tester.pumpAndSettle();

      expect(find.text('System Health Overview'), findsOneWidget);
      expect(find.text('Quadrant Q1 ArvaNode'), findsOneWidget);
      expect(find.text('Quadrant Q4 ArvaNode'), findsOneWidget);
      expect(find.text('ArvaNet Internet Gateway & Field Base Station'), findsOneWidget);
      expect(find.text('ArvaCore Automated Irrigation & Pump Controller'), findsOneWidget);
      expect(find.text('Uplink'), findsOneWidget);
      expect(find.text('Last command'), findsOneWidget);
    });

    testWidgets('keeps monitoring node details read-only', (tester) async {
      final notifier = DiagnosticsNotifier();
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(home: DeviceDiagnosticsScreen(key: const ValueKey('node'), notifier: notifier)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quadrant Q1 ArvaNode'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Read-only telemetry node'), findsOneWidget);
      expect(find.text('Open Control Screen'), findsNothing);
    });

    testWidgets('renders empty and error states', (tester) async {
      final emptyNotifier = DiagnosticsNotifier(repository: _StubRepository(const []));
      await tester.pumpWidget(
        MaterialApp(home: DeviceDiagnosticsScreen(key: const ValueKey('empty'), notifier: emptyNotifier)),
      );
      await tester.pumpAndSettle();
      expect(find.text('No Devices Registered'), findsOneWidget);
      emptyNotifier.dispose();

      final errorNotifier = DiagnosticsNotifier(repository: _StubRepository(const [], shouldThrow: true));
      await tester.pumpWidget(
        MaterialApp(home: DeviceDiagnosticsScreen(key: const ValueKey('error'), notifier: errorNotifier)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Telemetry Connection Error'), findsOneWidget);
      errorNotifier.dispose();
    });
  });
}

class _StubRepository implements DiagnosticsRepository {
  final List<DeviceDiagnostic> devices;
  final bool shouldThrow;

  const _StubRepository(this.devices, {this.shouldThrow = false});

  @override
  Future<List<DeviceDiagnostic>> fetchDeviceDiagnostics() async {
    if (shouldThrow) throw Exception('gateway unavailable');
    return devices;
  }

  @override
  Future<DeviceDiagnostic?> fetchDeviceById(String id) async => null;

  @override
  Stream<List<DeviceDiagnostic>> watchDeviceDiagnostics() => const Stream.empty();
}