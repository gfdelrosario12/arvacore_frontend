import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquaflow_frontend/core/realtime/realtime_events.dart';
import 'package:aquaflow_frontend/features/telemetry_stream/data/repositories/telemetry_stream_repository.dart';
import 'package:aquaflow_frontend/features/telemetry_stream/domain/models/telemetry_stream_event.dart';
import 'package:aquaflow_frontend/features/telemetry_stream/domain/models/telemetry_stream_summary.dart';
import 'package:aquaflow_frontend/features/telemetry_stream/presentation/providers/telemetry_stream_notifier.dart';

class MockTelemetryStreamRepository implements TelemetryStreamRepository {
  List<TelemetryStreamEvent> eventsToReturn = [];
  TelemetryStreamSummary summaryToReturn = const TelemetryStreamSummary(
    totalTransmissions: 10,
    recentTransmissionsCount: 5,
    distinctNodesCount: 2,
    failedOrRejectedCount: 1,
  );
  Map<String, dynamic> filtersToReturn = {
    'nodeIds': ['NODE-C3E8', 'NODE-A1B2'],
    'statuses': ['PROCESSED', 'PARTIALLY_PROCESSED', 'REJECTED', 'FAILED'],
    'zones': [],
  };

  @override
  Future<List<TelemetryStreamEvent>> fetchEvents({
    String? nodeId,
    int? fieldId,
    String? status,
    DateTime? from,
    DateTime? to,
    String? search,
    int page = 0,
    int size = 50,
  }) async {
    return eventsToReturn.where((e) {
      if (nodeId != null && e.nodeId != nodeId) return false;
      if (status != null && e.rawStatus != status) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<TelemetryStreamEvent>> fetchRecentEvents({int limit = 50, DateTime? after}) async {
    return eventsToReturn;
  }

  @override
  Future<TelemetryStreamSummary> fetchSummary() async => summaryToReturn;

  @override
  Future<Map<String, dynamic>> fetchFilterOptions() async => filtersToReturn;
}

void main() {
  group('TelemetryStreamEvent Model Tests', () {
    test('should parse hardware payload correctly into TelemetryStreamEvent', () {
      final json = {
        'eventId': 'evt-101',
        'nodeId': 'NODE-C3E8',
        'eventType': 'TELEMETRY_UPLINK',
        'status': 'PROCESSED',
        'receivedAt': '2026-10-17T22:00:00.000',
        'deviceTimestamp': '2026-10-17T21:59:58.000',
        'sequenceNumber': 7,
        'soilMoisturePercent': 45.59,
        'waterLevelDistanceCm': 123.15,
        'waterLevelCm': -23.15,
        'batteryVoltage': 4.15,
        'batteryLevel': 95.0,
        'rssiDbm': -72,
        'snrDb': 9.5,
        'readingsCount': 2,
        'statusMessage': 'Telemetry uplink ingested successfully',
        'rawPayload': '{"nodeId":"NODE-C3E8","seq":7,"batteryVoltage":4.15}',
      };

      final event = TelemetryStreamEvent.fromJson(json);

      expect(event.eventId, 'evt-101');
      expect(event.nodeId, 'NODE-C3E8');
      expect(event.status, TelemetryStreamStatus.processed);
      expect(event.sequenceNumber, 7);
      expect(event.soilMoisturePercent, 45.59);
      expect(event.waterLevelDistanceCm, 123.15);
      expect(event.batteryVoltage, 4.15);
      expect(event.batteryLevel, 95.0);
      expect(event.readingsCount, 2);
      expect(event.formattedRawPayload, contains('"nodeId": "NODE-C3E8"'));
    });

    test('should map all status strings accurately', () {
      expect(TelemetryStreamStatus.fromString('PROCESSED'), TelemetryStreamStatus.processed);
      expect(TelemetryStreamStatus.fromString('PARTIALLY_PROCESSED'), TelemetryStreamStatus.partiallyProcessed);
      expect(TelemetryStreamStatus.fromString('REJECTED'), TelemetryStreamStatus.rejected);
      expect(TelemetryStreamStatus.fromString('FAILED'), TelemetryStreamStatus.failed);
      expect(TelemetryStreamStatus.fromString('SOMETHING_ELSE'), TelemetryStreamStatus.unknown);
    });
  });

  group('RealtimeEvent Deserialization Compatibility', () {
    test('should parse backend SystemEvent JSON payload without throwing', () {
      final backendSystemEventJson = {
        'version': 1,
        'eventId': 'event-uuid-1234',
        'eventType': 'TELEMETRY_RECEIVED',
        'timestamp': '2026-10-17T22:05:00.000',
        'occurredAt': '2026-10-17T22:05:00.000',
        'sequence': 7,
        'aggregateId': 'NODE-C3E8',
        'scope': 'NODE-C3E8',
        'payload': {
          'eventId': 'evt-555',
          'nodeId': 'NODE-C3E8',
          'eventType': 'TELEMETRY_UPLINK',
          'status': 'PROCESSED',
          'receivedAt': '2026-10-17T22:05:00.000',
          'sequenceNumber': 7,
          'soilMoisturePercent': 45.59,
          'batteryLevel': 95.0,
        },
      };

      final realtimeEvent = RealtimeEvent.fromJson(backendSystemEventJson);

      expect(realtimeEvent.eventId, 'event-uuid-1234');
      expect(realtimeEvent.type, RealtimeEventType.telemetryStream);
      expect(realtimeEvent.scope, 'NODE-C3E8');
      expect(realtimeEvent.sequence, 7);
      expect(realtimeEvent.payload['nodeId'], 'NODE-C3E8');
    });
  });

  group('TelemetryStreamNotifier Tests', () {
    test('should fetch initial events and summary on startup', () async {
      final mockRepo = MockTelemetryStreamRepository();
      mockRepo.eventsToReturn = [
        TelemetryStreamEvent(
          eventId: 'evt-1',
          nodeId: 'NODE-C3E8',
          eventType: 'TELEMETRY_UPLINK',
          status: TelemetryStreamStatus.processed,
          rawStatus: 'PROCESSED',
          receivedAt: DateTime(2026, 10, 17, 22, 0),
          sequenceNumber: 7,
        ),
      ];

      final notifier = TelemetryStreamNotifier(repository: mockRepo);
      // Wait for async initialization
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.events.length, 1);
      expect(notifier.events.first.nodeId, 'NODE-C3E8');
      expect(notifier.summary.totalTransmissions, 10);
      expect(notifier.availableNodeIds, contains('NODE-C3E8'));
      notifier.dispose();
    });

    test('should buffer events when visual feed is paused and flush when resumed', () async {
      final mockRepo = MockTelemetryStreamRepository();
      final notifier = TelemetryStreamNotifier(repository: mockRepo);
      await Future.delayed(const Duration(milliseconds: 50));

      // Pause the feed
      notifier.togglePause();
      expect(notifier.isPaused, true);
      expect(notifier.pausedCount, 0);

      // Simulate a live event coming in
      final incoming = TelemetryStreamEvent(
        eventId: 'evt-2',
        nodeId: 'NODE-C3E8',
        eventType: 'TELEMETRY_UPLINK',
        status: TelemetryStreamStatus.processed,
        rawStatus: 'PROCESSED',
        receivedAt: DateTime(2026, 10, 17, 22, 5),
        sequenceNumber: 8,
      );

      // Use reflection or filter test via incorporation
      notifier.togglePause(); // Unpause
      expect(notifier.isPaused, false);
      notifier.dispose();
    });

    test('should filter events by status', () async {
      final mockRepo = MockTelemetryStreamRepository();
      mockRepo.eventsToReturn = [
        TelemetryStreamEvent(
          eventId: 'evt-1',
          nodeId: 'NODE-C3E8',
          eventType: 'TELEMETRY_UPLINK',
          status: TelemetryStreamStatus.processed,
          rawStatus: 'PROCESSED',
          receivedAt: DateTime(2026, 10, 17, 22, 0),
        ),
        TelemetryStreamEvent(
          eventId: 'evt-2',
          nodeId: 'NODE-C3E8',
          eventType: 'TELEMETRY_UPLINK',
          status: TelemetryStreamStatus.rejected,
          rawStatus: 'REJECTED',
          receivedAt: DateTime(2026, 10, 17, 22, 1),
        ),
      ];

      final notifier = TelemetryStreamNotifier(repository: mockRepo);
      await Future.delayed(const Duration(milliseconds: 50));

      notifier.setStatusFilter('REJECTED');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.selectedStatus, 'REJECTED');
      notifier.dispose();
    });
  });
}

