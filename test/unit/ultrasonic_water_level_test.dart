import 'package:aquaflow_frontend/core/api/api_mappers.dart';
import 'package:aquaflow_frontend/features/home/presentation/widgets/ultrasonic_water_level_diagram.dart';
import 'package:aquaflow_frontend/features/nodes/domain/models/esp32_node.dart';
import 'package:aquaflow_frontend/features/nodes/domain/models/transmission_config.dart';
import 'package:aquaflow_frontend/features/zones/domain/models/monitoring_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ultrasonic Water Level Physics Formula', () {
    test('calculates correct water level: Calibrated Bottom - Measured Distance', () {
      // Example: Datum 40 inches (101.6 cm), Measured 16 inches (40.64 cm) -> 24 inches (60.96 cm)
      final level = ApiMappers.calculateWaterLevelFromDistance(
        40.64,
        calibratedBottomCm: 101.6,
      );
      expect(level, closeTo(60.96, 0.01));
    });

    test('clamps water level to 0.0 when ball is resting at bottom plate', () {
      final level = ApiMappers.calculateWaterLevelFromDistance(
        101.6,
        calibratedBottomCm: 101.6,
      );
      expect(level, equals(0.0));

      final belowBottom = ApiMappers.calculateWaterLevelFromDistance(
        105.0,
        calibratedBottomCm: 101.6,
      );
      expect(belowBottom, equals(0.0));
    });

    test('clamps water level to maximum measurable limit of 3 feet (91.44 cm / 36 in)', () {
      final level = ApiMappers.calculateWaterLevelFromDistance(
        5.0,
        calibratedBottomCm: 101.6,
      );
      expect(level, equals(ApiMappers.maxMeasurableWaterLevelCm));
    });

    test('adapts to deep bench installations where distance exceeds standard 101.6 cm datum', () {
      // NODE-C3E8 hardware bench setup transmitting 123.15 cm
      final level = ApiMappers.calculateWaterLevelFromDistance(123.15);
      expect(level, isNotNull);
      expect(level!, greaterThanOrEqualTo(0.0));
      expect(level, lessThanOrEqualTo(ApiMappers.maxMeasurableWaterLevelCm));
    });

    test('rejects invalid echoes, sensor timeouts, and out-of-range measurements', () {
      // Below physical transducer blind zone (< 2cm)
      expect(ApiMappers.calculateWaterLevelFromDistance(1.5), isNull);
      expect(ApiMappers.calculateWaterLevelFromDistance(0.0), isNull);
      expect(ApiMappers.calculateWaterLevelFromDistance(-10.0), isNull);

      // Above maximum physical timeout (> 500cm)
      expect(ApiMappers.calculateWaterLevelFromDistance(600.0), isNull);

      // Null distance
      expect(ApiMappers.calculateWaterLevelFromDistance(null), isNull);
    });
  });

  group('Esp32Node & MonitoringZone Water Level Distance Persistence', () {
    test('Esp32Node preserves waterLevelDistanceCm through copyWith and serialization', () {
      final node = Esp32Node(
        id: 'NODE-C3E8',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        displayName: 'Test ArvaNode',
        transmissionConfig: const TransmissionConfig(),
        isOnline: true,
        lastSeen: DateTime.now(),
        waterLevelDistanceCm: 45.2,
        waterLevelCm: 56.4,
      );

      expect(node.waterLevelDistanceCm, equals(45.2));
      expect(node.waterLevelCm, equals(56.4));

      final updated = node.copyWith(waterLevelDistanceCm: 38.0);
      expect(updated.waterLevelDistanceCm, equals(38.0));
      expect(updated.waterLevelCm, equals(56.4));

      final json = updated.toJson();
      expect(json['waterLevelDistanceCm'], equals(38.0));

      final restored = Esp32Node.fromJson(json);
      expect(restored.waterLevelDistanceCm, equals(38.0));
    });

    test('MonitoringZone preserves waterLevelDistanceCm and calibratedBottomOffsetCm', () {
      final zone = MonitoringZone(
        id: '1',
        code: 'Q1',
        name: 'Zone 1',
        soilMoisturePercent: 45.0,
        waterLevelCm: 60.96,
        waterLevelDistanceCm: 40.64,
        calibratedBottomOffsetCm: 101.6,
        temperatureCelsius: 28.0,
        humidityPercent: 70.0,
        batteryPercent: 95,
        status: ZoneStatus.optimal,
        lastUpdated: DateTime.now(),
      );

      expect(zone.waterLevelDistanceCm, equals(40.64));
      expect(zone.calibratedBottomOffsetCm, equals(101.6));

      final copied = zone.copyWith(waterLevelDistanceCm: 35.0);
      expect(copied.waterLevelDistanceCm, equals(35.0));
      expect(copied.calibratedBottomOffsetCm, equals(101.6));
    });
  });

  group('UltrasonicWaterLevelDiagram Widget Tests', () {
    testWidgets('renders diagram with valid node telemetry and allows switching units', (tester) async {
      final node = Esp32Node(
        id: 'NODE-C3E8',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        displayName: 'Test Node',
        transmissionConfig: const TransmissionConfig(),
        isOnline: true,
        lastSeen: DateTime.now(),
        waterLevelDistanceCm: 40.64,
        waterLevelCm: 60.96,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UltrasonicWaterLevelDiagram(
                nodes: [node],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and metrics
      expect(find.text('Ultrasonic Water-Level Column'), findsOneWidget);
      expect(find.text('CALCULATED WATER LEVEL'), findsOneWidget);
      expect(find.text('ECHO DISTANCE'), findsOneWidget);
      expect(find.text('TOTAL DATUM'), findsOneWidget);

      // Initial unit is inches (60.96 cm / 2.54 = 24.0 in)
      expect(find.text('24.0 in'), findsOneWidget);

      // Switch to Centimeters (cm)
      await tester.tap(find.text('cm'));
      await tester.pumpAndSettle();
      expect(find.text('61.0 cm'), findsOneWidget);

      // Switch to Feet (ft)
      await tester.tap(find.text('ft'));
      await tester.pumpAndSettle();
      expect(find.text('2.00 ft'), findsOneWidget);
    });

    testWidgets('displays invalid echo warning gracefully when sensor has no valid distance', (tester) async {
      final offlineNode = Esp32Node(
        id: 'NODE-OFFLINE',
        macAddress: '00:00:00:00:00:00',
        displayName: 'Disconnected Node',
        transmissionConfig: const TransmissionConfig(),
        isOnline: false,
        lastSeen: DateTime.now(),
        waterLevelDistanceCm: null,
        waterLevelCm: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UltrasonicWaterLevelDiagram(
                nodes: [offlineNode],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('NO VALID ECHO / OUT OF RANGE'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
    });
  });
}

