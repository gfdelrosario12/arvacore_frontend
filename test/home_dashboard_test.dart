import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/home/data/repositories/field_dashboard_repository.dart';
import 'package:aquaflow_frontend/features/home/presentation/home_screen.dart';

void main() {
  group('FieldDashboardRepository Unit Tests', () {
    late FieldDashboardRepository repository;

    setUp(() {
      repository = FieldDashboardRepositoryImpl();
    });

    test('fetchDashboardSummary returns normal summary with Q1-Q4 zones', () async {
      final summary = await repository.fetchDashboardSummary(
        mockState: MockState.normal,
      );

      expect(summary.monitoringZones.length, equals(4));
      expect(summary.highestMoistureZoneCode, isNotNull);
      expect(summary.lowestMoistureZoneCode, isNotNull);
      expect(summary.isStale, isFalse);
    });

    test('fetchDashboardSummary returns stale summary when requested', () async {
      final summary = await repository.fetchDashboardSummary(
        mockState: MockState.stale,
      );

      expect(summary.isStale, isTrue);
    });

    test('fetchDashboardSummary returns empty summary when requested', () async {
      final summary = await repository.fetchDashboardSummary(
        mockState: MockState.empty,
      );

      expect(summary.monitoringZones, isEmpty);
      expect(summary.activeAlerts, isEmpty);
    });

    test('fetchDashboardSummary throws exception on error state', () async {
      expect(
        () => repository.fetchDashboardSummary(mockState: MockState.error),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('HomeScreen Widget Tests', () {
    testWidgets('renders AquaSense Dashboard content in normal state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      // Loading state initially
      expect(find.text('Loading AquaSense Dashboard...'), findsOneWidget);

      await tester.pumpAndSettle();

      // Content loaded
      expect(find.text('AquaSense Dashboard'), findsOneWidget);
      expect(find.text('Overall Field Condition'), findsOneWidget);
      expect(find.textContaining('Autonomous Edge Irrigation'), findsWidgets);
      expect(find.text('Field Recommendations'), findsOneWidget);
    });

    testWidgets('renders stale warning badge when telemetry is stale',
        (WidgetTester tester) async {
      final repository = FieldDashboardRepositoryImpl();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            repository: repository,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open tune menu to switch to stale state
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stale Telemetry'));
      await tester.pumpAndSettle();

      expect(find.text('STALE TELEMETRY DATA (>15m)'), findsOneWidget);
    });

    testWidgets('renders error state widget when fetch fails',
        (WidgetTester tester) async {
      final repository = FieldDashboardRepositoryImpl();

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            repository: repository,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open tune menu to switch to error state
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Error State'));
      await tester.pumpAndSettle();

      expect(find.text('Telemetry Connection Error'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);
    });
  });
}
