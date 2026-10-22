import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/alerts/data/repositories/alert_repository.dart';
import 'package:aquaflow_frontend/features/alerts/domain/models/models.dart';
import 'package:aquaflow_frontend/features/alerts/presentation/alert_detail_screen.dart';
import 'package:aquaflow_frontend/features/alerts/presentation/alerts_screen.dart';
import 'package:aquaflow_frontend/features/alerts/presentation/providers/alert_provider.dart';

void main() {
  group('Alert Domain & Repository Unit Tests', () {
    late MockAlertRepository repository;

    setUp(() {
      repository = MockAlertRepository();
    });

    test('fetches initial seed alerts with correct source attribution', () async {
      final alerts = await repository.fetchAlerts();
      expect(alerts.isNotEmpty, isTrue);

      final irrigationAlert = alerts.firstWhere((a) => a.source.type == AlertSourceType.centralIrrigation);
      expect(irrigationAlert.source.targetScope, equals('ENTIRE FIELD'));

      final nodeAlert = alerts.firstWhere((a) => a.source.type == AlertSourceType.monitoringZone);
      expect(nodeAlert.source.targetScope, startsWith('Q'));
    });

    test('marks individual alert as read', () async {
      final alerts = await repository.fetchAlerts();
      final unreadAlert = alerts.firstWhere((a) => !a.isRead);

      await repository.markAsRead(unreadAlert.id);
      final updatedList = await repository.fetchAlerts();
      final updatedAlert = updatedList.firstWhere((a) => a.id == unreadAlert.id);

      expect(updatedAlert.isRead, isTrue);
    });

    test('marks all alerts as read', () async {
      await repository.markAllAsRead();
      final updatedList = await repository.fetchAlerts();
      expect(updatedList.every((a) => a.isRead), isTrue);
    });
  });

  group('AlertNotifier Unit Tests', () {
    late MockAlertRepository repository;
    late AlertNotifier notifier;

    setUp(() {
      repository = MockAlertRepository();
      notifier = AlertNotifier(repository: repository);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('filters alerts by severity', () async {
      await notifier.fetchAlerts();
      notifier.setSeverityFilter(AlertSeverity.critical);

      final filtered = notifier.state.filteredAlerts;
      expect(filtered.every((a) => a.severity == AlertSeverity.critical), isTrue);
    });

    test('filters alerts by unread status', () async {
      await notifier.fetchAlerts();
      notifier.toggleUnreadFilter(true);

      final filtered = notifier.state.filteredAlerts;
      expect(filtered.every((a) => !a.isRead), isTrue);
    });

    test('filters alerts by search query', () async {
      await notifier.fetchAlerts();
      notifier.setSearchQuery('Q4');

      final filtered = notifier.state.filteredAlerts;
      expect(filtered.isNotEmpty, isTrue);
      expect(filtered.every((a) => a.title.contains('Q4') || a.source.name.contains('Q4')), isTrue);
    });
  });

  group('AlertsScreen & Detail Widget Tests', () {
    testWidgets('renders AlertsScreen with title, search, and list items', (tester) async {
      final repository = MockAlertRepository();
      final notifier = AlertNotifier(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: AlertsScreen(notifier: notifier),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('System Alerts'), findsOneWidget);
      expect(find.text('Critical Dryness: Quadrant Q4'), findsOneWidget);
      expect(find.text('Field Reflood Recommended'), findsOneWidget);
    });

    testWidgets('navigates to AlertDetailScreen on item tap', (tester) async {
      final repository = MockAlertRepository();
      final notifier = AlertNotifier(repository: repository);

      await tester.pumpWidget(
        MaterialApp(
          home: AlertsScreen(notifier: notifier),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Critical Dryness: Quadrant Q4'));
      await tester.pumpAndSettle();

      expect(find.text('Alert Details'), findsOneWidget);
      expect(find.text('SCOPE: Q4'), findsOneWidget);
      expect(find.text('Recommended Action'), findsOneWidget);
    });

    testWidgets('renders AlertDetailScreen with scope ENTIRE FIELD for central irrigation alert', (tester) async {
      final alert = SystemAlert(
        id: 'TEST-ALT-01',
        title: 'Central Irrigation Active',
        description: 'Main pump running for entire field.',
        severity: AlertSeverity.info,
        category: AlertCategory.irrigation,
        source: AlertSource.centralIrrigation,
        timestamp: DateTime.now(),
        recommendedAction: 'Check main line pressure on Control screen.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AlertDetailScreen(alert: alert),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alert Details'), findsOneWidget);
      expect(find.text('SCOPE: ENTIRE FIELD'), findsOneWidget);
      expect(find.text('Open Manual Control'), findsOneWidget);
    });
  });
}

