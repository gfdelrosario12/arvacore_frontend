import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_role.dart';
import 'package:aquaflow_frontend/features/diagnostics/data/repositories/diagnostics_repository.dart';
import 'package:aquaflow_frontend/features/diagnostics/domain/models/models.dart';
import 'package:aquaflow_frontend/features/diagnostics/presentation/providers/diagnostics_provider.dart';
import 'package:aquaflow_frontend/features/iot_hub/presentation/screens/iot_hub_screen.dart';

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
    final notifier = DiagnosticsNotifier(repository: const _ImmediateStubRepository());
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IotHubScreen(
            userRole: UserRole.admin,
            diagnosticsNotifier: notifier,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Tab bar items exist
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Registry'), findsOneWidget);
    expect(find.text('Telemetry'), findsOneWidget);
    expect(find.text('Events & Logs'), findsOneWidget);

    // Verify Overview title
    expect(find.text('ArvaCore IoT Pipeline'), findsOneWidget);
    expect(find.text('ArvaNode Fleet Connectivity'), findsOneWidget);
  });
}
