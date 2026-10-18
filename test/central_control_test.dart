import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/auth_token.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_role.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_session.dart';
import 'package:aquaflow_frontend/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aquaflow_frontend/features/control/data/repositories/control_repository.dart';
import 'package:aquaflow_frontend/features/control/domain/models/models.dart';
import 'package:aquaflow_frontend/features/irrigation/presentation/manual_control_screen.dart';
import 'package:aquaflow_frontend/features/control/presentation/providers/central_control_provider.dart';

void main() {
  group('Control Domain & Repository Unit Tests', () {
    late MockControlRepository repository;

    setUp(() {
      repository = MockControlRepository();
    });

    test('initializes central telemetry with ENTIRE FIELD target', () async {
      final telemetry = await repository.getCentralTelemetry();
      expect(telemetry.controllerId, equals('CTRL-FIELD-01'));
      expect(telemetry.controllerState, equals(CentralControllerState.online));
      expect(telemetry.target, equals(CentralControlTelemetry.fixedTarget));
      expect(telemetry.pumpStatus, equals(PumpStatus.off));
      expect(telemetry.valveStatus, equals(MainValveStatus.closed));
    });

    test('dispatches start irrigation command and updates hardware telemetry state', () async {
      final command = ControlCommand(
        id: 'CMD-TEST-01',
        type: CommandType.startIrrigation,
        durationMinutes: 45,
        timestamp: DateTime.now(),
        requestedBy: 'Tester',
        userRole: ControlUserRole.operator,
      );

      final result = await repository.dispatchCommand(command);
      expect(result.isSuccess, isTrue);
      expect(result.outcome, equals(CommandOutcome.acknowledged));

      final updated = await repository.getCentralTelemetry();
      expect(updated.pumpStatus, equals(PumpStatus.pumping));
      expect(updated.valveStatus, equals(MainValveStatus.open));
      expect(updated.irrigationState, equals(IrrigationState.irrigating));
      expect(updated.durationMinutes, equals(45));
    });

    test('dispatches stop irrigation command and resets hardware to idle', () async {
      // First start
      await repository.dispatchCommand(ControlCommand(
        id: 'CMD-START',
        type: CommandType.startIrrigation,
        durationMinutes: 30,
        timestamp: DateTime.now(),
        requestedBy: 'Tester',
        userRole: ControlUserRole.operator,
      ));

      // Then stop
      final result = await repository.dispatchCommand(ControlCommand(
        id: 'CMD-STOP',
        type: CommandType.stopIrrigation,
        durationMinutes: 0,
        timestamp: DateTime.now(),
        requestedBy: 'Tester',
        userRole: ControlUserRole.operator,
      ));

      expect(result.isSuccess, isTrue);
      expect(result.outcome, equals(CommandOutcome.completed));

      final updated = await repository.getCentralTelemetry();
      expect(updated.pumpStatus, equals(PumpStatus.off));
      expect(updated.valveStatus, equals(MainValveStatus.closed));
      expect(updated.irrigationState, equals(IrrigationState.idle));
    });

    test('rejects commands targeting invalid scope', () async {
      final invalidCommand = ControlCommand(
        id: 'CMD-INVALID',
        type: CommandType.startIrrigation,
        target: 'Q1 ZONE ONLY',
        durationMinutes: 30,
        timestamp: DateTime.now(),
        requestedBy: 'Tester',
        userRole: ControlUserRole.operator,
      );

      final result = await repository.dispatchCommand(invalidCommand);
      expect(result.isSuccess, isFalse);
      expect(result.outcome, equals(CommandOutcome.rejected));
      expect(result.message, contains('ENTIRE FIELD'));
    });

    test('rejects commands requested by unauthorized viewer role', () async {
      final unauthorizedCommand = ControlCommand(
        id: 'CMD-UNAUTH',
        type: CommandType.startIrrigation,
        durationMinutes: 30,
        timestamp: DateTime.now(),
        requestedBy: 'ViewerUser',
        userRole: ControlUserRole.viewer,
      );

      final result = await repository.dispatchCommand(unauthorizedCommand);
      expect(result.isSuccess, isFalse);
      expect(result.outcome, equals(CommandOutcome.rejected));
      expect(result.message, contains('Unauthorized'));
    });

    test('fails command dispatch when controller is offline', () async {
      repository.updateStateForTesting(CentralControlTelemetry(
        controllerId: 'CTRL-OFFLINE',
        controllerState: CentralControllerState.offline,
        pumpStatus: PumpStatus.off,
        valveStatus: MainValveStatus.closed,
        irrigationState: IrrigationState.error,
        flowRateLitersPerMin: 0.0,
        linePressureBar: 0.0,
        lastUpdated: DateTime.now(),
      ));

      final command = ControlCommand(
        id: 'CMD-OFFLINE',
        type: CommandType.startIrrigation,
        durationMinutes: 30,
        timestamp: DateTime.now(),
        requestedBy: 'Tester',
        userRole: ControlUserRole.operator,
      );

      final result = await repository.dispatchCommand(command);
      expect(result.isSuccess, isFalse);
      expect(result.outcome, equals(CommandOutcome.failed));
      expect(result.message, contains('OFFLINE'));
    });
  });

  group('CentralControlNotifier Unit Tests', () {
    late MockControlRepository repository;
    late CentralControlNotifier notifier;

    setUp(() {
      repository = MockControlRepository();
      notifier = CentralControlNotifier(repository: repository);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('updates user role', () {
      notifier.setUserRole(ControlUserRole.admin);
      expect(notifier.state.userRole, equals(ControlUserRole.admin));
    });

    test('executes start irrigation flow through notifier', () async {
      await notifier.loadTelemetry();
      final resultFuture = notifier.startIrrigation(
        durationMinutes: 60,
        requestedBy: 'Operator',
      );

      expect(notifier.state.isCommandPending, isTrue);

      final result = await resultFuture;
      expect(result.isSuccess, isTrue);
      expect(notifier.state.isCommandPending, isFalse);
      expect(notifier.state.telemetry?.irrigationState, equals(IrrigationState.irrigating));
    });
  });

  group('ManualControlScreen Widget Tests', () {
    setUp(() {
      // Authenticate as operator to see control buttons
      final operatorToken = AuthToken(
        accessToken: 'test_access',
        refreshToken: 'test_refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        fieldId: 'field_test',
        role: UserRole.operator,
      );
      final operatorSession = UserSession(
        userId: 'test_operator',
        username: 'test_operator',
        email: 'test@operator.com',
        role: 'Operator',
        token: operatorToken,
      );
      globalAuthNotifier.state = AuthState.authenticated(operatorSession);
    });

    tearDown(() {
      // Reset auth state without calling secure storage
      globalAuthNotifier.state = AuthState.unauthenticated();
    });

    testWidgets('renders ManualControlScreen with target badge and actions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManualControlScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Manual Control'), findsOneWidget);
      expect(find.text('TARGET: ENTIRE FIELD'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Stop'), findsOneWidget);
    });
  });
}
