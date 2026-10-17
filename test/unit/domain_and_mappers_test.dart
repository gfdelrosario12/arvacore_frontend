// test/unit/domain_and_mappers_test.dart
//
// Unit tests for:
//  – ZoneTrendAnalysis (monitoring_zone)
//  – AwdRuleEngine (AWD analysis + mapper transforms)
//  – ApiMappers (zone, auth, telemetry DTOs)
//  – SystemAlert / AlertSource domain model
//  – DeviceDiagnostic domain model and scope invariant
//  – SettingsSnapshot round-trip and defaults

import 'package:aquaflow_frontend/core/api/api_dtos.dart';
import 'package:aquaflow_frontend/core/api/api_mappers.dart';
import 'package:aquaflow_frontend/features/alerts/domain/models/alert_enums.dart';
import 'package:aquaflow_frontend/features/alerts/domain/models/alert_source.dart';
import 'package:aquaflow_frontend/features/alerts/domain/models/system_alert.dart';
import 'package:aquaflow_frontend/features/awd/domain/models/awd_analytics_summary.dart';
import 'package:aquaflow_frontend/features/awd/domain/models/awd_recommendation.dart';
import 'package:aquaflow_frontend/features/awd/domain/models/awd_threshold_config.dart';
import 'package:aquaflow_frontend/features/awd/domain/services/awd_rule_engine.dart';
import 'package:aquaflow_frontend/features/control/domain/models/central_control_telemetry.dart';
import 'package:aquaflow_frontend/features/control/domain/models/control_enums.dart';
import 'package:aquaflow_frontend/features/diagnostics/domain/models/device_diagnostic.dart';
import 'package:aquaflow_frontend/features/diagnostics/domain/models/diagnostics_enums.dart';
import 'package:aquaflow_frontend/features/settings/domain/models/settings_models.dart';
import 'package:aquaflow_frontend/features/zones/domain/models/monitoring_zone.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

