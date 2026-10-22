import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

abstract class RealtimeTransport {
  Stream<String> get messages;
  Stream<Object> get errors;
  bool get isConnected;

  Future<void> connect(Uri endpoint, {required String accessToken});
  Future<void> subscribe(List<String> topics);
  Future<void> close();
}

/// Pure database-backed REST polling transport that replaces WebSockets.
/// Deduplicates in-flight HTTP requests, tracks incremental cursors (`after` / `sinceId`),
/// and applies jittered polling intervals.
class RestPollingRealtimeTransport implements RealtimeTransport {
  final http.Client _httpClient;
  final Duration pollInterval;
  final _messages = StreamController<String>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final Random _random = Random();

  Timer? _pollTimer;
  Uri? _endpoint;
  String? _accessToken;
  bool _connected = false;
  bool _pollInFlight = false;
  DateTime? _lastTelemetryReceivedAt;
  int _sequenceCounter = 1;

  RestPollingRealtimeTransport({
    http.Client? httpClient,
    this.pollInterval = const Duration(seconds: 5),
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(Uri endpoint, {required String accessToken}) async {
    await close();
    if (accessToken.isEmpty) {
      throw StateError('Access token is required.');
    }
    _endpoint = endpoint;
    _accessToken = accessToken;
    _connected = true;
    _scheduleNextPoll(initial: true);
  }

  @override
  Future<void> subscribe(List<String> topics) async {
    if (!_connected) {
      throw StateError('Realtime REST polling transport is not connected.');
    }
  }

  void _scheduleNextPoll({bool initial = false}) {
    _pollTimer?.cancel();
    if (!_connected) return;
    final jitterMs = _random.nextInt(400);
    final delay = initial
        ? const Duration(milliseconds: 50)
        : pollInterval + Duration(milliseconds: jitterMs);
    _pollTimer = Timer(delay, () async {
      if (!_connected) return;
      await _executePollCycle();
      if (_connected) {
        _scheduleNextPoll();
      }
    });
  }

  Future<void> _executePollCycle() async {
    if (_pollInFlight || !_connected || _endpoint == null || _accessToken == null) {
      return;
    }
    _pollInFlight = true;
    try {
      final baseUri = _resolveBaseApiUri(_endpoint!);
      final queryParams = <String, String>{'limit': '20'};
      if (_lastTelemetryReceivedAt != null) {
        queryParams['after'] = _lastTelemetryReceivedAt!.toIso8601String();
      }
      final streamUri = baseUri.replace(
        path: '/api/v1/telemetry/stream/recent',
        queryParameters: queryParams,
      );

      final response = await _httpClient.get(
        streamUri,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          for (final item in decoded.reversed) {
            if (item is Map<String, dynamic>) {
              final receivedAtStr = item['receivedAt']?.toString();
              if (receivedAtStr != null) {
                final parsed = DateTime.tryParse(receivedAtStr);
                if (parsed != null &&
                    (_lastTelemetryReceivedAt == null ||
                        parsed.isAfter(_lastTelemetryReceivedAt!))) {
                  _lastTelemetryReceivedAt = parsed;
                }
              }
              final nodeId = item['nodeId']?.toString() ?? 'ARVANODE-001';
              final eventId = item['eventId']?.toString() ??
                  'rest-${DateTime.now().microsecondsSinceEpoch}-${_sequenceCounter++}';
              final envelope = {
                'version': 1,
                'eventId': eventId,
                'eventType': 'telemetry_stream',
                'occurredAt': receivedAtStr ?? DateTime.now().toUtc().toIso8601String(),
                'sequence': _sequenceCounter++,
                'scope': 'NODE-$nodeId',
                'payload': item,
              };
              _messages.add(jsonEncode(envelope));
            }
          }
        }
      }
    } catch (error) {
      if (_connected) {
        _errors.add(error);
      }
    } finally {
      _pollInFlight = false;
    }
  }

  Uri _resolveBaseApiUri(Uri endpoint) {
    final scheme = endpoint.scheme == 'wss'
        ? 'https'
        : (endpoint.scheme == 'ws' ? 'http' : endpoint.scheme);
    return Uri(
      scheme: scheme.isEmpty ? 'https' : scheme,
      host: endpoint.host.isEmpty ? 'api-aquaflow.gladwindr.me' : endpoint.host,
      port: endpoint.hasPort ? endpoint.port : null,
    );
  }

  @override
  Future<void> close() async {
    _connected = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> dispose() async {
    await close();
    await _messages.close();
    await _errors.close();
  }
}

class FakeRealtimeTransport implements RealtimeTransport {
  final _messages = StreamController<String>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final List<List<String>> subscriptions = [];
  bool _connected = false;
  int connectCount = 0;

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(Uri endpoint, {required String accessToken}) async {
    if (accessToken.isEmpty) throw StateError('Access token is required.');
    connectCount++;
    _connected = true;
  }

  @override
  Future<void> subscribe(List<String> topics) async {
    if (!_connected) throw StateError('Transport is disconnected.');
    subscriptions.add(List.unmodifiable(topics));
  }

  void emit(String message) {
    if (_connected) _messages.add(message);
  }

  void fail(Object error) {
    _connected = false;
    _errors.add(error);
  }

  @override
  Future<void> close() async {
    _connected = false;
  }

  Future<void> dispose() async {
    await close();
    await _messages.close();
    await _errors.close();
  }
}
