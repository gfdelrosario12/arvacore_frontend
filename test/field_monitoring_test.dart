import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/field/presentation/field_screen.dart';
import 'package:aquaflow_frontend/features/zones/data/datasources/zone_data_source.dart';
import 'package:aquaflow_frontend/features/zones/data/repositories/zone_repository.dart';
import 'package:aquaflow_frontend/features/zones/domain/models/monitoring_zone.dart';
import 'package:aquaflow_frontend/features/nodes/data/repositories/node_repository.dart';

class FailingZoneRepository implements ZoneRepository {
  @override
  Future<List<MonitoringZone>> fetchMonitoringZones({
    ZoneMockState mockState = ZoneMockState.normal,
    String? fieldId,
  }) async {
    throw Exception('Gateway node (GW-01) is offline: connection timeout');
  }

  @override
  Future<MonitoringZone?> fetchZoneDetails(
    String code, {
    ZoneMockState mockState = ZoneMockState.normal,
  }) async {
    throw Exception('Gateway offline');
  }

  @override
  Future<MonitoringZone?> fetchZoneById(
    String id, {
    ZoneMockState mockState = ZoneMockState.normal,
  }) async {
    throw Exception('Gateway offline');
  }

  @override
  Future<MonitoringZone> createZone({
    required String name,
    required double area,
    required String cropType,
    double? waterAllocationLimit,
  }) async {
    throw Exception('Gateway offline');
  }

  @override
  Future<void> deleteZone(String id, {String? fieldId}) async {
    throw Exception('Gateway offline');
  }
}

void main() {
  group('ZoneRepository Diagnostic Tests', () {
    late ZoneRepository repository;

    setUp(() {
      repository = ZoneRepositoryImpl();
    });

    test('fetchMonitoringZones returns signal diagnostics (RSSI, SNR, battery)',
        () async {
      final zones = await repository.fetchMonitoringZones(
        mockState: ZoneMockState.normal,
      );

      expect(zones.length, equals(4));
      final q1 = zones.firstWhere((z) => z.code == 'Q1');
      expect(q1.isOnline, isTrue);
      expect(q1.rssiDbm, equals(-78));
      expect(q1.snrDb, equals(10.4));
      expect(q1.batteryPercent, equals(94));
      expect(q1.waterLevelHistory, isNotEmpty);
    });

    test('fetchMonitoringZones returns stale zones when requested', () async {
      final zones = await repository.fetchMonitoringZones(
        mockState: ZoneMockState.stale,
      );

      expect(zones.length, equals(4));
      final q1 = zones.firstWhere((z) => z.code == 'Q1');
      final hoursAgo = DateTime.now().difference(q1.lastUpdated).inHours;
      expect(hoursAgo, greaterThanOrEqualTo(2));
    });

    test('fetchMonitoringZones throws gateway error on unavailable state',
        () async {
      expect(
        () => repository.fetchMonitoringZones(
          mockState: ZoneMockState.unavailable,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('FieldScreen Widget Tests', () {
    testWidgets('renders Field Monitoring screen and 2x2 grid in normal state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FieldScreen(),
        ),
      );

      expect(find.text('Loading Field Zone Telemetry...'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.textContaining('Distributed Field Monitoring Nodes'), findsOneWidget);
      expect(find.text('Field Telemetry Matrix'), findsOneWidget);
      expect(find.textContaining('ArvaNode Monitoring Overview'), findsOneWidget);
      expect(find.text('Q1'), findsWidgets);
      expect(find.text('Q2'), findsWidgets);
      expect(find.text('Q3'), findsWidgets);
      expect(find.text('Q4'), findsWidgets);
    });

    testWidgets(
        'tapping a zone card opens ZoneDetailBottomSheet with diagnostics and read-only notice',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FieldScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap quadrant Q1 card
      await tester.ensureVisible(find.text('Q1').first);
      await tester.tap(find.text('Q1').first);
      await tester.pumpAndSettle();

      // Inspector sheet opens
      expect(find.text('Sensor Diagnostics & Network Info'), findsOneWidget);
      expect(find.textContaining('Signal Strength (RSSI)'), findsOneWidget);
      expect(find.textContaining('-78 dBm'), findsOneWidget);
      expect(find.textContaining('Read-Only Monitoring Point (Q1)'), findsOneWidget);
    });

    testWidgets('renders gateway unavailable error state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FieldScreen(
            repository: FailingZoneRepository(),
            nodeRepository: MockNodeRepository(initialNodes: const []),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ArvaNet Gateway Telemetry Error'), findsOneWidget);
      expect(find.textContaining('Gateway node (GW-01) is offline'), findsOneWidget);
    });
  });
}
