import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/core/config/iot_simulation_mode.dart';
import 'package:aquaflow_frontend/features/audit/data/repositories/account_audit_repository.dart';
import 'package:aquaflow_frontend/features/audit/domain/models/audit_result.dart';
import 'package:aquaflow_frontend/features/irrigation/data/repositories/irrigation_repository.dart';
import 'package:aquaflow_frontend/features/irrigation/domain/models/manual_irrigation_control.dart';
import 'package:aquaflow_frontend/features/irrigation/presentation/providers/manual_control_notifier.dart';

void main() {
  group('ManualIrrigationCommand Domain Model Tests', () {
    test('Default target scope is strictly ENTIRE FIELD', () {
      final cmd = ManualIrrigationCommand(
        commandId: 'cmd-01',
        durationMinutes: 30,
        action: 'start',
        operatorId: 'op-01',
        operatorName: 'Operator One',
      );

      expect(cmd.targetScope, equals('ENTIRE FIELD'));
    });

    test('Accepts valid field-wide target scope variations', () {
      final cmd1 = ManualIrrigationCommand(
        commandId: 'cmd-01',
        targetScope: 'ENTIRE FIELD',
        durationMinutes: 30,
        action: 'start',
        operatorId: 'op-01',
        operatorName: 'Operator One',
      );
      final cmd2 = ManualIrrigationCommand(
        commandId: 'cmd-02',
        targetScope: 'ENTIRE_FIELD',
        durationMinutes: 30,
        action: 'start',
        operatorId: 'op-02',
        operatorName: 'Operator Two',
      );

      expect(cmd1.targetScope, equals('ENTIRE FIELD'));
      expect(cmd2.targetScope, equals('ENTIRE_FIELD'));
    });

    test('Throws ArgumentError when given non-field target scope like Q1 or NODE-01', () {
      expect(
        () => ManualIrrigationCommand(
          commandId: 'cmd-err',
          targetScope: 'Q1',
          durationMinutes: 30,
          action: 'start',
          operatorId: 'op-01',
          operatorName: 'Operator One',
        ),
        throwsArgumentError,
      );

      expect(
        () => ManualIrrigationCommand(
          commandId: 'cmd-err2',
          targetScope: 'NODE-01',
          durationMinutes: 30,
          action: 'start',
          operatorId: 'op-01',
          operatorName: 'Operator One',
        ),
        throwsArgumentError,
      );
    });

    test('JSON serialization and deserialization roundtrip', () {
      final now = DateTime.now();
      final original = ManualIrrigationCommand(
        commandId: 'cmd-json-1',
        durationMinutes: 45,
        action: 'start',
        rationale: 'Canal maintenance flush',
        operatorId: 'usr-100',
        operatorName: 'Maria Santos',
        timestamp: now,
      );

      final json = original.toJson();
      final restored = ManualIrrigationCommand.fromJson(json);

      expect(restored.commandId, equals('cmd-json-1'));
      expect(restored.targetScope, equals('ENTIRE FIELD'));
      expect(restored.durationMinutes, equals(45));
      expect(restored.action, equals('start'));
      expect(restored.rationale, equals('Canal maintenance flush'));
      expect(restored.operatorId, equals('usr-100'));
      expect(restored.operatorName, equals('Maria Santos'));
    });
  });

  group('ManualControlNotifier State Machine & Authorization Tests', () {
    late ManualControlNotifier notifier;
    late MockAccountAuditRepository mockAuditRepo;

    setUp(() {
      mockAuditRepo = MockAccountAuditRepository();
      notifier = ManualControlNotifier(
        irrigationRepository: IrrigationRepositoryImpl(),
        auditRepository: mockAuditRepo,
      );
    });

    test('Rejects manual start for unauthorized role viewer', () async {
      final success = await notifier.startManualIrrigation(
        operatorId: 'usr-viewer',
        operatorName: 'Viewer User',
        operatorRole: 'viewer',
        durationMinutes: 30,
      );

      expect(success, isFalse);
      expect(notifier.state.errorMessage, contains('Unauthorized'));
      expect(notifier.state.modeState, equals(ManualOverrideModeState.idle));

      // Verify audit log emitted denial
      final events = await mockAuditRepo.fetchAuditEvents(limit: 5);
      expect(events.first.action, equals('irrigation.manual.start_denied'));
      expect(events.first.result, equals(AuditResult.denied));
    });

    test('Dispatches manual start for operator role, updating state machine and audit log', () async {
      final success = await notifier.startManualIrrigation(
        operatorId: 'usr-op-01',
        operatorName: 'Operator Juan',
        operatorRole: 'operator',
        durationMinutes: 45,
        rationale: 'Emergency field pulse',
      );

      expect(success, isTrue);
      expect(notifier.state.modeState, equals(ManualOverrideModeState.active));
      expect(notifier.state.targetDurationMinutes, equals(45));
      expect(notifier.state.activeCommand?.targetScope, equals('ENTIRE FIELD'));

      final events = await mockAuditRepo.fetchAuditEvents(limit: 5);
      expect(events.first.action, equals('irrigation.manual.start'));
      expect(events.first.result, equals(AuditResult.success));
      expect(events.first.target.id, equals('ENTIRE FIELD'));
    });

    test('Dispatches manual stop and transitions to cooldown', () async {
      await notifier.startManualIrrigation(
        operatorId: 'usr-op-01',
        operatorName: 'Operator Juan',
        operatorRole: 'operator',
        durationMinutes: 30,
      );

      final stopped = await notifier.stopManualIrrigation(
        operatorId: 'usr-op-01',
        operatorName: 'Operator Juan',
        operatorRole: 'operator',
        rationale: 'Inspection completed',
      );

      expect(stopped, isTrue);
      expect(notifier.state.modeState, equals(ManualOverrideModeState.cooldown));
      expect(notifier.state.cooldownUntil, isNotNull);

      final events = await mockAuditRepo.fetchAuditEvents(limit: 5);
      expect(events.first.action, equals('irrigation.manual.stop'));
      expect(events.first.result, equals(AuditResult.success));
    });

    test('Triggers uninhibited Emergency Stop interlock', () async {
      final ok = await notifier.triggerEmergencyStop(
        operatorId: 'usr-op-01',
        operatorName: 'Operator Juan',
        operatorRole: 'operator',
        rationale: 'Pipe leak detected',
      );

      expect(ok, isTrue);
      expect(notifier.state.modeState, equals(ManualOverrideModeState.emergencyStopped));

      final events = await mockAuditRepo.fetchAuditEvents(limit: 5);
      expect(events.first.action, equals('irrigation.emergency.stop'));
      expect(events.first.result, equals(AuditResult.success));
    });

    test('Resets cooldown to idle after cooldown period elapses', () {
      final past = DateTime.now().subtract(const Duration(minutes: 10));
      final testState = ManualControlState(
        modeState: ManualOverrideModeState.cooldown,
        cooldownUntil: past,
      );

      final testNotifier = ManualControlNotifier(
        initialState: testState,
        auditRepository: mockAuditRepo,
      );

      testNotifier.checkCooldownStatus();
      expect(testNotifier.state.modeState, equals(ManualOverrideModeState.idle));
      expect(testNotifier.state.cooldownUntil, isNull);
    });

    test('IoT Workflow Simulation Mode intercepts hardware execution and returns simulation confirmation', () async {
      globalIotTestModeNotifier.value = true;
      try {
        final success = await notifier.startManualIrrigation(
          operatorId: 'usr-op-01',
          operatorName: 'Operator Juan',
          operatorRole: 'operator',
          durationMinutes: 45,
          rationale: 'Simulation test start',
        );

        expect(success, isTrue);
        expect(notifier.state.modeState, equals(ManualOverrideModeState.active));
        expect(notifier.state.isSimulatedActive, isTrue);
        expect(
          notifier.state.simulationNotice,
          contains('Workflow Test Passed — Irrigation activation was processed successfully in simulation mode'),
        );

        final events = await mockAuditRepo.fetchAuditEvents(limit: 5);
        expect(events.first.action, equals('irrigation.manual.start_simulated'));
        expect(events.first.result, equals(AuditResult.success));
        expect(events.first.metadata.rationale, contains('[SIMULATION]'));
      } finally {
        globalIotTestModeNotifier.value = false;
      }
    });
  });
}

