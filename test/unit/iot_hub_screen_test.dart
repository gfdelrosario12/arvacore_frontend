import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_role.dart';
import 'package:aquaflow_frontend/features/diagnostics/data/repositories/diagnostics_repository.dart';
import 'package:aquaflow_frontend/features/diagnostics/domain/models/models.dart';
import 'package:aquaflow_frontend/features/diagnostics/presentation/providers/diagnostics_provider.dart';
import 'package:aquaflow_frontend/features/iot_hub/presentation/screens/iot_hub_screen.dart';
import 'package:aquaflow_frontend/features/nodes/data/repositories/node_repository.dart';
import 'package:aquaflow_frontend/features/nodes/presentation/providers/node_management_notifier.dart';

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
  testWidgets('IotHubScreen renders navigation tabs and overview header', (tester) async {
    final diagNotifier = DiagnosticsNotifier(repository: const _ImmediateStubRepository());
    final nodeNotifier = NodeManagementNotifier(repository: MockNodeRepository());
    addTearDown(diagNotifier.dispose);
    addTearDown(nodeNotifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IotHubScreen(
            userRole: UserRole.admin,
            diagnosticsNotifier: diagNotifier,
            nodeNotifier: nodeNotifier,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Tab bar items exist
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Registry'), findsOneWidget);
    expect(find.text('Telemetry'), findsOneWidget);
    expect(find.text('Events & Logs'), findsOneWidget);

    // Verify Monitoring AppBar and Overview title
    expect(find.text('Monitoring'), findsOneWidget);
    expect(find.text('ArvaCore Monitoring Pipeline'), findsOneWidget);
    expect(find.text('All-Node Water Levels (Paddy Depth)'), findsOneWidget);
    expect(find.text('6 Agricultural Sensor Categories Telemetry Matrix'), findsOneWidget);
    expect(find.text('ArvaNode Fleet Connectivity'), findsOneWidget);
  });
}
