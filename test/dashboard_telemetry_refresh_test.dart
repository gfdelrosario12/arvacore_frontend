import 'package:aquaflow_frontend/core/api/api_mappers.dart';
import 'package:aquaflow_frontend/features/home/data/repositories/field_dashboard_repository.dart';
import 'package:aquaflow_frontend/features/home/domain/models/field_dashboard_summary.dart';
import 'package:aquaflow_frontend/features/home/presentation/home_screen.dart';
import 'package:aquaflow_frontend/features/home/presentation/widgets/connected_nodes_card.dart';
import 'package:aquaflow_frontend/features/irrigation/domain/models/centralized_irrigation.dart';
import 'package:aquaflow_frontend/features/nodes/domain/models/esp32_node.dart';
import 'package:aquaflow_frontend/features/nodes/domain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts how often the dashboard asked for fresh telemetry.
class _RecordingDashboardRepository implements FieldDashboardRepository {
  int topologyLoads = 0;
  int telemetryPolls = 0;

  @override
  Future<FieldDashboardSummary> fetchDashboardSummary({
    MockState mockState = MockState.normal,
  }) async {
    topologyLoads++;
    return _summary();
  }

  @override
  Future<FieldDashboardSummary> refreshLatestTelemetry() async {
    telemetryPolls++;
    return _summary();
  }
}

/// Serves a fixed set of telemetry snapshots.
class _FakeTelemetrySource implements DashboardTelemetrySource {
  List<NodeTelemetrySnapshot> snapshots;
  List<String>? lastRequestedNodeIds;

  _FakeTelemetrySource(this.snapshots);

  @override
  Future<List<NodeTelemetrySnapshot>> fetchLatestTelemetry(
    List<String> nodeIds,
  ) async {
    lastRequestedNodeIds = nodeIds;
    return snapshots;
  }
}

FieldDashboardSummary _summary({List<Esp32Node> nodes = const []}) {
  return FieldDashboardSummary(
    overallCondition: FieldConditionStatus.optimal,
    overallConditionLabel: 'Optimal Moisture Balance',
    awdStatusLabel: 'Moisture Sufficient',
    requiresIrrigation: false,
    isIrrigationRunning: false,
    recommendedActionText: 'No action required.',
    lastUpdated: DateTime.now(),
    centralIrrigation: CentralizedIrrigation(
      id: 'central-system-01',
      systemName: 'Main Field Irrigation Hub',
      mainPumpState: PumpState.idle,
      distributionValveState: ValveState.closed,
      flowRateLitersPerMin: 0.0,
      pressureBar: 0.0,
      mode: SystemMode.manual,
      activeDurationMinutes: 0,
      lastStateChange: DateTime.now(),
    ),
    monitoringZones: const [],
    connectedNodes: nodes,
    activeAlerts: const [],
    recommendations: const [],
  );
}

Esp32Node _node({
  String id = 'ARVANODE-001',
  double? soilMoisturePercent,
  double? waterLevelCm,
  double? waterLevelDistanceCm,
  String? soilSensorHealth,
  String? ultrasonicSensorHealth,
  String? telemetryStatus,
  bool isOnline = true,
}) {
  return Esp32Node(
    id: id,
    macAddress: '8C:4F:00:AB:CD:01',
    displayName: id,
    assignedZoneId: '1',
    assignedZoneCode: 'Q1',
    assignmentStatus: 'ASSIGNED_TO_ZONE',
    pairingStatus: 'PAIRED',
    connectivityStatus: isOnline ? 'ONLINE' : 'OFFLINE',
    soilSensorHealth: soilSensorHealth,
    ultrasonicSensorHealth: ultrasonicSensorHealth,
    telemetryStatus: telemetryStatus,
    transmissionConfig: const TransmissionConfig(intervalSeconds: 2),
    isOnline: isOnline,
    lifecycleState: NodeLifecycleStatus.active,
    lastSeen: DateTime.now(),
    soilMoisturePercent: soilMoisturePercent,
    waterLevelCm: waterLevelCm,
    waterLevelDistanceCm: waterLevelDistanceCm,
    batteryPercent: 95,
  );
}

