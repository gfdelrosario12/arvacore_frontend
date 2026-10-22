import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/core/realtime/realtime_coordinator.dart';
import 'package:aquaflow_frontend/core/widgets/realtime_status_indicator.dart';

void main() {
  group('RealtimeStatusIndicator Widget Tests', () {
    testWidgets('renders LIVE badge when connected and healthy', (tester) async {
      const state = RealtimeState(
        connection: RealtimeConnectionState.connected,
        isPollingFallback: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RealtimeStatusIndicator(state: state),
          ),
        ),
      );

      expect(find.text('LIVE REST SYNC'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('renders Reconnecting... state when connecting', (tester) async {
      const state = RealtimeState(
        connection: RealtimeConnectionState.reconnecting,
        reconnectAttempts: 2,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RealtimeStatusIndicator(state: state),
          ),
        ),
      );

      expect(find.text('Reconnecting...'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('renders Degraded (REST Fallback) state when polling fallback active', (tester) async {
      const state = RealtimeState(
        connection: RealtimeConnectionState.degraded,
        isPollingFallback: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RealtimeStatusIndicator(state: state),
          ),
        ),
      );

      expect(find.text('Degraded (REST Fallback)'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });
  });
}

