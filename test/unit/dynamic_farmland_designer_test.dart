import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/field/domain/models/field.dart';
import 'package:aquaflow_frontend/features/field/presentation/widgets/farmland_designer_view.dart';
import 'package:aquaflow_frontend/features/nodes/domain/models/models.dart';
import 'package:aquaflow_frontend/features/zones/domain/models/monitoring_zone.dart';

import '../support/zone_fixtures.dart';

void main() {
  group('Dynamic Farmland Domain & Serialization Tests', () {
    test('Field model preserves physical dimensions and operational status', () {
      final now = DateTime.now();
      final field = Field(
        id: 'field-101',
        name: 'Demo Rice Paddy',
        description: 'AWD research parcel',
        lengthMeters: 250.0,
        widthMeters: 160.0,
        totalArea: 4.0,
        areaUnit: 'hectares',
        shapeType: 'RECTANGULAR',
        operationalStatus: 'READY',
        createdAt: now,
        updatedAt: now,
      );

      expect(field.id, 'field-101');
      expect(field.name, 'Demo Rice Paddy');
      expect(field.lengthMeters, 250.0);
      expect(field.widthMeters, 160.0);
      expect(field.totalArea, 4.0);
      expect(field.areaUnit, 'hectares');
      expect(field.shapeType, 'RECTANGULAR');
      expect(field.operationalStatus, 'READY');

      final updated = field.copyWith(
        operationalStatus: 'MONITORING',
        totalArea: 4.2,
      );
      expect(updated.operationalStatus, 'MONITORING');
      expect(updated.totalArea, 4.2);
      expect(updated.lengthMeters, 250.0);
    });

    test('MonitoringZone preserves dynamic division and relative coordinates', () {
      final zone = sampleZone(code: 'Q1').copyWith(
        id: 'zone-01',
        fieldId: 'field-101',
        name: 'North Inflow Sector',
        areaType: 'QUARTER',
        cropType: 'Rice - NSIC Rc 222',
        lengthMeters: 125.0,
        widthMeters: 80.0,
        areaSize: 1.0,
        areaUnit: 'hectares',
        relativeX: 0.0,
        relativeY: 0.0,
        relativeWidth: 0.5,
        relativeHeight: 0.5,
        operationalStatus: 'READY',
      );

      expect(zone.code, 'Q1');
      expect(zone.areaType, 'QUARTER');
      expect(zone.cropType, 'Rice - NSIC Rc 222');
      expect(zone.relativeX, 0.0);
      expect(zone.relativeWidth, 0.5);
      expect(zone.relativeHeight, 0.5);
      expect(zone.isArchived, isFalse);

      final splitZone = zone.copyWith(
        code: 'Q1-A',
        relativeWidth: 0.25,
      );
      expect(splitZone.code, 'Q1-A');
      expect(splitZone.relativeWidth, 0.25);
    });
  });

  group('FarmlandDesignerView Widget Tests', () {
    testWidgets('renders Farmland properties, dimensions, and action buttons', (tester) async {
      final now = DateTime.now();
      final field = Field(
        id: '1',
        name: 'ArvaCore Demonstration Farmland',
        lengthMeters: 200.0,
        widthMeters: 100.0,
        totalArea: 2.0,
        areaUnit: 'hectares',
        operationalStatus: 'READY',
        createdAt: now,
        updatedAt: now,
      );

      final List<MonitoringZone> zones = [
        sampleZone(code: 'Q1').copyWith(
          id: '1',
          fieldId: '1',
          name: 'Northwest Quarter',
          areaType: 'QUARTER',
          cropType: 'Rice',
          relativeX: 0.0,
          relativeY: 0.0,
          relativeWidth: 0.5,
          relativeHeight: 0.5,
          assignedNodeIds: ['node-01'],
        ),
        sampleZone(code: 'Q2').copyWith(
          id: '2',
          fieldId: '1',
          name: 'Northeast Quarter',
          areaType: 'QUARTER',
          cropType: 'Rice',
          relativeX: 0.5,
          relativeY: 0.0,
          relativeWidth: 0.5,
          relativeHeight: 0.5,
          assignedNodeIds: [],
        ),
      ];

      final List<Esp32Node> nodes = [
        Esp32Node(
          id: 'node-01',
          macAddress: '78:E3:6D:12:34:01',
          displayName: 'ArvaNode-01',
          assignedZoneId: '1',
          isOnline: true,
          batteryPercent: 94,
          soilMoisturePercent: 42.1,
          waterLevelCm: 2.4,
          lastSeen: now,
          transmissionConfig: TransmissionConfig(intervalSeconds: 3, lastConfiguredAt: now),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FarmlandDesignerView(
                field: field,
                zones: zones,
                nodes: nodes,
                onRefresh: () async {},
                onAssignNode: (nodeId, {int? fieldId, int? monitoringZoneId}) async => true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header properties
      expect(find.text('ArvaCore Demonstration Farmland'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);
      expect(find.textContaining('200.0m × 100.0m'), findsOneWidget);
      expect(find.text('Readiness'), findsOneWidget);
      expect(find.text('Edit Farmland'), findsOneWidget);

      // Toolbar action buttons
      expect(find.text('Add Area'), findsOneWidget);
      expect(find.text('Split Area'), findsOneWidget);
      expect(find.text('Merge Areas'), findsOneWidget);
      expect(find.text('Fit View'), findsOneWidget);

      // Zone codes rendered on canvas
      expect(find.text('Q1'), findsOneWidget);
      expect(find.text('Q2'), findsOneWidget);

      // Node badges
      expect(find.textContaining('ArvaNode-01 (94%)'), findsOneWidget);
      expect(find.text('Unmonitored'), findsOneWidget);
    });

    testWidgets('tapping a zone selects it and displays inspector details', (tester) async {
      final now = DateTime.now();
      final field = Field(
        id: '1',
        name: 'ArvaCore Demonstration Farmland',
        lengthMeters: 100.0,
        widthMeters: 100.0,
        totalArea: 1.0,
        areaUnit: 'hectares',
        operationalStatus: 'READY',
        createdAt: now,
        updatedAt: now,
      );

      final List<MonitoringZone> zones = [
        sampleZone(code: 'Q1').copyWith(
          id: '1',
          fieldId: '1',
          name: 'Northwest Quarter',
          areaType: 'QUARTER',
          cropType: 'Rice',
          relativeX: 0.0,
          relativeY: 0.0,
          relativeWidth: 1.0,
          relativeHeight: 1.0,
          assignedNodeIds: ['node-01'],
        ),
      ];

      final List<Esp32Node> nodes = [
        Esp32Node(
          id: 'node-01',
          macAddress: '78:E3:6D:12:34:01',
          displayName: 'ArvaNode-01',
          assignedZoneId: '1',
          isOnline: true,
          batteryPercent: 88,
          soilMoisturePercent: 38.5,
          waterLevelCm: -2.1,
          lastSeen: now,
          transmissionConfig: TransmissionConfig(intervalSeconds: 3, lastConfiguredAt: now),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FarmlandDesignerView(
                field: field,
                zones: zones,
                nodes: nodes,
                onRefresh: () async {},
                onAssignNode: (nodeId, {int? fieldId, int? monitoringZoneId}) async => true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Q1 to select it
      await tester.tap(find.text('Q1'));
      await tester.pumpAndSettle();

      // Inspector card appears
      expect(find.text('Northwest Quarter (Q1)'), findsOneWidget);
      expect(find.text('Assigned Hardware Telemetry'), findsOneWidget);
      expect(find.text('Soil Moisture'), findsOneWidget);
      expect(find.text('38.5%'), findsOneWidget);
      expect(find.text('Water Level'), findsOneWidget);
      expect(find.text('-2.1 cm'), findsOneWidget);
      expect(find.text('Battery Health'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
    });
  });
}

