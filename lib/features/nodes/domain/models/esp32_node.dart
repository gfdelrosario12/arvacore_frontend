import 'lorawan_identity.dart';
import 'node_enums.dart';
import 'node_telemetry_snapshot.dart';
import 'sensor.dart';
import 'spatial_coordinates.dart';
import 'transmission_config.dart';

/// Represents an operational or discovered physical ESP32 IoT node in AquaSense.
/// Represents an operational, discovered, or lifecycle-managed physical ESP32 IoT node in AquaSense.
class Esp32Node {
  final String id;
  final String macAddress;
  final String displayName;
  final String? assignedFieldId;
  final String? assignedFieldName;
  final String? assignedZoneId;
  final String? assignedZoneCode;
  final String? assignedZoneName;
  final String? assignedPointId;
  final SpatialCoordinates? coordinates;
  final TransmissionConfig transmissionConfig;
  final bool isOnline;
  final NodeLifecycleStatus lifecycleState;
  final String? pairingStatus;
  final String? assignmentStatus;
  final String? connectivityStatus;
  final String? soilSensorHealth;
  final String? ultrasonicSensorHealth;
  final String? telemetryStatus;
  final String hardwareRevision;
  final String firmwareVersion;
  final int? batteryPercent;
  final double? batteryVoltage;
  final int? rssiDbm;
  final double? snrDb;
  final DateTime lastSeen;
  final List<Sensor> sensors;
  final LoRaWANIdentity? loRaWANIdentity;

  // Lifecycle audit and commissioning metadata
  final String? commissioningToken;
  final String? replacedByNodeId;
  final String? replacesNodeId;
  final DateTime? replacedAt;
  final DateTime? commissionedAt;

  // Direct cached readings for performance and backward compatibility
  final double? _soilMoisturePercent;
  final double? _waterLevelCm;
  final double? _waterLevelDistanceCm;
  final double? _temperatureCelsius;
  final double? _humidityPercent;

  const Esp32Node({
    required this.id,
    required this.macAddress,
    required this.displayName,
    this.assignedFieldId,
    this.assignedFieldName,
    this.assignedZoneId,
    this.assignedZoneCode,
    this.assignedZoneName,
    this.assignedPointId,
    this.coordinates,
    required this.transmissionConfig,
    required this.isOnline,
    this.lifecycleState = NodeLifecycleStatus.active,
    this.pairingStatus,
    this.assignmentStatus,
    this.connectivityStatus,
    this.soilSensorHealth,
    this.ultrasonicSensorHealth,
    this.telemetryStatus,
    this.hardwareRevision = 'v2.1',
    this.firmwareVersion = '1.0.0',
    this.batteryPercent,
    this.batteryVoltage,
    this.rssiDbm,
    this.snrDb,
    required this.lastSeen,
    this.sensors = const [],
    this.loRaWANIdentity,
    this.commissioningToken,
    this.replacedByNodeId,
    this.replacesNodeId,
    this.replacedAt,
    this.commissionedAt,
    double? soilMoisturePercent,
    double? waterLevelCm,
    double? waterLevelDistanceCm,
    double? temperatureCelsius,
    double? humidityPercent,
  })  : _soilMoisturePercent = soilMoisturePercent,
        _waterLevelCm = waterLevelCm,
        _waterLevelDistanceCm = waterLevelDistanceCm,
        _temperatureCelsius = temperatureCelsius,
        _humidityPercent = humidityPercent;

  NodeLifecycleStatus get lifecycleStatus => lifecycleState;

  double? get soilMoisturePercent {
    if (_soilMoisturePercent != null) return _soilMoisturePercent;
    for (final s in sensors) {
      if (s.type == SensorType.soilMoistureCapacitive && s.latestValue != null) {
        return s.latestValue;
      }
    }
    return null;
  }

  double? get waterLevelCm {
    if (_waterLevelCm != null) return _waterLevelCm;
    for (final s in sensors) {
      if (s.type == SensorType.waterLevelTube && s.latestValue != null) {
        return s.latestValue;
      }
    }
    return null;
  }

  double? get waterLevelDistanceCm {
    if (_waterLevelDistanceCm != null) return _waterLevelDistanceCm;
    for (final s in sensors) {
      if (s.type == SensorType.waterLevelTube && s.latestValue != null) {
        return s.latestValue;
      }
    }
    return null;
  }

  double? get temperatureCelsius {
    if (_temperatureCelsius != null) return _temperatureCelsius;
    for (final s in sensors) {
      if (s.type == SensorType.soilTemperature && s.latestValue != null) {
        return s.latestValue;
      }
    }
    return null;
  }

