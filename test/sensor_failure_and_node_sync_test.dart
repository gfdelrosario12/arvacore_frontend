import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/core/api/api_dtos.dart';
import 'package:aquaflow_frontend/core/api/api_mappers.dart';
import 'package:aquaflow_frontend/features/home/presentation/widgets/connected_nodes_card.dart';
import 'package:aquaflow_frontend/features/nodes/domain/models/esp32_node.dart';
import 'package:aquaflow_frontend/features/nodes/domain/models/node_enums.dart';
import 'package:aquaflow_frontend/features/nodes/domain/models/transmission_config.dart';
import 'package:aquaflow_frontend/features/telemetry_stream/domain/models/telemetry_stream_event.dart';
import 'package:aquaflow_frontend/features/telemetry_stream/presentation/widgets/telemetry_stream_event_card.dart';
import 'package:aquaflow_frontend/features/zones/domain/models/monitoring_zone.dart';

void main() {
  group('Sensor Failure Zero Telemetry & Node Assignment Consistency Tests', () {
    test('ApiMappers.esp32Node preserves canonical nodeId and numeric 0.0 on sensor failure', () {
      final resource = ResourceDto.fromJson({
        'id': 42,
        'nodeId': 'ARVANODE-001',
        'macAddress': '8C:4F:00:AB:CD:01',
        'displayName': 'ARVANODE-001',
        'lifecycleState': 'ACTIVE',
        'pairingStatus': 'PAIRED',
        'assignmentStatus': 'UNASSIGNED',
        'connectivityStatus': 'ONLINE',
        'isOnline': true,
        'soilMoisturePercent': 0.0,
        'waterLevelDistanceCm': 0.0,
        'waterLevelCm': 0.0,
        'soilSensorHealth': 'ERROR',
        'ultrasonicSensorHealth': 'TIMEOUT',
        'telemetryStatus': 'SENSOR_FAILURE',
        'sensorHealth': {
          'soilMoisture': 'ERROR',
          'ultrasonic': 'TIMEOUT',
        },
      });

      final node = ApiMappers.esp32Node(resource);

      expect(node.id, equals('ARVANODE-001'));
      expect(node.soilMoisturePercent, equals(0.0));
      expect(node.waterLevelDistanceCm, equals(0.0));
      expect(node.waterLevelCm, equals(0.0));
      expect(node.soilSensorHealth, equals('ERROR'));
      expect(node.ultrasonicSensorHealth, equals('TIMEOUT'));
      expect(node.telemetryStatus, equals('SENSOR_FAILURE'));
      expect(node.isSoilSensorFailed, isTrue);
      expect(node.isUltrasonicSensorFailed, isTrue);
      expect(node.hasSensorFailure, isTrue);
      expect(node.isAssigned, isFalse);
    });

    test('ApiMappers.calculateWaterLevelFromDistance returns 0.0 for 0.0 distance instead of 91.44 cm', () {
      expect(ApiMappers.calculateWaterLevelFromDistance(0.0), equals(0.0));
      expect(ApiMappers.calculateWaterLevelFromDistance(91.6), closeTo(10.0, 0.1));
    });

    testWidgets('ConnectedNodesCard displays numeric 0.0% and 0.0 cm with sensor failure badges and unassigned status', (tester) async {
      final failedUnassignedNode = Esp32Node(
        id: 'ARVANODE-001',
        macAddress: '8C:4F:00:AB:CD:01',
        displayName: 'ARVANODE-001',
        assignedZoneId: null,
        assignmentStatus: 'UNASSIGNED',
        pairingStatus: 'PAIRED',
        connectivityStatus: 'ONLINE',
        soilSensorHealth: 'ERROR',
        ultrasonicSensorHealth: 'TIMEOUT',
        telemetryStatus: 'SENSOR_FAILURE',
        transmissionConfig: const TransmissionConfig(intervalSeconds: 3),
        isOnline: true,
        lifecycleState: NodeLifecycleStatus.active,
        lastSeen: DateTime.now(),
        soilMoisturePercent: 0.0,
        waterLevelCm: 0.0,
        waterLevelDistanceCm: 0.0,
        batteryPercent: 95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConnectedNodesCard(
                nodes: [failedUnassignedNode],
                zones: const [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('0.0%'), findsOneWidget);
      expect(find.text('0.0 cm'), findsOneWidget);
      expect(find.text('SOIL: ERROR'), findsOneWidget);
      expect(find.text('ULTRA: TIMEOUT'), findsOneWidget);
      expect(find.text('SENSOR_FAILURE'), findsOneWidget);
      expect(find.textContaining('Unassigned'), findsOneWidget);
    });

    testWidgets('ConnectedNodesCard displays authoritative zone assignment when node is assigned', (tester) async {
      final zoneQ1 = MonitoringZone(
        id: '101',
        code: 'Q1',
        name: 'Quarter 1',
        soilMoisturePercent: 62.5,
        waterLevelCm: 10.0,
        temperatureCelsius: 28.0,
        humidityPercent: 75.0,
        batteryPercent: 98,
        status: ZoneStatus.optimal,
        lastUpdated: DateTime.now(),
        isOnline: true,
        rssiDbm: -60,
        snrDb: 9.5,
        hardwareModel: 'ESP32',
        firmwareVersion: '2.1.0',
        waterLevelHistory: const [10.0],
        assignedNodeIds: const ['ARVANODE-001'],
      );

      final assignedNode = Esp32Node(
        id: 'ARVANODE-001',
        macAddress: '8C:4F:00:AB:CD:01',
        displayName: 'ARVANODE-001',
        assignedZoneId: '101',
        assignedZoneCode: 'Q1',
        assignedZoneName: 'Quarter 1',
        assignmentStatus: 'ASSIGNED_TO_ZONE',
        pairingStatus: 'PAIRED',
        connectivityStatus: 'ONLINE',
        soilSensorHealth: 'OK',
        ultrasonicSensorHealth: 'OK',
        telemetryStatus: 'OK',
        transmissionConfig: const TransmissionConfig(intervalSeconds: 3),
        isOnline: true,
        lifecycleState: NodeLifecycleStatus.active,
        lastSeen: DateTime.now(),
        soilMoisturePercent: 62.5,
        waterLevelCm: 10.0,
        waterLevelDistanceCm: 91.6,
        batteryPercent: 98,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConnectedNodesCard(
                nodes: [assignedNode],
                zones: [zoneQ1],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Q1 • Quarter 1'), findsOneWidget);
      expect(find.text('62.5%'), findsOneWidget);
      expect(find.text('10.0 cm'), findsOneWidget);
      expect(find.text('SOIL: OK'), findsOneWidget);
      expect(find.text('ULTRA: OK'), findsOneWidget);
    });

    testWidgets('TelemetryStreamEventCard displays numeric 0.0 and sensor failure badges for unassigned node', (tester) async {
      final event = TelemetryStreamEvent.fromJson({
        'eventId': 'evt-001',
        'nodeId': 'ARVANODE-001',
        'eventType': 'TELEMETRY_UPLINK',
        'status': 'PROCESSED',
        'receivedAt': DateTime.now().toIso8601String(),
        'sequenceNumber': 12,
        'zoneId': null,
        'zoneCode': null,
        'soilMoisturePercent': 0.0,
        'waterLevelCm': 0.0,
        'waterLevelDistanceCm': 0.0,
        'soilSensorHealth': 'ERROR',
        'ultrasonicSensorHealth': 'TIMEOUT',
        'telemetryStatus': 'PARTIAL_FAILURE',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TelemetryStreamEventCard(event: event),
            ),
          ),
        ),
      );

      expect(find.text('UNASSIGNED'), findsOneWidget);
      expect(find.text('PARTIAL_FAILURE'), findsOneWidget);
      expect(find.textContaining('0.0% (ERROR)'), findsOneWidget);
      expect(find.textContaining('0.0 cm (0.0 in) (TIMEOUT)'), findsOneWidget);
    });
  });
}

