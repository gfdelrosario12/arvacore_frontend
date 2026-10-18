import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/awd/data/repositories/awd_repository.dart';
import 'package:aquaflow_frontend/features/awd/domain/models/awd_analytics_summary.dart';
import 'package:aquaflow_frontend/features/awd/domain/models/awd_recommendation.dart';
import 'package:aquaflow_frontend/features/awd/domain/models/awd_threshold_config.dart';
import 'package:aquaflow_frontend/features/awd/domain/services/awd_rule_engine.dart';
import 'package:aquaflow_frontend/features/awd/presentation/awd_analytics_screen.dart';
import 'package:aquaflow_frontend/features/zones/data/datasources/zone_data_source.dart';
import 'package:aquaflow_frontend/features/zones/data/repositories/zone_repository.dart';

void main() {
  group('AwdRuleEngine Unit Tests', () {
    late ZoneRepository zoneRepo;

    setUp(() {
      zoneRepo = ZoneRepositoryImpl();
    });

    test('evaluates field AWD summary and reflood recommendation correctly', () async {
      final zones = await zoneRepo.fetchMonitoringZones(
        mockState: ZoneMockState.normal,
      );

      final summary = AwdRuleEngine.evaluateFieldAwd(
        zones: zones,
        config: const AwdThresholdConfig(
          refloodTriggerCm: 1.0, // Q4 is 0.5 cm, below 1.0 cm
        ),
      );

      expect(summary.isInsufficientData, isFalse);
      expect(summary.totalNodes, equals(4));
      expect(summary.fieldStatus, equals(FieldAwdStatus.refloodNeeded));
      expect(summary.recommendation.action, equals(IrrigationAction.irrigate));
      expect(summary.recommendation.rationale, contains('reflood'));
    });

    test('returns insufficient data summary when zero nodes report or quorum unmet', () async {
      final summaryEmpty = AwdRuleEngine.evaluateFieldAwd(
        zones: const [],
      );
      expect(summaryEmpty.isInsufficientData, isTrue);
      expect(summaryEmpty.recommendation.title, contains('Insufficient Telemetry Data'));

      final zones = await zoneRepo.fetchMonitoringZones(
        mockState: ZoneMockState.normal,
      );
      final subset = zones.take(2).toList();
      final summaryQuorum = AwdRuleEngine.evaluateFieldAwd(
        zones: subset,
        minRequiredZones: 4,
      );
      expect(summaryQuorum.isInsufficientData, isTrue);
    });

    test('computes quad-zone drying rates per day correctly', () async {
      final zones = await zoneRepo.fetchMonitoringZones(
        mockState: ZoneMockState.normal,
      );

      final summary = AwdRuleEngine.evaluateFieldAwd(zones: zones);

      expect(summary.zoneDryingRates.length, equals(4));
      final q1Rate = summary.zoneDryingRates.firstWhere((r) => r.zoneCode == 'Q1');
      expect(q1Rate.dryingRateCmPerDay, greaterThan(0));
    });
  });

  group('AwdAnalyticsScreen Widget Tests', () {
    testWidgets('renders AWD Analytics screen with overview, recommendation, and thresholds',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AwdAnalyticsScreen(),
        ),
      );

      expect(find.text('Aggregating field telemetry & evaluating AWD rules...'),
          findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('ArvaCore AWD Analytics'), findsOneWidget);
      expect(find.text('Field-Wide AWD Condition'), findsOneWidget);
      expect(find.text('Node Autonomous Decision'), findsOneWidget);
      expect(find.text('Configurable AWD Threshold Rules'), findsOneWidget);
      expect(
          find.text('Quad-Zone Drying & Wetting Rate Comparison'), findsOneWidget);

      // Verify read-only guardrails: zone-level pump triggers are omitted
      expect(find.text('Start Irrigation (Q1)'), findsNothing);
      expect(find.text('Stop Irrigation (Q4)'), findsNothing);
    });

    testWidgets('renders insufficient data state when fewer than 4 nodes report',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AwdAnalyticsScreen(
            mockState: AwdMockState.insufficientData,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Insufficient Telemetry Data'), findsOneWidget);
      expect(
          find.textContaining('Active zone telemetry'),
          findsOneWidget);
    });

    testWidgets('renders stale telemetry warning banner when data is outdated',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AwdAnalyticsScreen(
            mockState: AwdMockState.stale,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Stale Telemetry Notice'), findsOneWidget);
    });

    testWidgets('renders error state on engine fetch failure',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AwdAnalyticsScreen(
            mockState: AwdMockState.error,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AWD Analytics Engine Error'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);
    });
  });
}