void main() {
  group('Latest telemetry snapshot mapping', () {
    test('keeps a reported numeric zero and separates it from missing data', () {
      final snapshots = ApiMappers.nodeTelemetrySnapshots({
        'serverTime': '2026-10-22T20:02:40',
        'nodes': [
          {
            'nodeId': 'ARVANODE-001',
            'soilMoisturePercent': 0.0,
            'waterLevelDistanceCm': 0.0,
            'waterLevelCm': 0.0,
            'soilSensorHealth': 'DISCONNECTED',
            'ultrasonicSensorHealth': 'TIMEOUT',
            'telemetryStatus': 'SENSOR_FAILURE',
            'isOnline': true,
            'hasTelemetry': true,
          },
          {
            'nodeId': 'ARVANODE-002',
            'soilMoisturePercent': null,
            'waterLevelDistanceCm': null,
            'hasTelemetry': false,
            'isOnline': false,
          },
        ],
      });

      expect(snapshots, hasLength(2));

      final failing = snapshots.firstWhere((s) => s.nodeId == 'ARVANODE-001');
      expect(failing.soilMoisturePercent, equals(0.0));
      expect(failing.waterLevelCm, equals(0.0));
      expect(failing.hasTelemetry, isTrue);
      expect(failing.isSoilSensorFailed, isTrue);
      expect(failing.isUltrasonicSensorFailed, isTrue);
      expect(failing.hasSensorFailure, isTrue);

      final missing = snapshots.firstWhere((s) => s.nodeId == 'ARVANODE-002');
      expect(missing.soilMoisturePercent, isNull);
      expect(missing.waterLevelCm, isNull);
      expect(missing.hasTelemetry, isFalse);
      expect(missing.hasSensorFailure, isFalse);
    });

    test('a snapshot replaces telemetry but never the pairing or zone state', () {
      final node = _node(soilMoisturePercent: 42.0, waterLevelCm: 12.0);

      final updated = node.applyTelemetrySnapshot(
        const NodeTelemetrySnapshot(
          nodeId: 'ARVANODE-001',
          soilMoisturePercent: 55.5,
          waterLevelCm: 9.25,
          waterLevelDistanceCm: 30.0,
          isOnline: true,
          hasTelemetry: true,
          telemetryStatus: 'OK',
        ),
      );

      expect(updated.soilMoisturePercent, equals(55.5));
      expect(updated.waterLevelCm, equals(9.25));
      expect(updated.waterLevelDistanceCm, equals(30.0));
      expect(updated.isOnline, isTrue);

      // Pairing and assignment stay independent from the telemetry state.
      expect(updated.pairingStatus, equals('PAIRED'));
      expect(updated.assignmentStatus, equals('ASSIGNED_TO_ZONE'));
      expect(updated.assignedZoneCode, equals('Q1'));
    });

    test('an empty snapshot clears outdated measurements instead of keeping them', () {
      final node = _node(soilMoisturePercent: 42.0, waterLevelCm: 12.0);

      final updated = node.applyTelemetrySnapshot(
        const NodeTelemetrySnapshot(nodeId: 'ARVANODE-001'),
      );

      expect(updated.soilMoisturePercent, isNull);
      expect(updated.waterLevelCm, isNull);
      expect(updated.waterLevelDistanceCm, isNull);
      expect(updated.pairingStatus, equals('PAIRED'));
    });
  });

  group('Dashboard telemetry refresh', () {
    test('the poll requests only the nodes of the loaded topology', () async {
      final source = _FakeTelemetrySource(const [
        NodeTelemetrySnapshot(
          nodeId: 'NODE-Q1',
          soilMoisturePercent: 61.0,
          waterLevelCm: 9.25,
          waterLevelDistanceCm: 30.0,
          isOnline: true,
          hasTelemetry: true,
        ),
      ]);
      final repository = FieldDashboardRepositoryImpl(telemetrySource: source);

      await repository.fetchDashboardSummary();
      final summary = await repository.refreshLatestTelemetry();

      expect(source.lastRequestedNodeIds, isNotNull);
      expect(source.lastRequestedNodeIds, contains('NODE-Q1'));
      // Exactly the nodes of the loaded topology are requested, nothing else.
      expect(source.lastRequestedNodeIds, hasLength(4));

      final refreshed = summary.connectedNodes
          .firstWhere((node) => node.id == 'NODE-Q1');
      expect(refreshed.soilMoisturePercent, equals(61.0));
      expect(refreshed.waterLevelCm, equals(9.25));
      expect(refreshed.isOnline, isTrue);
    });

    testWidgets('the dashboard refreshes on a 5 second cycle without overlapping requests',
        (tester) async {
      final repository = _RecordingDashboardRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            repository: repository,
            enableLivePolling: true,
          ),
        ),
      );

      // Initial topology load.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repository.topologyLoads, 1);
      expect(repository.telemetryPolls, 1);

      // Nothing happens before the next 5 second cycle.
      await tester.pump(const Duration(seconds: 2));
      expect(repository.telemetryPolls, 1);

      // The next cycle refreshes the telemetry.
      await tester.pump(const Duration(seconds: 4));
      expect(repository.telemetryPolls, 2);

      await tester.pump(const Duration(seconds: 6));
      expect(repository.telemetryPolls, 3);
    });
  });

  group('ConnectedNodesCard measurement rendering', () {
    testWidgets('shows a reported zero and a placeholder for missing data',
        (tester) async {
      final zeroNode = _node(
        id: 'ARVANODE-001',
        soilMoisturePercent: 0.0,
        waterLevelCm: 0.0,
        soilSensorHealth: 'DISCONNECTED',
        ultrasonicSensorHealth: 'TIMEOUT',
        telemetryStatus: 'SENSOR_FAILURE',
      );
      final missingNode = _node(
        id: 'ARVANODE-002',
        soilMoisturePercent: null,
        waterLevelCm: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ConnectedNodesCard(
                nodes: [zeroNode, missingNode],
                zones: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The reported zero is rendered as a numeric zero.
      expect(find.text('0.0%'), findsOneWidget);
      expect(find.text('0.0 cm'), findsOneWidget);
      // The node without telemetry renders a placeholder instead of a fake zero.
      expect(find.text('--'), findsNWidgets(2));
    });
  });
}
