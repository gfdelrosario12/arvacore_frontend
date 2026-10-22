import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/features/alerts/domain/models/models.dart';
import 'package:aquaflow_frontend/features/alerts/presentation/providers/alert_provider.dart';
import 'package:aquaflow_frontend/features/alerts/presentation/widgets/global_alert_overlay.dart';
import 'package:aquaflow_frontend/features/alerts/data/repositories/alert_repository.dart';

class FakeAlertRepository implements AlertRepository {
  List<SystemAlert> alerts = [];

  @override
  Future<List<SystemAlert>> fetchAlerts() async => alerts;

  @override
  Future<List<SystemAlert>> syncIncremental() async => alerts;

  @override
  Future<void> markAlertAsRead(String alertId) async {
    alerts = alerts.map((a) => a.id == alertId ? a.copyWith(isRead: true) : a).toList();
  }

  @override
  Future<void> acknowledgeAlert(String alertId) async => markAlertAsRead(alertId);

  @override
  Future<void> markAllAsRead() async {
    alerts = alerts.map((a) => a.copyWith(isRead: true)).toList();
  }

  @override
  Future<void> clearAllAlerts() async {
    alerts = [];
  }

  @override
  Stream<List<SystemAlert>> get alertStream => Stream.value(alerts);
}

void main() {
  testWidgets('GlobalAlertOverlay shows newly received alert banner and auto-dismisses after 5 seconds',
      (WidgetTester tester) async {
    final fakeRepo = FakeAlertRepository();
    final notifier = AlertNotifier(repository: fakeRepo, enablePolling: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlobalAlertOverlay(
            notifier: notifier,
            child: const Center(child: Text('App Content')),
          ),
        ),
      ),
    );

    expect(find.text('App Content'), findsOneWidget);
    expect(find.text('Critical Water Deficiency'), findsNothing);

    // Initial fetch with no alerts initializes the seen list
    await notifier.fetchAlerts();
    await tester.pump();

    // Now a new unread alert arrives
    final newAlert = SystemAlert(
      id: 'alert-1',
      title: 'Critical Water Deficiency',
      description: 'Water level below -15cm in Zone 1',
      severity: AlertSeverity.critical,
      category: AlertCategory.irrigation,
      source: const AlertSource(
        type: AlertSourceType.centralIrrigation,
        id: 'CTRL-01',
        displayName: 'Central Pump',
      ),
      timestamp: DateTime.now(),
      isRead: false,
      recommendedAction: 'Start reflooding',
    );

    fakeRepo.alerts = [newAlert];
    await notifier.fetchAlerts();
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 300)); // Finish animation

    // Verify banner is visible
    expect(find.text('Critical Water Deficiency'), findsOneWidget);
    expect(find.text('CRITICAL'), findsOneWidget);

    // Advance 4.5 seconds - banner should still be present
    await tester.pump(const Duration(milliseconds: 4500));
    expect(find.text('Critical Water Deficiency'), findsOneWidget);

    // Advance remaining 1 second (total > 5 seconds) - banner dismisses
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 300)); // Finish reverse animation

    expect(find.text('Critical Water Deficiency'), findsNothing);
  });
}
