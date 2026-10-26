import 'package:aquaflow_frontend/features/auth/domain/models/auth_token.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_session.dart';
import 'package:aquaflow_frontend/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aquaflow_frontend/features/irrigation/data/repositories/irrigation_repository.dart';
import 'package:aquaflow_frontend/features/irrigation/domain/models/centralized_irrigation.dart';
import 'package:aquaflow_frontend/features/zones/data/repositories/zone_repository.dart';
import 'package:aquaflow_frontend/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Aqua Flow app shell smoke test when authenticated',
      (WidgetTester tester) async {
    final mockSession = UserSession(
      userId: 'usr_test',
      username: 'testop',
      email: 'test@aquaflow.io',
      role: 'Operator',
      token: AuthToken(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    final authNotifier = AuthNotifier();
    authNotifier.state = AuthState.authenticated(mockSession);

    await tester.pumpWidget(AquaFlowApp(authNotifier: authNotifier));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('ArvaLink'), findsOneWidget);
    expect(find.text('Autonomous Edge Irrigation'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Sensors'), findsWidgets);
    expect(find.text('Manual'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  test('MonitoringZone repository retrieves Q1–Q4 zones', () async {
    final repository = ZoneRepositoryImpl();
    final zones = await repository.fetchMonitoringZones();

    expect(zones.length, equals(4));
    expect(zones.map((z) => z.code), containsAll(['Q1', 'Q2', 'Q3', 'Q4']));
  });

  test('Irrigation repository manages centralized field system', () async {
    final repository = IrrigationRepositoryImpl();
    final initial = await repository.fetchSystemStatus();

    expect(initial.mainPumpState, equals(PumpState.idle));

    final updated = await repository.toggleMainPump(true);
    expect(updated.mainPumpState, equals(PumpState.active));
    expect(updated.flowRateLitersPerMin, greaterThan(0.0));
  });
}