  double? get humidityPercent {
    if (_humidityPercent != null) return _humidityPercent;
    for (final s in sensors) {
      if (s.type == SensorType.ambientHumidity && s.latestValue != null) {
        return s.latestValue;
      }
    }
    return null;
  }

  bool get isRetired => lifecycleState.isRetired;
  bool get isTerminal => lifecycleState.isTerminal;

  bool get isAssigned =>
      (assignedZoneId != null &&
          assignedZoneId!.trim().isNotEmpty &&
          assignedZoneId!.toUpperCase() != 'UNASSIGNED') ||
      (assignmentStatus != null &&
          assignmentStatus!.toUpperCase().startsWith('ASSIGNED'));

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

  /// Returns a copy of this node whose telemetry fields are replaced by [snapshot].
  ///
  /// Only telemetry related fields are overwritten. Pairing, assignment and lifecycle
  /// state stay untouched so a telemetry refresh can never change the topology state
  /// of a node.
  ///
  /// Measurements that the snapshot does not contain are cleared instead of keeping
  /// the previous value, so a dashboard never presents an outdated measurement as if
  /// it were live.
  Esp32Node applyTelemetrySnapshot(NodeTelemetrySnapshot snapshot) {
    return Esp32Node(
      id: id,
      macAddress: macAddress,
      displayName: displayName,
      assignedFieldId: assignedFieldId,
      assignedFieldName: assignedFieldName,
      assignedZoneId: assignedZoneId,
      assignedZoneCode: assignedZoneCode,
      assignedZoneName: assignedZoneName,
      assignedPointId: assignedPointId,
      coordinates: coordinates,
      transmissionConfig: transmissionConfig,
      isOnline: snapshot.isOnline,
      lifecycleState: lifecycleState,
      pairingStatus: pairingStatus,
      assignmentStatus: assignmentStatus,
      connectivityStatus: snapshot.isOnline ? 'ONLINE' : 'OFFLINE',
      soilSensorHealth: snapshot.soilSensorHealth ?? soilSensorHealth,
      ultrasonicSensorHealth:
          snapshot.ultrasonicSensorHealth ?? ultrasonicSensorHealth,
      telemetryStatus: snapshot.telemetryStatus ?? telemetryStatus,
      hardwareRevision: hardwareRevision,
      firmwareVersion: firmwareVersion,
      batteryPercent: snapshot.batteryPercent ?? batteryPercent,
      batteryVoltage: snapshot.batteryVoltage ?? batteryVoltage,
      rssiDbm: rssiDbm,
      snrDb: snrDb,
      lastSeen: snapshot.lastTelemetryAt ?? lastSeen,
      sensors: sensors,
      loRaWANIdentity: loRaWANIdentity,
      commissioningToken: commissioningToken,
      replacedByNodeId: replacedByNodeId,
      replacesNodeId: replacesNodeId,
      replacedAt: replacedAt,
      commissionedAt: commissionedAt,
      soilMoisturePercent: snapshot.soilMoisturePercent,
      waterLevelCm: snapshot.waterLevelCm,
      waterLevelDistanceCm: snapshot.waterLevelDistanceCm,
      temperatureCelsius: temperatureCelsius,
      humidityPercent: humidityPercent,
    );
  }

