import 'dart:convert';

enum TelemetryStreamStatus {
  processed,
  partiallyProcessed,
  rejected,
  failed,
  unknown;

  static TelemetryStreamStatus fromString(String? value) {
    if (value == null) return TelemetryStreamStatus.unknown;
    switch (value.trim().toUpperCase()) {
      case 'PROCESSED':
        return TelemetryStreamStatus.processed;
      case 'PARTIALLY_PROCESSED':
        return TelemetryStreamStatus.partiallyProcessed;
      case 'REJECTED':
        return TelemetryStreamStatus.rejected;
      case 'FAILED':
        return TelemetryStreamStatus.failed;
      default:
        return TelemetryStreamStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case TelemetryStreamStatus.processed:
        return 'Processed';
      case TelemetryStreamStatus.partiallyProcessed:
        return 'Partially Processed';
      case TelemetryStreamStatus.rejected:
        return 'Rejected';
      case TelemetryStreamStatus.failed:
        return 'Failed';
      case TelemetryStreamStatus.unknown:
        return 'Unknown';
    }
  }
}

class TelemetryStreamEvent {
  final String eventId;
  final String nodeId;
  final String eventType;
  final TelemetryStreamStatus status;
  final String rawStatus;
  final DateTime receivedAt;
  final DateTime? deviceTimestamp;
  final int? sequenceNumber;
  final int? fieldId;
  final int? zoneId;
  final String? zoneCode;
  final double? soilMoisturePercent;
  final double? waterLevelCm;
  final double? waterLevelDistanceCm;
  final String? soilSensorHealth;
  final String? ultrasonicSensorHealth;
  final String? telemetryStatus;
  final double? batteryLevel;
  final double? batteryVoltage;
  final int? rssiDbm;
  final double? snrDb;
  final int readingsCount;
  final String? statusMessage;
  final String? rawPayload;

  const TelemetryStreamEvent({
    required this.eventId,
    required this.nodeId,
    required this.eventType,
    required this.status,
    required this.rawStatus,
    required this.receivedAt,
    this.deviceTimestamp,
    this.sequenceNumber,
    this.fieldId,
    this.zoneId,
    this.zoneCode,
    this.soilMoisturePercent,
    this.waterLevelCm,
    this.waterLevelDistanceCm,
    this.soilSensorHealth,
    this.ultrasonicSensorHealth,
    this.telemetryStatus,
    this.batteryLevel,
    this.batteryVoltage,
    this.rssiDbm,
    this.snrDb,
    this.readingsCount = 0,
    this.statusMessage,
    this.rawPayload,
  });

  bool get isSoilSensorFailed =>
      soilSensorHealth != null &&
      soilSensorHealth!.trim().isNotEmpty &&
      soilSensorHealth!.trim().toUpperCase() != 'OK';

  bool get isUltrasonicSensorFailed =>
      ultrasonicSensorHealth != null &&
      ultrasonicSensorHealth!.trim().isNotEmpty &&
      ultrasonicSensorHealth!.trim().toUpperCase() != 'OK';

  bool get hasSensorFailure =>
      isSoilSensorFailed ||
      isUltrasonicSensorFailed ||
      (telemetryStatus != null &&
          telemetryStatus!.trim().isNotEmpty &&
          telemetryStatus!.trim().toUpperCase() != 'OK');

  factory TelemetryStreamEvent.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString() ?? 'UNKNOWN';
    final sensorHealthMap = json['sensorHealth'] is Map
        ? Map<String, dynamic>.from(json['sensorHealth'] as Map)
        : null;
    final soilHealth = (json['soilSensorHealth'] ?? sensorHealthMap?['soilMoisture'])?.toString();
    final ultrasonicHealth = (json['ultrasonicSensorHealth'] ?? sensorHealthMap?['ultrasonic'])?.toString();
    final rawDistance = _asDouble(json['waterLevelDistanceCm'] ?? json['water_level_distance']);
    final rawWaterLevel = _asDouble(json['waterLevelCm'] ?? json['water_level_cm']);
    final isUltrasonicFail = ultrasonicHealth != null &&
        ultrasonicHealth.trim().isNotEmpty &&
        ultrasonicHealth.trim().toUpperCase() != 'OK';
    final resolvedWaterLevel = (isUltrasonicFail || rawDistance == 0.0)
        ? 0.0
        : rawWaterLevel;

    return TelemetryStreamEvent(
      eventId: json['eventId']?.toString() ?? '',
      nodeId: json['nodeId']?.toString() ?? 'UNKNOWN',
      eventType: json['eventType']?.toString() ?? 'TELEMETRY_UPLINK',
      status: TelemetryStreamStatus.fromString(rawStatus),
      rawStatus: rawStatus,
      receivedAt: DateTime.tryParse(json['receivedAt']?.toString() ?? '') ??
          DateTime.tryParse(json['occurredAt']?.toString() ?? '') ??
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      deviceTimestamp: DateTime.tryParse(json['deviceTimestamp']?.toString() ?? ''),
      sequenceNumber: _asInt(json['sequenceNumber'] ?? json['sequence'] ?? json['seq'] ?? json['fCnt']),
      fieldId: _asInt(json['fieldId']),
      zoneId: _asInt(json['zoneId']),
      zoneCode: json['zoneCode']?.toString(),
      soilMoisturePercent: _asDouble(json['soilMoisturePercent'] ?? json['soil_moisture']),
      waterLevelCm: resolvedWaterLevel,
      waterLevelDistanceCm: rawDistance,
      soilSensorHealth: soilHealth,
      ultrasonicSensorHealth: ultrasonicHealth,
      telemetryStatus: json['telemetryStatus']?.toString(),
      batteryLevel: _asDouble(json['batteryLevel'] ?? json['battery_level']),
      batteryVoltage: _asDouble(json['batteryVoltage'] ?? json['battery_voltage']),
      rssiDbm: _asInt(json['rssiDbm'] ?? json['rssi']),
      snrDb: _asDouble(json['snrDb'] ?? json['snr']),
      readingsCount: _asInt(json['readingsCount']) ?? 0,
      statusMessage: json['statusMessage']?.toString(),
      rawPayload: json['rawPayload']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'nodeId': nodeId,
        'eventType': eventType,
        'status': rawStatus,
        'receivedAt': receivedAt.toIso8601String(),
        'deviceTimestamp': deviceTimestamp?.toIso8601String(),
        'sequenceNumber': sequenceNumber,
        'fieldId': fieldId,
        'zoneId': zoneId,
        'zoneCode': zoneCode,
        'soilMoisturePercent': soilMoisturePercent,
        'waterLevelCm': waterLevelCm,
        'waterLevelDistanceCm': waterLevelDistanceCm,
        if (soilSensorHealth != null) 'soilSensorHealth': soilSensorHealth,
        if (ultrasonicSensorHealth != null) 'ultrasonicSensorHealth': ultrasonicSensorHealth,
        if (telemetryStatus != null) 'telemetryStatus': telemetryStatus,
        'batteryLevel': batteryLevel,
        'batteryVoltage': batteryVoltage,
        'rssiDbm': rssiDbm,
        'snrDb': snrDb,
        'readingsCount': readingsCount,
        'statusMessage': statusMessage,
        'rawPayload': rawPayload,
      };

  String get formattedRawPayload {
    if (rawPayload == null || rawPayload!.trim().isEmpty) {
      return '{}';
    }
    try {
      final decoded = jsonDecode(rawPayload!);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return rawPayload!;
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

