enum RealtimeEventType {
  measurement,
  sensorStatus,
  gatewayStatus,
  irrigationState,
  irrigationEvent,
  controllerEvent,
  alert,
  nodeStatus,
  transmissionIntervalUpdated,
  nodeDiscovered,
  nodeLifecycleUpdated,
  nodeReplaced,
  auditEvent,
  lorawanTelemetry,
  lorawanDeviceStatus,
  manualControlExecuted,
  awdAnalysisCompleted,
  telemetryStream,
}

class RealtimeValidationException implements Exception {
  final String message;

  const RealtimeValidationException(this.message);

  @override
  String toString() => 'RealtimeValidationException: $message';
}

class RealtimeEvent {
  static const supportedVersion = 1;

  final int version;
  final String eventId;
  final RealtimeEventType type;
  final DateTime occurredAt;
  final int sequence;
  final String scope;
  final Map<String, dynamic> payload;

  const RealtimeEvent({
    required this.version,
    required this.eventId,
    required this.type,
    required this.occurredAt,
    required this.sequence,
    required this.scope,
    required this.payload,
  });

  String get aggregateKey => scope;

  bool get isMonitoringScope {
    if (scope == 'SYSTEM' || scope.isEmpty) return true;
    if (scope.startsWith('NODE-') || scope.startsWith('ESP32-')) return true;
    // Dynamic node/monitoring point aggregate keys (alphanumeric identifiers).
    return RegExp(r'^[A-Za-z][A-Za-z0-9_\-\.:]{2,}$').hasMatch(scope);
  }

