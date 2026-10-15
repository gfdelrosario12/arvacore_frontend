import 'package:aquaflow_frontend/core/realtime/realtime_events.dart';
import 'package:aquaflow_frontend/features/diagnostics/domain/models/models.dart';
import 'package:aquaflow_frontend/features/diagnostics/presentation/widgets/device_detail_dialog.dart';
import 'package:aquaflow_frontend/features/nodes/data/repositories/node_repository.dart';
import 'package:aquaflow_frontend/features/nodes/domain/models/models.dart';
import 'package:aquaflow_frontend/features/nodes/presentation/providers/lorawan_node_notifier.dart';
import 'package:aquaflow_frontend/features/nodes/presentation/widgets/node_registration_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoRaWAN Domain Models & Serialization', () {
    test('LoRaWANLinkQuality serialization', () {
      const link = LoRaWANLinkQuality(
        rssiDbm: -92.5,
        snrDb: 9.2,
        gatewayId: 'GW-E8E076FFFE001234',
        frequencyHz: 915000000,
        spreadingFactor: 'SF7',
      );

      final json = link.toJson();
      expect(json['rssiDbm'], -92.5);
      expect(json['snrDb'], 9.2);
      expect(json['gatewayId'], 'GW-E8E076FFFE001234');

      final deserialized = LoRaWANLinkQuality.fromJson(json);
      expect(deserialized.rssiDbm, -92.5);
      expect(deserialized.snrDb, 9.2);
      expect(deserialized.spreadingFactor, 'SF7');
    });

    test('LoRaWANIdentity serialization & copyWith', () {
      final now = DateTime.utc(2026, 9, 21, 10, 0, 0);
      final identity = LoRaWANIdentity(
        devEui: '0004A30B001F9876',
        joinEui: '0000000000000000',
        appKey: '2B7E151628AED2A6ABF7158809CF4F3C',
        devAddr: '01234567',
        fCntUp: 42,
        fCntDown: 10,
        lastSeen: now,
      );

      final json = identity.toJson();
      expect(json['devEui'], '0004A30B001F9876');
      expect(json['fCntUp'], 42);

      final restored = LoRaWANIdentity.fromJson(json);
      expect(restored.devEui, '0004A30B001F9876');
      expect(restored.fCntUp, 42);

      final updated = restored.copyWith(fCntUp: 43, downlinkStatus: 'queued');
      expect(updated.fCntUp, 43);
      expect(updated.downlinkStatus, 'queued');
    });

    test('Esp32Node with LoRaWANIdentity', () {
      final node = SensorNode(
        id: 'node-lora-1',
        macAddress: '0004A30B001F9876',
        displayName: 'East Field LoRa Sensor',
        assignedZoneId: 'zone-dynamic-east',
        isOnline: true,
        transmissionConfig: const TransmissionConfig(),
        lastSeen: DateTime.now(),
        loRaWANIdentity: const LoRaWANIdentity(
          devEui: '0004A30B001F9876',
          joinEui: '0000000000000000',
        ),
      );

      final json = node.toJson();
      expect(json['loRaWANIdentity'], isNotNull);
      expect(json['loRaWANIdentity']['devEui'], '0004A30B001F9876');

      final restoredNode = Esp32Node.fromJson(json);
      expect(restoredNode.loRaWANIdentity?.devEui, '0004A30B001F9876');
    });

    test('Measurement UTC timestamp normalization and devEui extraction', () {
      final dt = DateTime.parse('2026-09-21T10:15:30Z');
      final measurement = Measurement(
        id: 'm-1',
        timestamp: dt,
        sensorId: 's-1',
        pointId: 'p-1',
        rawValue: 45.0,
        calibratedValue: 44.2,
        metadata: const {'devEui': '0004A30B001F9876'},
      );

      expect(measurement.serverNormalizedTimestamp.isUtc, isTrue);
      expect(measurement.devEui, '0004A30B001F9876');
    });
  });

  group('RealtimeEvent LoRaWAN Parsing', () {
    test('Parses lorawanTelemetry event', () {
      final eventJson = {
        'version': 1,
        'eventId': 'evt-lora-1',
        'eventType': 'lorawan_telemetry',
        'occurredAt': '2026-09-21T10:00:00Z',
        'sequence': 101,
        'scope': 'NODE-0004A30B001F9876',
        'payload': {'soilMoisture': 35.5, 'batteryVoltage': 3.7},
      };

      final event = RealtimeEvent.fromJson(eventJson);
      expect(event.type, RealtimeEventType.lorawanTelemetry);
      expect(event.scope, 'NODE-0004A30B001F9876');
    });
  });

  group('LoRaWAN State Notifier Tests', () {
    test('Registration and downlink queuing', () async {
      final fakeRepo = MockNodeRepository();
      final notifier = LoRaWANNodeNotifier(nodeRepository: fakeRepo);
      await notifier.loadLoRaWANNodes();

      expect(notifier.state.isLoading, isFalse);

      final success = await notifier.registerLoRaWANNode(
        devEui: '0004A30B001F9876',
        joinEui: '0000000000000000',
        appKey: '2B7E151628AED2A6ABF7158809CF4F3C',
        displayName: 'East Boundary Sensor',
        assignedFieldId: 'field-main',
        assignedZoneId: 'zone-dynamic-east',
      );

      expect(success, isTrue);
      expect(notifier.state.loRaWANNodes.length, greaterThanOrEqualTo(1));

      final queued = await notifier.queueDownlinkCommand(
        devEui: '0004A30B001F9876',
        newIntervalSeconds: 60,
      );

      expect(queued, isTrue);
    });
  });

  group('LoRaWAN Widgets Tests', () {
    testWidgets('NodeRegistrationDialog renders empty state when no nodes requested pairing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NodeRegistrationDialog(
              discoveredNodes: const [],
              onRegister: (req) async => true,
            ),
          ),
        ),
      );

      expect(find.text('Hardware Node Discovery'), findsOneWidget);
      expect(find.text('No Nodes Requested to Pair'), findsOneWidget);
    });

    testWidgets('DeviceDetailDialog renders LoRaWAN link metrics', (tester) async {
      final device = DeviceDiagnostic(
        id: 'node-lora-1',
        name: 'LoRaWAN Field Node',
        category: DeviceCategory.sensorNode,
        healthStatus: DeviceHealthStatus.healthy,
        diagnosticMessage: 'Operating nominally',
        targetScope: 'zone-dynamic-east',
        isOnline: true,
        lastSeen: DateTime.now(),
        batteryPercent: 88,
        batteryVoltage: 3.85,
        rssiDbm: -88,
        snrDb: 10.5,
        macAddress: '0004A30B001F9876',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceDetailDialog(
              device: device,
            ),
          ),
        ),
      );

      expect(find.text('LoRaWAN Link Metrics'), findsOneWidget);
      expect(find.text('0004A30B001F9876'), findsOneWidget);
      expect(find.text('Class A'), findsOneWidget);
    });
  });
}
