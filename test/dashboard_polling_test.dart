import 'package:aquaflow_frontend/core/realtime/dashboard_polling.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardPollingService', () {
    testWidgets('polls every 5 seconds while running', (tester) async {
      int calls = 0;
      final service = DashboardPollingService(
        fetchCallback: () async => calls++,
        pollInterval: const Duration(seconds: 5),
      );

      service.start();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);

      await tester.pump(const Duration(seconds: 6));
      expect(calls, 2);

      await tester.pump(const Duration(seconds: 6));
      expect(calls, 3);

      service.dispose();
    });

    testWidgets('never runs two requests at the same time', (tester) async {
      int started = 0;
      int completed = 0;
      final service = DashboardPollingService(
        fetchCallback: () async {
          started++;
          await Future<void>.delayed(const Duration(seconds: 30));
          completed++;
        },
        pollInterval: const Duration(seconds: 5),
      );

      service.start();
      await tester.pump(const Duration(milliseconds: 400));
      expect(started, 1);

      // A manual refresh while the request is still running must join the running
      // request instead of starting a second one.
      final Future<void> forced = service.forcePoll();
      await tester.pump(const Duration(milliseconds: 200));
      expect(started, 1);

      await tester.pump(const Duration(seconds: 30));
      await forced;
      expect(started, 1);
      expect(completed, 1);

      service.dispose();
    });

    testWidgets('applies bounded backoff and resumes the normal interval after recovery',
        (tester) async {
      int calls = 0;
      bool failing = true;
      final service = DashboardPollingService(
        fetchCallback: () async {
          calls++;
          if (failing) throw Exception('backend unreachable');
        },
        pollInterval: const Duration(seconds: 5),
        backoffBaseDelay: const Duration(seconds: 2),
        backoffMaxDelay: const Duration(seconds: 30),
      );

      service.start();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      expect(service.isDegraded, isTrue);
      expect(service.consecutiveFailures, 1);

      // First backoff step is 2 seconds, shorter than the normal 5 second interval.
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 2);
      expect(service.consecutiveFailures, 2);

      // Second backoff step doubles to 4 seconds.
      failing = false;
      await tester.pump(const Duration(seconds: 4));
      expect(calls, 3);
      expect(service.isDegraded, isFalse);
      expect(service.consecutiveFailures, 0);

      // The normal 5 second interval is restored once polling succeeds again.
      await tester.pump(const Duration(seconds: 6));
      expect(calls, 4);

      service.dispose();
    });

    testWidgets('stops polling when the dashboard is closed', (tester) async {
      int calls = 0;
      final service = DashboardPollingService(
        fetchCallback: () async => calls++,
        pollInterval: const Duration(seconds: 5),
      );

      service.start();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);

      service.stop();
      await tester.pump(const Duration(seconds: 60));
      expect(calls, 1);
      expect(service.isPolling, isFalse);

      service.dispose();
    });

    testWidgets('a manual refresh runs immediately even between two intervals',
        (tester) async {
      int calls = 0;
      final service = DashboardPollingService(
        fetchCallback: () async => calls++,
        pollInterval: const Duration(seconds: 5),
      );

      service.start();
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);

      await service.forcePoll();
      expect(calls, 2);

      service.dispose();
    });
  });
}
