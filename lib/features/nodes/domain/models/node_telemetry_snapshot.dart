/// Latest telemetry known for a single edge node.
///
/// Produced by the batched backend snapshot endpoint
/// (`GET /api/v1/nodes/telemetry/latest`) and consumed by the Home Dashboard poll.
///
/// Every measurement is nullable on purpose: `null` means "this node never reported
/// this sensor", while a numeric `0` means "the node reported a zero value". The
/// dashboard renders those two states differently.
class NodeTelemetrySnapshot {
  /// Canonical node identifier, e.g. `ARVANODE-001`.
  final String nodeId;

  /// Numeric primary key of the node on the backend.
  final String? edgeNodeId;

  final String? monitoringZoneId;
  final String? monitoringZoneCode;
  final String? monitoringZoneName;

  final double? soilMoisturePercent;
  final double? waterLevelDistanceCm;
  final double? waterLevelCm;
  final double? batteryVoltage;
  final int? batteryPercent;

  final String? soilSensorHealth;
  final String? ultrasonicSensorHealth;
  final String? telemetryStatus;

  /// Device timestamp of the newest reading.
  final DateTime? lastTelemetryAt;

  /// Server-side arrival timestamp of the newest reading.
  final DateTime? lastReceivedAt;

  /// True when the backend considers the node reachable.
  final bool isOnline;

  /// True when at least one reading backs this snapshot.
  final bool hasTelemetry;

  const NodeTelemetrySnapshot({
    required this.nodeId,
    this.edgeNodeId,
    this.monitoringZoneId,
    this.monitoringZoneCode,
    this.monitoringZoneName,
    this.soilMoisturePercent,
    this.waterLevelDistanceCm,
    this.waterLevelCm,
    this.batteryVoltage,
    this.batteryPercent,
    this.soilSensorHealth,
    this.ultrasonicSensorHealth,
    this.telemetryStatus,
    this.lastTelemetryAt,
    this.lastReceivedAt,
    this.isOnline = false,
    this.hasTelemetry = false,
  });

  /// True when the node reported a soil sensor failure.
  bool get isSoilSensorFailed {
    final String? health = soilSensorHealth?.trim();
    return health != null && health.isNotEmpty && health.toUpperCase() != 'OK';
  }

  /// True when the node reported an ultrasonic sensor failure.
  bool get isUltrasonicSensorFailed {
    final String? health = ultrasonicSensorHealth?.trim();
    return health != null && health.isNotEmpty && health.toUpperCase() != 'OK';
  }

  /// True when any sensor or the telemetry link reported a problem.
  bool get hasSensorFailure {
    final String? status = telemetryStatus?.trim();
    return isSoilSensorFailed ||
        isUltrasonicSensorFailed ||
        (status != null && status.isNotEmpty && status.toUpperCase() != 'OK');
  }
}
