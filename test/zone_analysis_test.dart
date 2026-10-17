import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/zones/data/datasources/zone_data_source.dart';
import 'package:aquaflow_frontend/features/zones/domain/models/monitoring_zone.dart';
import 'package:aquaflow_frontend/features/zones/presentation/zone_analysis_screen.dart';

void main() {
  group('ZoneTrendAnalysis Unit Tests', () {
    test('computes Rising trend for increasing water levels', () {
      final history = [3.0, 3.5, 4.0, 4.5, 5.0];
      final trend = ZoneTrendAnalysis.fromHistory(history);

      expect(trend.direction, equals(TrendDirection.rising));
      expect(trend.rateCmPerHour, equals(0.5));
      expect(trend.label, contains('Rising (+0.5 cm/h)'));
    });

    test('computes Falling trend for decreasing water levels', () {
      final history = [5.0, 4.2, 3.4, 2.6, 1.8];
      final trend = ZoneTrendAnalysis.fromHistory(history);

      expect(trend.direction, equals(TrendDirection.falling));
      expect(trend.rateCmPerHour, equals(-0.8));
      expect(trend.label, contains('Falling (-0.8 cm/h)'));
    });

    test('computes Stable trend for constant water levels', () {
      final history = [4.5, 4.5, 4.6, 4.5];
      final trend = ZoneTrendAnalysis.fromHistory(history);

      expect(trend.direction, equals(TrendDirection.stable));
      expect(trend.label, contains('Stable'));
    });
  });

  group('ZoneAnalysisScreen Widget Tests', () {
    testWidgets('renders zone analysis details, metrics, trend, and read-only banner',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ZoneAnalysisScreen(
            zoneCode: 'Q1',
          ),
        ),
      );

      expect(find.text('Fetching quadrant telemetry & history...'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Q1 Detailed Analysis'), findsOneWidget);
      expect(find.text('North-East Field Quadrant'), findsOneWidget);
      expect(find.text('Water Condition Trend Analysis'), findsOneWidget);
      expect(find.textContaining('Rising'), findsWidgets);
      expect(find.text('Soil Moisture'), findsOneWidget);
      expect(find.text('Water Depth'), findsOneWidget);
      expect(find.text('Historical Water Level'), findsOneWidget);
      expect(find.text('Sensor Node Hardware Diagnostics'), findsOneWidget);

      // Verify strict prohibition of zone-level pump or valve activation controls
      expect(find.text('Start Irrigation'), findsNothing);
      expect(find.text('Stop Irrigation'), findsNothing);
      expect(find.text('Pump Control'), findsNothing);
      expect(find.text('Valve Control'), findsNothing);
    });

    testWidgets('toggles timeframe between 24h and 7d trend history',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ZoneAnalysisScreen(
            zoneCode: 'Q1',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('24-Hour'), findsOneWidget);

      final chipFinder = find.text('7d History');
      await tester.ensureVisible(chipFinder);
      await tester.tap(chipFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.textContaining('7-Day'), findsOneWidget);
    });

    testWidgets('renders error state on telemetry fetch failure',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ZoneAnalysisScreen(
            zoneCode: 'Q1',
            mockState: ZoneMockState.error,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Telemetry Gateway Error'), findsOneWidget);
      expect(find.textContaining('Unable to establish LoRaWAN'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);
    });
  });
}