  bool get isEntireField => scope == 'ENTIRE FIELD';

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    final version = _optionalInt(json, 'version') ?? supportedVersion;
    if (version != supportedVersion) {
      throw RealtimeValidationException('Unsupported event version: $version.');
    }
    final eventId = _requiredString(json, 'eventId');
    final eventType = _eventType(_requiredString(json, 'eventType'));
    final occurredAt = DateTime.tryParse(
          json['occurredAt']?.toString() ??
              json['timestamp']?.toString() ??
              json['receivedAt']?.toString() ??
              '',
        ) ??
        DateTime.now();
    final sequence = _optionalInt(json, 'sequence') ??
        _optionalInt(json, 'sequenceNumber') ??
        0;
    final scope = json['scope']?.toString() ??
        json['aggregateId']?.toString() ??
        json['nodeId']?.toString() ??
        'SYSTEM';
    final rawPayload = json['payload'];
    if (rawPayload is! Map) {
      throw const RealtimeValidationException('Event payload must be an object.');
    }
    final payload = Map<String, dynamic>.from(rawPayload);
    final event = RealtimeEvent(
      version: version,
      eventId: eventId,
      type: eventType,
      occurredAt: occurredAt,
      sequence: sequence,
      scope: scope,
      payload: payload,
    );
    event._validateScope();
    return event;
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'eventId': eventId,
        'eventType': _eventTypeToString(type),
        'occurredAt': occurredAt.toIso8601String(),
        'sequence': sequence,
        'scope': scope,
        'payload': payload,
      };

  void _validateScope() {
    final irrigationEvent = type == RealtimeEventType.irrigationState ||
        type == RealtimeEventType.irrigationEvent ||
        type == RealtimeEventType.controllerEvent ||
        type == RealtimeEventType.manualControlExecuted;
    if (irrigationEvent && !isEntireField) {
      throw RealtimeValidationException(
        '${type.name} events require ENTIRE FIELD scope.',
      );
    }
    if (type == RealtimeEventType.measurement ||
        type == RealtimeEventType.sensorStatus ||
        type == RealtimeEventType.nodeStatus ||
        type == RealtimeEventType.transmissionIntervalUpdated ||
        type == RealtimeEventType.nodeLifecycleUpdated ||
        type == RealtimeEventType.nodeReplaced ||
        type == RealtimeEventType.lorawanTelemetry ||
        type == RealtimeEventType.lorawanDeviceStatus ||
        type == RealtimeEventType.telemetryStream) {
      if (!isMonitoringScope) {
        throw RealtimeValidationException(
          '${type.name} events require valid monitoring or node scope.',
        );
      }
    }
  }

  Map<String, Object?> toSafeLogMap() => {
        'version': version,
        'eventId': eventId,
        'eventType': type.name,
        'occurredAt': occurredAt.toIso8601String(),
        'sequence': sequence,
        'scope': scope,
        'payloadKeys': payload.keys.toList(growable: false),
      };

  static String _eventTypeToString(RealtimeEventType type) {
    switch (type) {
      case RealtimeEventType.measurement:
        return 'measurement';
      case RealtimeEventType.sensorStatus:
        return 'sensor_status';
      case RealtimeEventType.gatewayStatus:
        return 'gateway_status';
      case RealtimeEventType.irrigationState:
        return 'irrigation_state';
      case RealtimeEventType.irrigationEvent:
        return 'irrigation_event';
      case RealtimeEventType.controllerEvent:
        return 'controller_event';
      case RealtimeEventType.alert:
        return 'alert';
      case RealtimeEventType.nodeStatus:
        return 'node_status';
      case RealtimeEventType.transmissionIntervalUpdated:
        return 'transmission_interval_updated';
      case RealtimeEventType.nodeDiscovered:
        return 'node_discovered';
      case RealtimeEventType.nodeLifecycleUpdated:
        return 'node_lifecycle_updated';
      case RealtimeEventType.nodeReplaced:
        return 'node_replaced';
      case RealtimeEventType.auditEvent:
        return 'audit_event';
      case RealtimeEventType.lorawanTelemetry:
        return 'lorawan_telemetry';
      case RealtimeEventType.lorawanDeviceStatus:
        return 'lorawan_device_status';
      case RealtimeEventType.manualControlExecuted:
        return 'manual_control_executed';
      case RealtimeEventType.awdAnalysisCompleted:
        return 'awd_analysis_completed';
      case RealtimeEventType.telemetryStream:
        return 'telemetry_stream';
    }
  }

  static RealtimeEventType _eventType(String value) {
    switch (value) {
      case 'measurement':
      case 'water_measurement':
        return RealtimeEventType.measurement;
      case 'telemetry_stream':
      case 'telemetryStream':
      case 'telemetry_received':
      case 'TELEMETRY_RECEIVED':
        return RealtimeEventType.telemetryStream;
      case 'sensor_status':
        return RealtimeEventType.sensorStatus;
      case 'gateway_status':
        return RealtimeEventType.gatewayStatus;
      case 'irrigation_state':
        return RealtimeEventType.irrigationState;
      case 'irrigation_event':
        return RealtimeEventType.irrigationEvent;
      case 'controller_event':
        return RealtimeEventType.controllerEvent;
      case 'alert':
        return RealtimeEventType.alert;
      case 'node_status':
      case 'nodeStatus':
      case 'NODE_STATUS_CHANGED':
        return RealtimeEventType.nodeStatus;
      case 'transmission_interval_updated':
      case 'transmissionIntervalUpdated':
        return RealtimeEventType.transmissionIntervalUpdated;
      case 'node_discovered':
      case 'nodeDiscovered':
        return RealtimeEventType.nodeDiscovered;
      case 'node_lifecycle_updated':
      case 'nodeLifecycleUpdated':
        return RealtimeEventType.nodeLifecycleUpdated;
      case 'node_replaced':
      case 'nodeReplaced':
        return RealtimeEventType.nodeReplaced;
      case 'audit_event':
      case 'auditEvent':
      case 'audit':
        return RealtimeEventType.auditEvent;
      case 'lorawan_telemetry':
      case 'lorawanTelemetry':
        return RealtimeEventType.lorawanTelemetry;
      case 'lorawan_device_status':
      case 'lorawanDeviceStatus':
        return RealtimeEventType.lorawanDeviceStatus;
      case 'manual_control_executed':
      case 'manualControlExecuted':
        return RealtimeEventType.manualControlExecuted;
      case 'awd_analysis_completed':
      case 'awdAnalysisCompleted':
        return RealtimeEventType.awdAnalysisCompleted;
      default:
        throw RealtimeValidationException('Unsupported event type: $value.');
    }
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw RealtimeValidationException('Event $key is required.');
    }
    return value;
  }

  static int? _optionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }
}
