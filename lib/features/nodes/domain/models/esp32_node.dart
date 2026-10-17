import 'lorawan_identity.dart';
import 'node_enums.dart';
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
  final String? assignedZoneId;
  final String? assignedPointId;
  final SpatialCoordinates? coordinates;
  final TransmissionConfig transmissionConfig;
  final bool isOnline;
  final NodeLifecycleStatus lifecycleState;
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
    this.assignedZoneId,
    this.assignedPointId,
    this.coordinates,
    required this.transmissionConfig,
    required this.isOnline,
    this.lifecycleState = NodeLifecycleStatus.active,
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

  Esp32Node copyWith({
    String? id,
    String? macAddress,
    String? displayName,
    String? assignedFieldId,
    String? assignedZoneId,
    String? assignedPointId,
    SpatialCoordinates? coordinates,
    TransmissionConfig? transmissionConfig,
    bool? isOnline,
    NodeLifecycleStatus? lifecycleState,
    NodeLifecycleStatus? lifecycleStatus,
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
      assignedZoneId: assignedZoneId ?? this.assignedZoneId,
      assignedPointId: assignedPointId ?? this.assignedPointId,
      coordinates: coordinates ?? this.coordinates,
      transmissionConfig: transmissionConfig ?? this.transmissionConfig,
      isOnline: isOnline ?? this.isOnline,
      lifecycleState: lifecycleStatus ?? lifecycleState ?? this.lifecycleState,
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
        if (assignedZoneId != null) 'assignedZoneId': assignedZoneId,
        if (assignedPointId != null) 'assignedPointId': assignedPointId,
        if (coordinates != null) 'coordinates': coordinates!.toJson(),
        'transmissionConfig': transmissionConfig.toJson(),
        'isOnline': isOnline,
        'lifecycleState': lifecycleState.name,
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
    return Esp32Node(
      id: json['id'] as String,
      macAddress: json['macAddress'] as String,
      displayName: json['displayName'] as String? ?? 'ESP32 Node',
      assignedFieldId: json['assignedFieldId'] as String?,
      assignedZoneId: json['assignedZoneId'] as String?,
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