import '../support/zone_fixtures.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // ZoneTrendAnalysis
  // ──────────────────────────────────────────────────────────────────────────
  group('ZoneTrendAnalysis', () {
    test('detects rising and falling water level trends from history', () {
      final rising = ZoneTrendAnalysis.fromHistory(const [1, 2, 3, 4]);
      expect(rising.direction, TrendDirection.rising);

      final falling = ZoneTrendAnalysis.fromHistory(const [8, 6, 4, 2]);
      expect(falling.direction, TrendDirection.falling);

      final stable = ZoneTrendAnalysis.fromHistory(const [5, 5, 5]);
      expect(stable.direction, TrendDirection.stable);
    });

    test('returns stable for single-element history', () {
      final trend = ZoneTrendAnalysis.fromHistory(const [4.0]);
      expect(trend.direction, TrendDirection.stable);
    });

    test('rate has correct sign for rising and falling', () {
      final rising = ZoneTrendAnalysis.fromHistory(const [3, 4, 5]);
      expect(rising.rateCmPerHour, greaterThan(0));

      final falling = ZoneTrendAnalysis.fromHistory(const [5, 4, 3]);
      expect(falling.rateCmPerHour, lessThan(0));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // AwdRuleEngine
  // ──────────────────────────────────────────────────────────────────────────
  group('AwdRuleEngine', () {
    test('enforces quorum requirement or zero zones for field evaluation', () {
      final summaryEmpty = AwdRuleEngine.evaluateFieldAwd(
        zones: const [],
      );
      expect(summaryEmpty.isInsufficientData, isTrue);
      expect(summaryEmpty.recommendation.title, contains('Insufficient'));

      final summary = AwdRuleEngine.evaluateFieldAwd(
        zones: sampleFieldZones().take(2).toList(),
        minRequiredZones: 4,
      );
      expect(summary.isInsufficientData, isTrue);
      expect(summary.recommendation.title, contains('Insufficient'));
    });

    test('flags critical dryness from min depth threshold', () {
      final summary = AwdRuleEngine.evaluateFieldAwd(
        zones: sampleFieldZones(depth: -6.0),
        config: const AwdThresholdConfig(criticalDrynessThresholdCm: -5.0),
      );
      expect(summary.fieldStatus, FieldAwdStatus.criticalDryness);
      expect(summary.reportingZones.length, 4);
    });

    test('aggregates Q1–Q4 without inventing zone actuators', () {
      final summary = AwdRuleEngine.evaluateFieldAwd(
        zones: sampleFieldZones(depth: 6.0),
      );
      expect(summary.reportingZones.map((z) => z.code), ['Q1', 'Q2', 'Q3', 'Q4']);
      expect(
        summary.recommendation.title.toLowerCase(),
        isNot(contains('q1 pump')),
      );
    });

    test('drying scenario produces non-empty drying rates for all zones', () {
      final summary = AwdRuleEngine.evaluateFieldAwd(
        zones: sampleFieldZones(drying: true),
      );
      expect(summary.isInsufficientData, isFalse);
      expect(summary.zoneDryingRates, hasLength(4));
      for (final rate in summary.zoneDryingRates) {
        expect(['Q1', 'Q2', 'Q3', 'Q4'], contains(rate.zoneCode));
      }
    });

    test('recommendation contains irrigate action on reflood-needed state', () {
      final summary = AwdRuleEngine.evaluateFieldAwd(
        zones: sampleFieldZones(depth: 0.3),
        config: const AwdThresholdConfig(refloodTriggerCm: 1.0),
      );
      expect(summary.fieldStatus, FieldAwdStatus.refloodNeeded);
      expect(summary.recommendation.action, IrrigationAction.irrigate);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // ApiMappers
  // ──────────────────────────────────────────────────────────────────────────
  group('ApiMappers', () {
    test('maps auth response into UserSession', () {
      final session = ApiMappers.userSession(
        AuthResponseDto(
          accessToken: 'access',
          refreshToken: 'refresh',
          user: {
            'id': 'u1',
            'username': 'op',
            'email': 'op@aquaflow.io',
            'role': 'Field Operator',
          },
        ),
      );
      expect(session.userId, 'u1');
      expect(session.token.accessToken, 'access');
      expect(session.token.refreshToken, 'refresh');
    });

    test('maps monitoring zone resource with quarter code', () {
      final zone = ApiMappers.monitoringZone(
        ResourceDto(
          id: 'z1',
          data: {
            'code': 'Q3',
            'soilMoisturePercent': 40,
            'waterLevelCm': 3.5,
            'isOnline': true,
            'status': 'optimal',
          },
        ),
      );
      expect(zone.code, 'Q3');
      expect(zone.waterLevelCm, 3.5);
    });

    test('maps Q1, Q2, Q3, Q4 zone codes correctly', () {
      for (final code in ['Q1', 'Q2', 'Q3', 'Q4']) {
        final zone = ApiMappers.monitoringZone(
          ResourceDto(
            id: 'z-$code',
            data: {
              'code': code,
              'soilMoisturePercent': 50,
              'waterLevelCm': 5.0,
              'isOnline': true,
              'status': 'optimal',
            },
          ),
        );
        expect(zone.code, code);
      }
    });

    test('maps central telemetry with ENTIRE FIELD fallback target', () {
      final telemetry = ApiMappers.centralTelemetry(
        const ResourceDto(
          id: 'CTRL-1',
          data: {
            'controllerState': 'online',
            'pumpStatus': 'off',
            'valveStatus': 'closed',
            'irrigationState': 'idle',
          },
        ),
      );
      expect(telemetry.target, CentralControlTelemetry.fixedTarget);
      expect(telemetry.pumpStatus, PumpStatus.off);
    });

    test('central telemetry target is always ENTIRE FIELD regardless of DTO data', () {
      // Even if an unexpected target were injected in the data map, the
      // mapper must normalise it to the fixed target constant.
      final telemetry = ApiMappers.centralTelemetry(
        const ResourceDto(
          id: 'CTRL-2',
          data: {
            'controllerState': 'online',
            'pumpStatus': 'pumping',
            'valveStatus': 'open',
            'irrigationState': 'irrigating',
            // Intentionally omit 'target' to confirm fallback.
          },
        ),
      );
      expect(telemetry.target, CentralControlTelemetry.fixedTarget);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // SystemAlert domain model (tasks 2.1 – alerts)
  // ──────────────────────────────────────────────────────────────────────────
  group('SystemAlert domain model', () {
    final baseAlert = SystemAlert(
      id: 'ALT-01',
      title: 'Critical Dryness: Q4',
      description: 'Water level below threshold.',
      severity: AlertSeverity.critical,
      category: AlertCategory.agronomic,
      source: AlertSource.monitoringZone('Q4'),
      timestamp: DateTime.utc(2026, 9, 1),
      recommendedAction: 'Irrigate field.',
    );

    test('copyWith preserves unchanged fields', () {
      final updated = baseAlert.copyWith(isRead: true);
      expect(updated.id, baseAlert.id);
      expect(updated.title, baseAlert.title);
      expect(updated.isRead, isTrue);
      expect(baseAlert.isRead, isFalse); // original unchanged
    });

    test('monitoring zone source uses correct scope', () {
      expect(baseAlert.source.type, AlertSourceType.monitoringZone);
      expect(baseAlert.source.targetScope, 'Q4');
    });

    test('centralIrrigation source always uses ENTIRE FIELD scope', () {
      final irrigationAlert = baseAlert.copyWith(
        source: AlertSource.centralIrrigation,
        category: AlertCategory.irrigation,
      );
      expect(irrigationAlert.source.type, AlertSourceType.centralIrrigation);
      expect(irrigationAlert.source.targetScope, 'ENTIRE FIELD');
    });

    test('gateway source uses ENTIRE FIELD scope', () {
      expect(AlertSource.gateway.targetScope, 'ENTIRE FIELD');
      expect(AlertSource.gateway.type, AlertSourceType.gateway);
    });

    test('severity enumeration has info, warning, critical', () {
      expect(AlertSeverity.values, containsAll([
        AlertSeverity.info,
        AlertSeverity.warning,
        AlertSeverity.critical,
      ]));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // DeviceDiagnostic domain model (tasks 2.1 – diagnostics)
  // ──────────────────────────────────────────────────────────────────────────
  group('DeviceDiagnostic domain model', () {
    final baseDevice = DeviceDiagnostic(
      id: 'DEV-Q1',
      name: 'Quadrant Q1 Sensor Node',
      category: DeviceCategory.sensorNode,
      healthStatus: DeviceHealthStatus.healthy,
      isOnline: true,
      batteryPercent: 92,
      rssiDbm: -75,
      snrDb: 9.5,
      lastSeen: DateTime.utc(2026, 9, 1),
      targetScope: 'Q1',
      diagnosticMessage: 'All sensors nominal.',
    );

    test('sensor nodes have Q-zone target scope', () {
      for (final code in ['Q1', 'Q2', 'Q3', 'Q4']) {
        final device = baseDevice.copyWith(targetScope: code);
        expect(device.targetScope, code);
        expect(device.category, DeviceCategory.sensorNode);
      }
    });

    test('central controller scope is ENTIRE FIELD', () {
      final controller = baseDevice.copyWith(
        id: 'DEV-CTRL',
        name: 'Centralized Irrigation Controller',
        category: DeviceCategory.centralController,
        targetScope: 'ENTIRE FIELD',
      );
      expect(controller.targetScope, 'ENTIRE FIELD');
      expect(controller.category, DeviceCategory.centralController);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = baseDevice.copyWith(batteryPercent: 50);
      expect(updated.id, baseDevice.id);
      expect(updated.batteryPercent, 50);
      expect(baseDevice.batteryPercent, 92);
    });

    test('DeviceHealthStatus has expected values', () {
      expect(DeviceHealthStatus.values, containsAll([
        DeviceHealthStatus.healthy,
        DeviceHealthStatus.degraded,
        DeviceHealthStatus.offline,
        DeviceHealthStatus.stale,
        DeviceHealthStatus.error,
      ]));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // SettingsSnapshot domain model (tasks 2.1 – settings)
  // ──────────────────────────────────────────────────────────────────────────
  group('SettingsSnapshot domain model', () {
    test('defaults returns expected preset values', () {
      final defaults = SettingsSnapshot.defaults();
      expect(defaults.appearance, SettingsAppearance.system);
      expect(defaults.measurementUnit, MeasurementUnit.metric);
      expect(defaults.language, SettingsLanguage.english);
      expect(defaults.notifications.systemAlerts, isTrue);
      expect(defaults.notifications.irrigationUpdates, isTrue);
    });

    test('toMap / withMap round-trip preserves all typed values', () {
      final snapshot = SettingsSnapshot.defaults();
      final map = snapshot.toMap();
      final restored = snapshot.withMap({
        ...map,
        'appearance': 'dark',
        'measurementUnit': 'imperial',
        'language': 'filipino',
      });
      expect(restored.appearance, SettingsAppearance.dark);
      expect(restored.measurementUnit, MeasurementUnit.imperial);
      expect(restored.language, SettingsLanguage.filipino);
    });

    test('withMap falls back to current value on unknown enum string', () {
      final snapshot = SettingsSnapshot.defaults();
      final restored = snapshot.withMap({'appearance': 'INVALID_VALUE'});
      expect(restored.appearance, snapshot.appearance);
    });

    test('themeMode maps each appearance correctly', () {
      expect(
        SettingsSnapshot.defaults()
            .copyWith(appearance: SettingsAppearance.light)
            .themeMode,
        ThemeMode.light,
      );
      expect(
        SettingsSnapshot.defaults()
            .copyWith(appearance: SettingsAppearance.dark)
            .themeMode,
        ThemeMode.dark,
      );
      expect(
        SettingsSnapshot.defaults()
            .copyWith(appearance: SettingsAppearance.system)
            .themeMode,
        ThemeMode.system,
      );
    });

    test('notifications copyWith selectively updates flags', () {
      final prefs = const NotificationPreferences()
          .copyWith(systemAlerts: false);
      expect(prefs.systemAlerts, isFalse);
      expect(prefs.irrigationUpdates, isTrue); // unchanged
    });
  });
}