  Esp32Node copyWith({
    String? id,
    String? macAddress,
    String? displayName,
    String? assignedFieldId,
    String? assignedFieldName,
    String? assignedZoneId,
    String? assignedZoneCode,
    String? assignedZoneName,
    String? assignedPointId,
    SpatialCoordinates? coordinates,
    TransmissionConfig? transmissionConfig,
    bool? isOnline,
    NodeLifecycleStatus? lifecycleState,
    NodeLifecycleStatus? lifecycleStatus,
    String? pairingStatus,
    String? assignmentStatus,
    String? connectivityStatus,
    String? soilSensorHealth,
    String? ultrasonicSensorHealth,
    String? telemetryStatus,
    String? hardwareRevision,
    String? firmwareVersion,
    int? batteryPercent,
    double? batteryVoltage,
    int? rssiDbm,
    double? snrDb,
    DateTime? lastSeen,
    List<Sensor>? sensors,
    LoRaWANIdentity? loRaWANIdentity,
    String? commissioningToken,
    String? replacedByNodeId,
    String? replacesNodeId,
    DateTime? replacedAt,
    DateTime? commissionedAt,
    double? soilMoisturePercent,
    double? waterLevelCm,
    double? waterLevelDistanceCm,
    double? temperatureCelsius,
    double? humidityPercent,
  }) {
    return Esp32Node(
      id: id ?? this.id,
      macAddress: macAddress ?? this.macAddress,
      displayName: displayName ?? this.displayName,
      assignedFieldId: assignedFieldId ?? this.assignedFieldId,
      assignedFieldName: assignedFieldName ?? this.assignedFieldName,
      assignedZoneId: assignedZoneId ?? this.assignedZoneId,
      assignedZoneCode: assignedZoneCode ?? this.assignedZoneCode,
      assignedZoneName: assignedZoneName ?? this.assignedZoneName,
      assignedPointId: assignedPointId ?? this.assignedPointId,
      coordinates: coordinates ?? this.coordinates,
      transmissionConfig: transmissionConfig ?? this.transmissionConfig,
      isOnline: isOnline ?? this.isOnline,
      lifecycleState: lifecycleStatus ?? lifecycleState ?? this.lifecycleState,
      pairingStatus: pairingStatus ?? this.pairingStatus,
      assignmentStatus: assignmentStatus ?? this.assignmentStatus,
      connectivityStatus: connectivityStatus ?? this.connectivityStatus,
      soilSensorHealth: soilSensorHealth ?? this.soilSensorHealth,
      ultrasonicSensorHealth:
          ultrasonicSensorHealth ?? this.ultrasonicSensorHealth,
      telemetryStatus: telemetryStatus ?? this.telemetryStatus,
      hardwareRevision: hardwareRevision ?? this.hardwareRevision,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      rssiDbm: rssiDbm ?? this.rssiDbm,
      snrDb: snrDb ?? this.snrDb,
      lastSeen: lastSeen ?? this.lastSeen,
      sensors: sensors ?? this.sensors,
      loRaWANIdentity: loRaWANIdentity ?? this.loRaWANIdentity,
      commissioningToken: commissioningToken ?? this.commissioningToken,
      replacedByNodeId: replacedByNodeId ?? this.replacedByNodeId,
      replacesNodeId: replacesNodeId ?? this.replacesNodeId,
      replacedAt: replacedAt ?? this.replacedAt,
      commissionedAt: commissionedAt ?? this.commissionedAt,
      soilMoisturePercent: soilMoisturePercent ?? this.soilMoisturePercent,
      waterLevelCm: waterLevelCm ?? this.waterLevelCm,
      waterLevelDistanceCm: waterLevelDistanceCm ?? this.waterLevelDistanceCm,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      humidityPercent: humidityPercent ?? this.humidityPercent,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'macAddress': macAddress,
        'displayName': displayName,
        if (assignedFieldId != null) 'assignedFieldId': assignedFieldId,
        if (assignedFieldName != null) 'assignedFieldName': assignedFieldName,
        if (assignedZoneId != null) 'assignedZoneId': assignedZoneId,
        if (assignedZoneCode != null) 'assignedZoneCode': assignedZoneCode,
        if (assignedZoneName != null) 'assignedZoneName': assignedZoneName,
        if (assignedPointId != null) 'assignedPointId': assignedPointId,
        if (coordinates != null) 'coordinates': coordinates!.toJson(),
        'transmissionConfig': transmissionConfig.toJson(),
        'isOnline': isOnline,
        'lifecycleState': lifecycleState.name,
        if (pairingStatus != null) 'pairingStatus': pairingStatus,
        if (assignmentStatus != null) 'assignmentStatus': assignmentStatus,
        if (connectivityStatus != null)
          'connectivityStatus': connectivityStatus,
        if (soilSensorHealth != null) 'soilSensorHealth': soilSensorHealth,
        if (ultrasonicSensorHealth != null)
          'ultrasonicSensorHealth': ultrasonicSensorHealth,
        if (telemetryStatus != null) 'telemetryStatus': telemetryStatus,
        'hardwareRevision': hardwareRevision,
        'firmwareVersion': firmwareVersion,
        if (batteryPercent != null) 'batteryPercent': batteryPercent,
        if (batteryVoltage != null) 'batteryVoltage': batteryVoltage,
        if (rssiDbm != null) 'rssiDbm': rssiDbm,
        if (snrDb != null) 'snrDb': snrDb,
        'lastSeen': lastSeen.toIso8601String(),
        'sensors': sensors.map((s) => s.toJson()).toList(),
        if (loRaWANIdentity != null) 'loRaWANIdentity': loRaWANIdentity!.toJson(),
        if (commissioningToken != null) 'commissioningToken': commissioningToken,
        if (replacedByNodeId != null) 'replacedByNodeId': replacedByNodeId,
        if (replacesNodeId != null) 'replacesNodeId': replacesNodeId,
        if (replacedAt != null) 'replacedAt': replacedAt!.toIso8601String(),
        if (commissionedAt != null)
          'commissionedAt': commissionedAt!.toIso8601String(),
        if (_soilMoisturePercent != null)
          'soilMoisturePercent': _soilMoisturePercent,
        if (_waterLevelCm != null) 'waterLevelCm': _waterLevelCm,
        if (_waterLevelDistanceCm != null)
          'waterLevelDistanceCm': _waterLevelDistanceCm,
        if (_temperatureCelsius != null)
          'temperatureCelsius': _temperatureCelsius,
        if (_humidityPercent != null) 'humidityPercent': _humidityPercent,
      };

  factory Esp32Node.fromJson(Map<String, dynamic> json) {
    final sensorHealthMap = json['sensorHealth'] is Map
        ? Map<String, dynamic>.from(json['sensorHealth'] as Map)
        : null;
    return Esp32Node(
      id: (json['nodeId'] ?? json['id']) as String,
      macAddress: json['macAddress'] as String? ?? '00:00:00:00:00:00',
      displayName: json['displayName'] as String? ?? 'ESP32 Node',
      assignedFieldId: (json['assignedFieldId'] ?? json['fieldId'])?.toString(),
      assignedFieldName: (json['assignedFieldName'] ?? json['fieldName'])?.toString(),
      assignedZoneId: (json['assignedZoneId'] ?? json['monitoringZoneId'])?.toString(),
      assignedZoneCode: (json['assignedZoneCode'] ?? json['monitoringZoneCode'])?.toString(),
      assignedZoneName: (json['assignedZoneName'] ?? json['monitoringZoneName'])?.toString(),
      assignedPointId: json['assignedPointId'] as String?,
      coordinates: json['coordinates'] != null
          ? SpatialCoordinates.fromJson(
              json['coordinates'] as Map<String, dynamic>,
            )
          : null,
      transmissionConfig: json['transmissionConfig'] != null
          ? TransmissionConfig.fromJson(
              json['transmissionConfig'] as Map<String, dynamic>,
            )
          : const TransmissionConfig(),
      isOnline: json['isOnline'] as bool? ?? false,
      lifecycleState: NodeLifecycleStatus.values.firstWhere(
        (e) => e.name == json['lifecycleState'],
        orElse: () => NodeLifecycleStatus.active,
      ),
      pairingStatus: json['pairingStatus']?.toString(),
      assignmentStatus: json['assignmentStatus']?.toString(),
      connectivityStatus: json['connectivityStatus']?.toString(),
      soilSensorHealth: (json['soilSensorHealth'] ?? sensorHealthMap?['soilMoisture'])?.toString(),
      ultrasonicSensorHealth: (json['ultrasonicSensorHealth'] ?? sensorHealthMap?['ultrasonic'])?.toString(),
      telemetryStatus: json['telemetryStatus']?.toString(),
      hardwareRevision: json['hardwareRevision'] as String? ?? 'v2.1',
      firmwareVersion: json['firmwareVersion'] as String? ?? '1.0.0',
      batteryPercent: json['batteryPercent'] as int?,
      batteryVoltage: (json['batteryVoltage'] as num?)?.toDouble(),
      rssiDbm: json['rssiDbm'] as int?,
      snrDb: (json['snrDb'] as num?)?.toDouble(),
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : DateTime.now(),
      sensors: (json['sensors'] as List<dynamic>?)
              ?.map((s) => Sensor.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
      loRaWANIdentity: json['loRaWANIdentity'] != null
          ? LoRaWANIdentity.fromJson(
              json['loRaWANIdentity'] as Map<String, dynamic>,
            )
          : null,
      commissioningToken: json['commissioningToken'] as String?,
      replacedByNodeId: json['replacedByNodeId'] as String?,
      replacesNodeId: json['replacesNodeId'] as String?,
      replacedAt: json['replacedAt'] != null
          ? DateTime.parse(json['replacedAt'] as String)
          : null,
      commissionedAt: json['commissionedAt'] != null
          ? DateTime.parse(json['commissionedAt'] as String)
          : null,
      soilMoisturePercent: (json['soilMoisturePercent'] as num?)?.toDouble(),
      waterLevelCm: (json['waterLevelCm'] as num?)?.toDouble(),
      waterLevelDistanceCm: (json['waterLevelDistanceCm'] as num?)?.toDouble() ??
          (json['waterLevelDistance'] as num?)?.toDouble(),
      temperatureCelsius: (json['temperatureCelsius'] as num?)?.toDouble(),
      humidityPercent: (json['humidityPercent'] as num?)?.toDouble(),
    );
  }
}

/// Domain alias representing a physical sensor node hardware device in field topology.
typedef SensorNode = Esp32Node;
