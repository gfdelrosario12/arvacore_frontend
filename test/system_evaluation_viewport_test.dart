import 'package:aquaflow_frontend/core/api/api_client.dart';
import 'package:aquaflow_frontend/core/api/api_config.dart';
import 'package:aquaflow_frontend/core/api/api_factory.dart';
import 'package:aquaflow_frontend/features/analytics/presentation/system_evaluation_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fakes.dart';

void main() {
  setUp(() {
    final fakeClient = FakeHttpClient((request) async {
      if (request.url.path.contains('/evaluation/summary')) {
        return fakeJsonResponse(
          request,
          200,
          '''
{
  "waterLevel": {
    "capabilityStatus": "MEASURABLE",
    "statusDescription": "Ultrasonic sensor (JSN-SR04T) perforated-well depth measurement vs physical dipstick reference verified.",
    "latestReportedCm": 14.5,
    "latestReferenceCm": 14.0,
    "meanAbsoluteErrorCm": 0.5,
    "meanAccuracyPercentage": 96.4,
    "sampleCount": 12,
    "calculationFormula": "Accuracy (%) = max(0, 1 - MAE / 91.44) * 100",
    "recentComparisons": [
      {
        "id": "1",
        "indicatorType": "WATER_LEVEL",
        "nodeId": "NODE-01-VERY-LONG-IDENTIFIER",
        "reportedValue": 14.5,
        "referenceValue": 14.0,
        "absoluteError": 0.5,
        "accuracyPercentage": 96.4,
        "timestamp": "2026-10-20T10:00:00Z",
        "instrumentDetails": "Manual Dipstick Standard Model DS-500"
      }
    ]
  },
  "soilMoisture": {
    "capabilityStatus": "PARTIALLY_MEASURABLE",
    "statusDescription": "Capacitive analog scale requires routine reference calibration against gravimetric core samples across field soil variations.",
    "latestReportedPercentage": 68.2,
    "latestReferencePercentage": 70.0,
    "meanAbsoluteError": 1.8,
    "meanAccuracyPercentage": 98.2,
    "sampleCount": 8,
    "calculationFormula": "Accuracy (%) = max(0, 1 - MAE / 100) * 100",
    "calibrationNotes": "Calibrated against volumetric theta probe standards across Sandy Loam test plot with standard oven drying calibration protocols.",
    "recentComparisons": []
  },
  "activation": {
    "capabilityStatus": "MEASURABLE",
    "statusDescription": "Command state machine dispatch to edge node radio acknowledgment verified across multiple irrigation events.",
    "totalAttempts": 15,
    "confirmedSuccesses": 15,
    "failedAttempts": 0,
    "successRatePercentage": 100.0,
    "confirmationSource": "Edge Node Downlink ACK & Central Pump Relay Status Feedback Mechanism",
    "calculationFormula": "Activation Accuracy (%) = (Confirmed / Total) * 100"
  },
  "deactivation": {
    "capabilityStatus": "MEASURABLE",
    "statusDescription": "Stop commands and emergency shutoff acknowledgment confirmation verified under real-time network conditions.",
    "totalAttempts": 14,
    "confirmedSuccesses": 14,
    "failedAttempts": 0,
    "successRatePercentage": 100.0,
    "confirmationSource": "Edge Node ACK & Emergency Stop Feedback Mechanism",
    "calculationFormula": "Deactivation Accuracy (%) = (Confirmed / Total) * 100"
  },
  "responseTime": {
    "capabilityStatus": "MEASURABLE",
    "statusDescription": "Latency from backend command dispatch to edge radio ACK recorded via gateway uplink.",
    "measuredSampleCount": 29,
    "avgCommandToAckMs": 420.0,
    "minCommandToAckMs": 280.0,
    "maxCommandToAckMs": 850.0,
    "p95CommandToAckMs": 620.0,
    "timeoutCount": 0,
    "clockSyncNotes": "Trigger Timestamp to Edge ACK Reception Delta via LoRaWAN Gateway",
    "calculationFormula": "Response Time = Response Timestamp - Trigger Timestamp"
  },
  "waterConsumption": {
    "capabilityStatus": "NOT_MEASURABLE",
    "statusDescription": "Missing flow sensor hardware; volumetric flow cannot be asserted without an in-line meter.",
    "measurementType": "UNAVAILABLE",
    "currentFlowRateLpm": 0.0,
    "cumulativeConsumptionLiters": 0.0,
    "hardwareRequirement": "In-line pulse flow meter (e.g. YF-B5 Hall-effect) or verified pump flow-rate calibration model",
    "missingComponentExplanation": "Current node hardware carries only soil moisture and ultrasonic sensors. Physical volumetric consumption cannot be claimed without a verified flow measurement source."
  }
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

    testWidgets('SystemEvaluationDashboardScreen renders on $name (${size.width.toInt()}x${size.height.toInt()}) without overflow', (tester) async {
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
          home: SystemEvaluationDashboardScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(SingleChildScrollView), findsWidgets);
      final scrollFinder = find.byType(SingleChildScrollView).first;

      // Scroll progressively from top to bottom
      await tester.drag(scrollFinder, const Offset(0, -350));
      await tester.pump();
      await tester.drag(scrollFinder, const Offset(0, -500));
      await tester.pump();
      await tester.drag(scrollFinder, const Offset(0, -600));
      await tester.pump();
      await tester.drag(scrollFinder, const Offset(0, -600));
      await tester.pump();

      final exception = tester.takeException();
      expect(exception, isNull);

      // Verify that Missing Hardware and Calibration Requirements text widgets are rendered
      expect(find.textContaining('Missing Hardware & Calibration Requirements'), findsWidgets);
      expect(find.textContaining('Hardware Requirement:'), findsWidgets);
      expect(find.textContaining('Calibration Requirement:'), findsWidgets);
    });
  }
}

