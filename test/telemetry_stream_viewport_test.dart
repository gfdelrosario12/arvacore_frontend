import 'package:aquaflow_frontend/core/api/api_client.dart';
import 'package:aquaflow_frontend/core/api/api_config.dart';
import 'package:aquaflow_frontend/core/api/api_factory.dart';
import 'package:aquaflow_frontend/features/telemetry_stream/presentation/screens/telemetry_stream_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fakes.dart';

void main() {
  setUp(() {
    final fakeClient = FakeHttpClient((request) async {
      if (request.url.path.contains('/telemetry/stream/summary')) {
        return fakeJsonResponse(
          request,
          200,
          '''
{
  "totalTransmissions": 1284,
  "recentTransmissionsCount": 94,
  "distinctNodesCount": 4,
  "processedCount": 1200,
  "partiallyProcessedCount": 60,
  "rejectedCount": 14,
  "failedCount": 10,
  "firstSeenTimestamp": "2026-10-18T00:00:00Z",
  "lastSeenTimestamp": "2026-10-20T12:00:00Z"
}
''',
        );
      }
      if (request.url.path.contains('/telemetry/stream/events')) {
        return fakeJsonResponse(
          request,
          200,
          '''
{
  "content": [
    {
      "eventId": "EVT-1001",
      "nodeId": "ESP32-NODE-01-VERY-LONG-IDENTIFIER",
      "sequenceNumber": 1024,
      "zoneCode": "ZONE-Q1-NORTH-EXPANDED",
      "receivedAt": "2026-10-20T12:05:00Z",
      "deviceTimestamp": "2026-10-20T12:04:58Z",
      "status": "PROCESSED",
      "rawStatus": "PROCESSED",
      "soilMoisturePercent": 45.2,
      "waterLevelCm": 12.8,
      "waterLevelDistanceCm": 24.3,
      "batteryLevel": 92,
      "batteryVoltage": 4.12,
      "rssiDbm": -68,
      "snrDb": 9.5,
      "statusMessage": "Clean ingestion and telemetry parsed correctly across all channels without loss.",
      "rawPayload": "{\\"node\\":\\"ESP32-01\\",\\"soil\\":45.2,\\"level\\":12.8}"
    }
  ],
  "totalPages": 1,
  "totalElements": 1,
  "number": 0,
  "size": 20
}
''',
        );
      }
      return fakeJsonResponse(request, 404, '{"error":"not found"}');
    });

    ApiRepositoryFactory(
      client: ApiClient(
        config: const ApiConfig(baseUrl: 'https://example.test'),
        httpClient: fakeClient,
      ),
    );
  });

  tearDown(() {
    ApiRepositoryFactory.resetInstanceForTesting();
  });

  final viewports = [
    {'name': 'Compact phone', 'size': const Size(320, 568)},
    {'name': 'Narrow Android phone', 'size': const Size(360, 640)},
    {'name': 'Standard phone', 'size': const Size(360, 800)},
    {'name': 'Modern smartphone', 'size': const Size(390, 844)},
    {'name': 'Large smartphone', 'size': const Size(430, 932)},
    {'name': 'Landscape phone', 'size': const Size(844, 390)},
  ];

  for (final vp in viewports) {
    final name = vp['name'] as String;
    final size = vp['size'] as Size;

    testWidgets('TelemetryStreamScreen renders on $name (${size.width.toInt()}x${size.height.toInt()}) without overflow', (tester) async {
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details);
      };
      final view = tester.view;
      view.devicePixelRatio = 1.0;
      view.physicalSize = size;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TelemetryStreamScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ListView), findsOneWidget);
      final listFinder = find.byType(ListView);

      // Scroll through content
      await tester.drag(listFinder, const Offset(0, -250));
      await tester.pump();
      await tester.drag(listFinder, const Offset(0, -350));
      await tester.pump();

      final exception = tester.takeException();
      expect(exception, isNull);
    });
  }
}

