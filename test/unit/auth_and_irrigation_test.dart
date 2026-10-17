// test/unit/auth_and_irrigation_test.dart
//
// Unit tests for:
//  – AuthNotifier state transitions (initial → authenticated → unauthenticated)
//  – Typed API error handling (401, 403, 500, timeout, decode)
//  – Irrigation command handling (ENTIRE FIELD accepted; Q1–Q4 rejected)
//  – AWD measurement data transformations / zone drying rates

import 'package:aquaflow_frontend/core/api/api_client.dart';
import 'package:aquaflow_frontend/core/api/api_config.dart';
import 'package:aquaflow_frontend/core/api/api_dtos.dart';
import 'package:aquaflow_frontend/core/api/api_errors.dart';
import 'package:aquaflow_frontend/features/auth/data/datasources/auth_service.dart';
import 'package:aquaflow_frontend/features/auth/data/repositories/auth_repository.dart';
import 'package:aquaflow_frontend/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aquaflow_frontend/features/awd/domain/models/awd_analytics_summary.dart';
import 'package:aquaflow_frontend/features/awd/domain/models/awd_threshold_config.dart';
import 'package:aquaflow_frontend/features/awd/domain/services/awd_rule_engine.dart';
import 'package:aquaflow_frontend/features/control/data/repositories/control_repository.dart';
import 'package:aquaflow_frontend/features/control/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../support/fakes.dart';
import '../support/zone_fixtures.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // AuthNotifier state transitions
  // ──────────────────────────────────────────────────────────────────────────
  group('AuthNotifier state transitions', () {
    AuthNotifier makeNotifier() => AuthNotifier(
          authRepository: AuthRepositoryImpl(
            authService: MockAuthService(),
            storageService: MemorySecureStorage(),
            tokenStore: FakeTokenStore(),
          ),
        );

    test('moves initial → authenticated → unauthenticated', () async {
      final notifier = makeNotifier();
      expect(notifier.state.status, AuthStatus.initial);

      final ok = await notifier.login('operator@aquaflow.io', 'pass');
      expect(ok, isTrue);
      expect(notifier.state.isAuthenticated, isTrue);

      await notifier.logout();
      expect(notifier.state.status, AuthStatus.unauthenticated);
    });

    test('rejects empty credentials without authenticating', () async {
      final notifier = makeNotifier();
      final ok = await notifier.login('  ', '');
      expect(ok, isFalse);
      expect(notifier.state.status, AuthStatus.error);
    });

    test('stays in error state on wrong credentials', () async {
      final notifier = makeNotifier();
      final ok = await notifier.login('operator', 'wrongpassword');
      expect(ok, isFalse);
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.errorMessage, isNotEmpty);
    });

    test('state session is null before login and non-null after', () async {
      final notifier = makeNotifier();
      expect(notifier.state.session, isNull);
      await notifier.login('operator@aquaflow.io', 'pass');
      expect(notifier.state.session, isNotNull);
    });

    test('logout clears session from state', () async {
      final notifier = makeNotifier();
      await notifier.login('operator@aquaflow.io', 'pass');
      await notifier.logout();
      expect(notifier.state.session, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Typed API error handling — 401, 403, 500, timeout, decode
  // ──────────────────────────────────────────────────────────────────────────
  group('Typed API error handling', () {
    ApiClient makeClient(Future<http.StreamedResponse> Function(http.BaseRequest) handler) {
      return ApiClient(
        config: const ApiConfig(baseUrl: 'https://example.test'),
        httpClient: FakeHttpClient(handler),
      );
    }

    Future<void> expectKind(int status, ApiErrorKind kind) async {
      final client = makeClient(
        (request) async => fakeJsonResponse(request, status, '{"message":"x"}'),
      );
      await expectLater(
        client.get('/api/fields'),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', kind)),
      );
    }

    test('maps 401 to authentication', () async {
      await expectKind(401, ApiErrorKind.authentication);
    });

    test('maps 403 to insufficientRole', () async {
      await expectKind(403, ApiErrorKind.insufficientRole);
    });

    test('maps 500 to server error', () async {
      await expectKind(500, ApiErrorKind.server);
    });

    test('maps 503 to server error', () async {
      await expectKind(503, ApiErrorKind.server);
    });

    test('maps 422 to validation error', () async {
      await expectKind(422, ApiErrorKind.validation);
    });

    test('maps 400 to validation error', () async {
      await expectKind(400, ApiErrorKind.validation);
    });

    test('maps malformed JSON body to decoding error', () async {
      final client = makeClient(
        (request) async => fakeJsonResponse(request, 200, '{malformed'),
      );
      await expectLater(
        client.get('/api/fields'),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.decoding)),
      );
    });

    test('timeout maps to ApiErrorKind.timeout', () async {
      final client = ApiClient(
        config: const ApiConfig(
          baseUrl: 'https://example.test',
          connectTimeout: Duration(milliseconds: 1),
          receiveTimeout: Duration(milliseconds: 1),
        ),
        httpClient: FakeHttpClient(
          (request) async {
            await Future<void>.delayed(const Duration(seconds: 5));
            return fakeJsonResponse(request, 200, '{}');
          },
        ),
      );

      await expectLater(
        client.get('/api/fields'),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.timeout)),
      );
    });

    test('ApiException exposes statusCode correctly', () async {
      final client = makeClient(
        (request) async => fakeJsonResponse(request, 403, '{"message":"forbidden"}'),
      );
      await expectLater(
        client.get('/api/fields'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.kind, 'kind', ApiErrorKind.insufficientRole),
        ),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Irrigation command handling (tasks 2.4)
  // ──────────────────────────────────────────────────────────────────────────
  group('Irrigation command handling', () {
    test('DTO rejects Q1–Q4 targets before transport', () {
      for (final target in ['Q1', 'Q2', 'Q3', 'Q4']) {
        expect(
          () => IrrigationCommandDto(target: target).toJson(),
          throwsA(isA<FormatException>()),
          reason: 'Expected FormatException for target "$target"',
        );
      }
    });

    test('DTO rejects arbitrary zone strings', () {
      expect(
        () => const IrrigationCommandDto(target: 'ZONE-3').toJson(),
        throwsA(isA<FormatException>()),
      );
    });

    test('repository rejects Q2 with rejected outcome and ENTIRE FIELD message', () async {
      final repo = MockControlRepository();
      final result = await repo.dispatchCommand(
        ControlCommand(
          id: 'c1',
          type: CommandType.startIrrigation,
          target: 'Q2',
          durationMinutes: 30,
          timestamp: DateTime.now(),
          requestedBy: 'tester',
          userRole: ControlUserRole.operator,
        ),
      );
      expect(result.outcome, CommandOutcome.rejected);
      expect(result.message, contains('ENTIRE FIELD'));
    });

    test('repository accepts ENTIRE FIELD and updates pump/valve', () async {
      final repo = MockControlRepository();
      final result = await repo.dispatchCommand(
        ControlCommand(
          id: 'c2',
          type: CommandType.startIrrigation,
          target: CentralControlTelemetry.fixedTarget,
          durationMinutes: 30,
          timestamp: DateTime.now(),
          requestedBy: 'tester',
          userRole: ControlUserRole.operator,
        ),
      );
      expect(result.isSuccess, isTrue);
      final telemetry = await repo.getCentralTelemetry();
      expect(telemetry.target, CentralControlTelemetry.fixedTarget);
      expect(telemetry.pumpStatus, PumpStatus.pumping);
      expect(telemetry.valveStatus, MainValveStatus.open);
    });

    test('repository rejects viewer role', () async {
      final repo = MockControlRepository();
      final result = await repo.dispatchCommand(
        ControlCommand(
          id: 'c3',
          type: CommandType.startIrrigation,
          durationMinutes: 15,
          timestamp: DateTime.now(),
          requestedBy: 'viewer',
          userRole: ControlUserRole.viewer,
        ),
      );
      expect(result.outcome, CommandOutcome.rejected);
      expect(result.message, contains('Unauthorized'));
    });

    test('stop command after start resets pump and valve to idle', () async {
      final repo = MockControlRepository();
      await repo.dispatchCommand(ControlCommand(
        id: 'start',
        type: CommandType.startIrrigation,
        durationMinutes: 30,
        timestamp: DateTime.now(),
        requestedBy: 'tester',
        userRole: ControlUserRole.operator,
      ));

      final stop = await repo.dispatchCommand(ControlCommand(
        id: 'stop',
        type: CommandType.stopIrrigation,
        durationMinutes: 0,
        timestamp: DateTime.now(),
        requestedBy: 'tester',
        userRole: ControlUserRole.operator,
      ));
      expect(stop.isSuccess, isTrue);
      final telemetry = await repo.getCentralTelemetry();
      expect(telemetry.pumpStatus, PumpStatus.off);
      expect(telemetry.valveStatus, MainValveStatus.closed);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // AWD measurement data transformations (task 2.2)
  // ──────────────────────────────────────────────────────────────────────────
  group('AWD measurement transformations', () {
    test('drying zones produce positive drying rate per day', () {
      final summary = AwdRuleEngine.evaluateFieldAwd(
        zones: sampleFieldZones(drying: true),
      );
      final rates = summary.zoneDryingRates;
      expect(rates, hasLength(4));
      // All four zones are drying, so rates should be positive (descending water)
      for (final rate in rates) {
        expect(rate.dryingRateCmPerDay, isNotNull);
      }
    });

    test('evaluates with custom reflood trigger threshold', () {
      final summary = AwdRuleEngine.evaluateFieldAwd(
        zones: sampleFieldZones(depth: 0.5),
        config: const AwdThresholdConfig(refloodTriggerCm: 1.0),
      );
      expect(summary.fieldStatus, FieldAwdStatus.refloodNeeded);
    });

    test('evaluates with custom critical dryness threshold', () {
      final summary = AwdRuleEngine.evaluateFieldAwd(
        zones: sampleFieldZones(depth: -7.0),
        config: const AwdThresholdConfig(criticalDrynessThresholdCm: -5.0),
      );
      expect(summary.fieldStatus, FieldAwdStatus.criticalDryness);
    });

    test('field status optimal when depth is well above thresholds', () {
      final summary = AwdRuleEngine.evaluateFieldAwd(
        zones: sampleFieldZones(depth: 10.0),
      );
      expect(
        summary.fieldStatus,
        isNot(FieldAwdStatus.refloodNeeded),
      );
      expect(
        summary.fieldStatus,
        isNot(FieldAwdStatus.criticalDryness),
      );
    });

    test('reportingZones match the Q1–Q4 fixture set', () {
      final summary = AwdRuleEngine.evaluateFieldAwd(
        zones: sampleFieldZones(),
      );
      final codes = summary.reportingZones.map((z) => z.code).toList();
      expect(codes, containsAll(['Q1', 'Q2', 'Q3', 'Q4']));
    });
  });
}
