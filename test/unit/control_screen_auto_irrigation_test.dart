import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/auth_token.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_role.dart';
import 'package:aquaflow_frontend/features/auth/domain/models/user_session.dart';
import 'package:aquaflow_frontend/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aquaflow_frontend/features/irrigation/presentation/manual_control_screen.dart';
import 'package:aquaflow_frontend/features/irrigation/data/datasources/irrigation_data_source.dart';
import 'package:aquaflow_frontend/features/irrigation/data/repositories/irrigation_repository.dart';
import 'package:aquaflow_frontend/features/irrigation/domain/models/auto_irrigation_config.dart';
import 'package:aquaflow_frontend/features/irrigation/domain/models/auto_irrigation_status.dart';
import 'package:aquaflow_frontend/features/irrigation/domain/models/centralized_irrigation.dart';
import 'package:aquaflow_frontend/features/irrigation/domain/models/irrigation_execution_audit_log.dart';
import 'package:aquaflow_frontend/features/irrigation/domain/models/manual_irrigation_control.dart';
import 'package:aquaflow_frontend/features/irrigation/presentation/providers/irrigation_notifier.dart';

void main() {
  group('ControlScreen automatic irrigation UI', () {
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

    testWidgets('renders automation supervisor badge and disabled banner',
        (tester) async {
      final irrigationNotifier = IrrigationNotifier(
        repository: IrrigationRepositoryImpl(
          dataSource: MockIrrigationDataSource(),
        ),
        initialConfig: const AutoIrrigationConfig(isEnabled: false),
        initialStatus: const AutoIrrigationStatus(
          state: AutoIrrigationState.disabled,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualControlScreen(
              irrigationNotifier: irrigationNotifier,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Automation Supervisor'), findsOneWidget);
      expect(find.text('DISABLED'), findsOneWidget);
      expect(
        find.textContaining('Field automation is currently disabled'),
        findsOneWidget,
      );
      expect(find.text('Configure'), findsOneWidget);
    });

    testWidgets('opens Auto-Irrigation Settings config modal', (tester) async {
      final irrigationNotifier = IrrigationNotifier(
        repository: IrrigationRepositoryImpl(
          dataSource: MockIrrigationDataSource(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualControlScreen(
              irrigationNotifier: irrigationNotifier,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Configure'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configure'));
      await tester.pumpAndSettle();

      expect(find.text('Auto-Irrigation Settings'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('displays cooldown banner when supervisor is cooling down',
        (tester) async {
      final fake = _FakeIrrigationRepository(
        config: const AutoIrrigationConfig(
          systemId: 'sys-field-01',
          isEnabled: true,
        ),
        status: AutoIrrigationStatus(
          systemId: 'sys-field-01',
          state: AutoIrrigationState.cooldown,
          cooldownUntil: DateTime.now().add(const Duration(minutes: 45)),
        ),
        logs: const [],
      );

      final irrigationNotifier = IrrigationNotifier(
        repository: fake,
        initialConfig: fake.config,
        initialStatus: fake.status,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualControlScreen(
              irrigationNotifier: irrigationNotifier,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COOLDOWN'), findsOneWidget);
      expect(find.textContaining('Cooldown Active'), findsWidgets);
    });

    testWidgets('audit history distinguishes System (Auto-AWD) vs Operator',
        (tester) async {
      final now = DateTime.now();
      final fake = _FakeIrrigationRepository(
        config: const AutoIrrigationConfig(isEnabled: false),
        status: const AutoIrrigationStatus(
          state: AutoIrrigationState.disabled,
        ),
        logs: [
          IrrigationExecutionAuditLog(
            id: 'log-sys',
            actor: IrrigationActor.systemAutoAwd,
            action: 'start',
            triggerContext: 'AWD Reflood',
            outcome: 'completed',
            timestamp: now.subtract(const Duration(hours: 2)),
          ),
          IrrigationExecutionAuditLog(
            id: 'log-op',
            actor: IrrigationActor.operator(id: 'op-01', name: 'Maria Santos'),
            action: 'stop',
            triggerContext: 'Manual stop',
            outcome: 'completed',
            timestamp: now.subtract(const Duration(hours: 1)),
          ),
        ],
      );

      final irrigationNotifier = IrrigationNotifier(
        repository: fake,
        initialConfig: fake.config,
        initialStatus: fake.status,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualControlScreen(
              irrigationNotifier: irrigationNotifier,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Irrigation Audit History'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == 'System (Auto-Irrigation)' ||
                  w.data == 'System (Auto-AWD)'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Operator:'), findsOneWidget);
      expect(find.textContaining('Maria Santos'), findsOneWidget);
    });

    testWidgets('shows fault lockout banner and clear lockout action',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const SizedBox()); // Apply view size

      final fake = _FakeIrrigationRepository(
        config: const AutoIrrigationConfig(isEnabled: true),
        status: AutoIrrigationStatus(
          state: AutoIrrigationState.faultLocked,
          lockoutReason: 'ACK timeout after 2 retries',
          lockoutTimestamp: DateTime.now(),
        ),
        logs: const [],
      );

      final irrigationNotifier = IrrigationNotifier(
        repository: fake,
        initialConfig: fake.config,
        initialStatus: fake.status,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualControlScreen(
              irrigationNotifier: irrigationNotifier,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FAULT LOCKED'), findsOneWidget);
      expect(find.textContaining('Lockout:'), findsOneWidget);
      expect(find.text('Clear Lockout'), findsWidgets);
    });
  });
}

class _FakeIrrigationRepository implements IrrigationRepository {
  AutoIrrigationConfig config;
  AutoIrrigationStatus status;
  List<IrrigationExecutionAuditLog> logs;

  _FakeIrrigationRepository({
    required this.config,
    required this.status,
    required this.logs,
  });

  @override
  Future<AutoIrrigationConfig> getAutoIrrigationConfig({
    String systemId = 'default',
  }) async =>
      config;

  @override
  Future<AutoIrrigationConfig> updateAutoIrrigationConfig(
    AutoIrrigationConfig newConfig,
  ) async {
    config = newConfig;
    return config;
  }

  @override
  Future<AutoIrrigationStatus> getAutoIrrigationStatus({
    String systemId = 'default',
  }) async =>
      status;

  @override
  Future<AutoIrrigationStatus> clearFaultLockout({
    String systemId = 'default',
    String? resolutionNote,
    String? clearedBy,
  }) async {
    status = status.copyWith(
      state: config.isEnabled
          ? AutoIrrigationState.standby
          : AutoIrrigationState.disabled,
      lockoutReason: null,
      lockoutTimestamp: null,
    );
    return status;
  }

  @override
  Future<List<IrrigationExecutionAuditLog>> getAuditLogs({
    String systemId = 'default',
    int limit = 50,
  }) async =>
      logs.take(limit).toList();

  @override
  Future<void> logExecution(IrrigationExecutionAuditLog log) async {
    logs = [log, ...logs];
  }

  @override
  Future<CentralizedIrrigation> fetchSystemStatus() {
    throw UnimplementedError();
  }

  @override
  Future<CentralizedIrrigation> toggleMainPump(bool active) {
    throw UnimplementedError();
  }

  @override
  Future<CentralizedIrrigation> updateSystemMode(SystemMode mode) {
    throw UnimplementedError();
  }

  @override
  Future<bool> dispatchManualStart(ManualIrrigationCommand command) async => true;

  @override
  Future<bool> dispatchManualStop({required String operatorId, String? rationale}) async => true;

  @override
  Future<bool> dispatchEmergencyStop({required String operatorId, String? rationale}) async => true;
}
