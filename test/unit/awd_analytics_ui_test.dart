import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/awd/data/repositories/awd_repository.dart';
import 'package:aquaflow_frontend/features/awd/domain/models/awd_confidence.dart';
import 'package:aquaflow_frontend/features/awd/presentation/awd_analytics_screen.dart';
import 'package:aquaflow_frontend/features/home/domain/models/field_dashboard_summary.dart';
import 'package:aquaflow_frontend/features/home/presentation/widgets/field_condition_header_card.dart';
import 'package:aquaflow_frontend/features/irrigation/domain/models/centralized_irrigation.dart';
import 'package:aquaflow_frontend/features/zones/presentation/zone_analysis_screen.dart';
import '../support/zone_fixtures.dart';

void main() {
  group('AWD Analytics UI & Widget Tests', () {
    testWidgets('renders AwdAnalyticsScreen with confidence chip, crop stage, and threshold rules',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AwdAnalyticsScreen(repository: MockAwdRepository()),
        ),
      );

      // Loading state
      expect(find.text('Aggregating field telemetry & evaluating AWD rules...'), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Screen title and key section headers
      expect(find.text('ArvaCore AWD Analytics'), findsOneWidget);
      expect(find.text('Field-Wide AWD Condition'), findsOneWidget);
      expect(find.text('Node Autonomous Decision'), findsOneWidget);
      expect(find.text('Configurable AWD Threshold Rules'), findsOneWidget);

      // Confidence badge and crop growth stage
      expect(find.textContaining('Confidence'), findsWidgets);
      expect(find.textContaining('Stage'), findsWidgets);
    });

    testWidgets('renders responsive layout across mobile and desktop viewport sizes',
        (WidgetTester tester) async {
      // 1. Mobile viewport
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AwdAnalyticsScreen(repository: MockAwdRepository()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ArvaCore AWD Analytics'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // 2. Desktop viewport
      tester.view.physicalSize = const Size(1920, 1080);
      await tester.pumpWidget(
        MaterialApp(
          home: AwdAnalyticsScreen(repository: MockAwdRepository()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ArvaCore AWD Analytics'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('FieldConditionHeaderCard renders confidence chip alongside AWD condition',
        (WidgetTester tester) async {
      const confidence = AwdConfidence(
        level: AwdConfidenceLevel.high,
        score: 0.92,
        coverageRatio: 1.0,
        freshnessScore: 0.95,
        validityRatio: 1.0,
        contributingFactors: ['All nodes reporting fresh'],
        summaryMessage: 'High confidence telemetry',
      );

      final now = DateTime.now();
      final summary = FieldDashboardSummary(
        overallCondition: FieldConditionStatus.optimal,
        overallConditionLabel: 'Optimal AWD Drying',
        awdStatusLabel: 'Safe Drying Phase',
        requiresIrrigation: false,
        isIrrigationRunning: false,
        recommendedActionText: 'Maintain observation',
        lastUpdated: now,
        centralIrrigation: CentralizedIrrigation(
          id: 'sys-01',
          systemName: 'Main Pump',
          mainPumpState: PumpState.offline,
          distributionValveState: ValveState.closed,
          flowRateLitersPerMin: 0.0,
          pressureBar: 0.0,
          mode: SystemMode.manual,
          activeDurationMinutes: 0,
          lastStateChange: now,
        ),
        monitoringZones: [sampleZone(code: 'Z1')],
        activeAlerts: const [],
        recommendations: const [],
        confidence: confidence,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FieldConditionHeaderCard(summary: summary),
          ),
        ),
      );

      expect(find.text('Overall Field Condition'), findsOneWidget);
      expect(find.text('Optimal AWD Drying'), findsOneWidget);
      expect(find.text('SAFE DRYING PHASE'), findsOneWidget);
      expect(find.text('High Confidence (92%)'), findsOneWidget);
    });

    testWidgets('ZoneAnalysisScreen renders telemetry freshness and data reliability badges',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final zone = sampleZone(
        code: 'Z1',
        waterLevelCm: 4.5,
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ZoneAnalysisScreen(
            zoneCode: 'Z1',
            initialZone: zone,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Z1 Detailed Analysis'), findsOneWidget);
      expect(find.textContaining('Fresh'), findsWidgets);
      expect(find.text('Valid Telemetry'), findsOneWidget);
      expect(find.text('Sensor Node Hardware Diagnostics'), findsOneWidget);
      expect(find.text('Telemetry Quality'), findsOneWidget);
      expect(find.text('Telemetry Freshness'), findsOneWidget);
    });
  });
}
