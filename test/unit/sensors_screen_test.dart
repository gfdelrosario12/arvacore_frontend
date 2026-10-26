import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/control/domain/models/control_enums.dart';
import 'package:aquaflow_frontend/features/diagnostics/data/repositories/diagnostics_repository.dart';
import 'package:aquaflow_frontend/features/diagnostics/domain/models/models.dart';
import 'package:aquaflow_frontend/features/diagnostics/presentation/providers/diagnostics_provider.dart';
import 'package:aquaflow_frontend/features/nodes/data/repositories/node_repository.dart';
import 'package:aquaflow_frontend/features/nodes/presentation/providers/node_management_notifier.dart';
import 'package:aquaflow_frontend/features/sensors/presentation/screens/sensors_screen.dart';

class _ImmediateStubRepository implements DiagnosticsRepository {
  const _ImmediateStubRepository();

  @override
  Future<List<DeviceDiagnostic>> fetchDeviceDiagnostics() async => [];

  @override
  Future<DeviceDiagnostic?> fetchDeviceById(String id) async => null;

  @override
  Stream<List<DeviceDiagnostic>> watchDeviceDiagnostics() => const Stream.empty();
}

void main() {
  testWidgets('SensorsScreen renders unified tabs and 4 core sections', (tester) async {
    final diagNotifier = DiagnosticsNotifier(repository: const _ImmediateStubRepository());
    final nodeNotifier = NodeManagementNotifier(repository: MockNodeRepository());
    addTearDown(diagNotifier.dispose);
    addTearDown(nodeNotifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SensorsScreen(
            userRole: ControlUserRole.admin,
            diagnosticsNotifier: diagNotifier,
            nodeNotifier: nodeNotifier,
          ),
        ),
      ),
    );

    // Pump frames to let mock data settle
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Verify 4 unified sub-tabs exist
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Field Map'), findsOneWidget);
    expect(find.text('Monitoring Nodes'), findsOneWidget);
    expect(find.text('Measurements'), findsOneWidget);

    // Verify Sensors AppBar title
    expect(find.text('Sensors'), findsOneWidget);

    // Verify Overview content
    expect(find.text('Unified Sensors Overview'), findsOneWidget);
    expect(find.text('Monitoring Fleet Connectivity'), findsOneWidget);
    expect(find.text('All-Node Water Levels (Paddy Depth)'), findsOneWidget);
  });
}
