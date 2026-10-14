typedef JsonMap = Map<String, dynamic>;

class ResourceDto {
  final String? id;
  final JsonMap data;

  const ResourceDto({this.id, required this.data});

  factory ResourceDto.fromJson(Object? json) {
    if (json is! JsonMap) {
      throw const FormatException('Expected a JSON object.');
    }
    final rawId = json['id'];
    return ResourceDto(
      id: rawId?.toString(),
      data: Map<String, dynamic>.from(json),
    );
  }
}

class ResourceListDto {
  final List<ResourceDto> items;

  const ResourceListDto(this.items);

  factory ResourceListDto.fromJson(Object? json) {
    final rawItems = json is List
        ? json
        : json is JsonMap && json['items'] is List
            ? json['items'] as List
            : const [];
    return ResourceListDto(
      rawItems.map(ResourceDto.fromJson).toList(growable: false),
    );
  }
}

class AuthResponseDto {
  final String accessToken;
  final String? refreshToken;
  final JsonMap user;

  const AuthResponseDto({
    required this.accessToken,
    this.refreshToken,
    required this.user,
  });

  factory AuthResponseDto.fromJson(Object? json) {
    if (json is! JsonMap || json['accessToken'] is! String) {
      throw const FormatException('Authentication response is missing accessToken.');
    }
    return AuthResponseDto(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      user: json['user'] is JsonMap
          ? Map<String, dynamic>.from(json['user'] as JsonMap)
          : const {},
    );
  }
}

class IrrigationCommandDto {
  static const entireField = 'ENTIRE FIELD';

  final String target;
  final int? durationMinutes;

  const IrrigationCommandDto({
    this.target = entireField,
    this.durationMinutes,
  });

  JsonMap toJson() {
    if (target != entireField) {
      throw const FormatException('Irrigation commands require ENTIRE FIELD target.');
    }
    return {
      'target': target,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
    };
  }
}

class IrrigationResultDto {
  final JsonMap data;

  const IrrigationResultDto(this.data);

  factory IrrigationResultDto.fromJson(Object? json) {
    if (json is! JsonMap) {
      throw const FormatException('Irrigation response is not an object.');
    }
    return IrrigationResultDto(Map<String, dynamic>.from(json));
  }
}

class Esp32NodeDto {
  final String id;
  final String macAddress;
  final String displayName;
  final String? assignedFieldId;
  final String? assignedZoneId;
  final double? latitude;
  final double? longitude;
  final double? localX;
  final double? localY;
  final int transmissionIntervalSeconds;
  final bool isAdaptive;
  final String? adaptiveReason;
  final bool isOnline;
  final String lifecycleState;
  final int? batteryPercent;
  final double? batteryVoltage;
  final int? rssiDbm;
  final double? snrDb;
  final String? lastSeen;
  final JsonMap? latestTelemetry;
  final String? commissioningToken;
  final String? replacedByNodeId;
  final String? replacesNodeId;
  final String? replacedAt;
  final String? commissionedAt;

  const Esp32NodeDto({
    required this.id,
    required this.macAddress,
    required this.displayName,
    this.assignedFieldId,
    this.assignedZoneId,
    this.latitude,
    this.longitude,
    this.localX,
    this.localY,
    required this.transmissionIntervalSeconds,
    this.isAdaptive = false,
    this.adaptiveReason,
    this.isOnline = true,
    this.lifecycleState = 'active',
    this.batteryPercent,
    this.batteryVoltage,
    this.rssiDbm,
    this.snrDb,
    this.lastSeen,
    this.latestTelemetry,
    this.commissioningToken,
    this.replacedByNodeId,
    this.replacesNodeId,
    this.replacedAt,
    this.commissionedAt,
  });

  factory Esp32NodeDto.fromJson(JsonMap json) {
    return Esp32NodeDto(
      id: json['id']?.toString() ?? '',
      macAddress: json['macAddress']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? json['name']?.toString() ?? 'ESP32 Node',
      assignedFieldId: json['assignedFieldId']?.toString(),
      assignedZoneId: json['assignedZoneId']?.toString(),
      latitude: json['latitude'] == null ? null : double.tryParse(json['latitude'].toString()),
      longitude: json['longitude'] == null ? null : double.tryParse(json['longitude'].toString()),
      localX: json['localX'] == null ? null : double.tryParse(json['localX'].toString()),
      localY: json['localY'] == null ? null : double.tryParse(json['localY'].toString()),
      transmissionIntervalSeconds: int.tryParse(json['transmissionIntervalSeconds']?.toString() ?? '') ?? 300,
      isAdaptive: json['isAdaptive'] as bool? ?? false,
      adaptiveReason: json['adaptiveReason']?.toString(),
      isOnline: json['isOnline'] as bool? ?? false,
      lifecycleState: json['lifecycleState']?.toString() ?? 'active',
      batteryPercent: json['batteryPercent'] == null ? null : int.tryParse(json['batteryPercent'].toString()),
      batteryVoltage: json['batteryVoltage'] == null ? null : double.tryParse(json['batteryVoltage'].toString()),
      rssiDbm: json['rssiDbm'] == null ? null : int.tryParse(json['rssiDbm'].toString()),
      snrDb: json['snrDb'] == null ? null : double.tryParse(json['snrDb'].toString()),
      lastSeen: json['lastSeen']?.toString(),
      latestTelemetry: json['latestTelemetry'] is JsonMap ? json['latestTelemetry'] as JsonMap : null,
      commissioningToken: json['commissioningToken']?.toString(),
      replacedByNodeId: json['replacedByNodeId']?.toString(),
      replacesNodeId: json['replacesNodeId']?.toString(),
      replacedAt: json['replacedAt']?.toString(),
      commissionedAt: json['commissionedAt']?.toString(),
    );
  }

  JsonMap toJson() => {
        'id': id,
        'macAddress': macAddress,
        'displayName': displayName,
        'assignedFieldId': assignedFieldId,
        'assignedZoneId': assignedZoneId,
        'latitude': latitude,
        'longitude': longitude,
        'localX': localX,
        'localY': localY,
        'transmissionIntervalSeconds': transmissionIntervalSeconds,
        'isAdaptive': isAdaptive,
        'adaptiveReason': adaptiveReason,
        'isOnline': isOnline,
        'lifecycleState': lifecycleState,
        'batteryPercent': batteryPercent,
        'batteryVoltage': batteryVoltage,
        'rssiDbm': rssiDbm,
        'snrDb': snrDb,
        'lastSeen': lastSeen,
        'latestTelemetry': latestTelemetry,
        if (commissioningToken != null) 'commissioningToken': commissioningToken,
        if (replacedByNodeId != null) 'replacedByNodeId': replacedByNodeId,
        if (replacesNodeId != null) 'replacesNodeId': replacesNodeId,
        if (replacedAt != null) 'replacedAt': replacedAt,
        if (commissionedAt != null) 'commissionedAt': commissionedAt,
      };
}

class DiscoveredNodeDto {
  final String id;
  final String macAddress;
  final String hardwareModel;
  final String firmwareVersion;
  final int rssiDbm;
  final String detectedAt;

  const DiscoveredNodeDto({
    required this.id,
    required this.macAddress,
    required this.hardwareModel,
    required this.firmwareVersion,
    required this.rssiDbm,
    required this.detectedAt,
  });

  factory DiscoveredNodeDto.fromJson(JsonMap json) => DiscoveredNodeDto(
        id: json['id']?.toString() ?? '',
        macAddress: json['macAddress']?.toString() ?? '',
        hardwareModel: json['hardwareModel']?.toString() ?? 'ESP32 LoRa Node',
        firmwareVersion: json['firmwareVersion']?.toString() ?? '1.0.0',
        rssiDbm: int.tryParse(json['rssiDbm']?.toString() ?? '') ?? -85,
        detectedAt: json['detectedAt']?.toString() ?? DateTime.now().toIso8601String(),
      );
}

class NodeRegistrationRequestDto {
  final String macAddress;
  final String displayName;
  final String fieldId;
  final String zoneId;
  final double? latitude;
  final double? longitude;
  final double? localX;
  final double? localY;
  final int transmissionIntervalSeconds;

  const NodeRegistrationRequestDto({
    required this.macAddress,
    required this.displayName,
    required this.fieldId,
    required this.zoneId,
    this.latitude,
    this.longitude,
    this.localX,
    this.localY,
    this.transmissionIntervalSeconds = 300,
  });

  JsonMap toJson() => {
        'macAddress': macAddress,
        'displayName': displayName,
        'fieldId': fieldId,
        'zoneId': zoneId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (localX != null) 'localX': localX,
        if (localY != null) 'localY': localY,
        'transmissionIntervalSeconds': transmissionIntervalSeconds,
      };
}

class NodeSpatialAssignmentDto {
  final String fieldId;
  final String zoneId;
  final double? latitude;
  final double? longitude;
  final double? localX;
  final double? localY;

  const NodeSpatialAssignmentDto({
    required this.fieldId,
    required this.zoneId,
    this.latitude,
    this.longitude,
    this.localX,
    this.localY,
  });

  JsonMap toJson() => {
        'fieldId': fieldId,
        'zoneId': zoneId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (localX != null) 'localX': localX,
        if (localY != null) 'localY': localY,
      };
}

class NodeLifecycleUpdateDto {
  final String state;
  final String? reason;
  final String? notes;

  const NodeLifecycleUpdateDto({
    required this.state,
    this.reason,
    this.notes,
  });

  JsonMap toJson() => {
        'state': state,
        if (reason != null) 'reason': reason,
        if (notes != null) 'notes': notes,
      };

  factory NodeLifecycleUpdateDto.fromJson(JsonMap json) =>
      NodeLifecycleUpdateDto(
        state: json['state']?.toString() ?? 'active',
        reason: json['reason']?.toString(),
        notes: json['notes']?.toString(),
      );
}

class NodeProvisioningRequestDto {
  final String commissioningToken;
  final String fieldId;
  final String? zoneId;
  final String? monitoringPointId;
  final double? latitude;
  final double? longitude;
  final double? localX;
  final double? localY;

  const NodeProvisioningRequestDto({
    required this.commissioningToken,
    required this.fieldId,
    this.zoneId,
    this.monitoringPointId,
    this.latitude,
    this.longitude,
    this.localX,
    this.localY,
  });

  JsonMap toJson() => {
        'commissioningToken': commissioningToken,
        'fieldId': fieldId,
        if (zoneId != null) 'zoneId': zoneId,
        if (monitoringPointId != null) 'monitoringPointId': monitoringPointId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (localX != null) 'localX': localX,
        if (localY != null) 'localY': localY,
      };

  factory NodeProvisioningRequestDto.fromJson(JsonMap json) =>
      NodeProvisioningRequestDto(
        commissioningToken: json['commissioningToken']?.toString() ?? '',
        fieldId: json['fieldId']?.toString() ?? '',
        zoneId: json['zoneId']?.toString(),
        monitoringPointId: json['monitoringPointId']?.toString(),
        latitude: json['latitude'] == null
            ? null
            : double.tryParse(json['latitude'].toString()),
        longitude: json['longitude'] == null
            ? null
            : double.tryParse(json['longitude'].toString()),
        localX: json['localX'] == null
            ? null
            : double.tryParse(json['localX'].toString()),
        localY: json['localY'] == null
            ? null
            : double.tryParse(json['localY'].toString()),
      );
}

class NodeReplacementRequestDto {
  final String replacementNodeId;
  final String? reason;
  final bool transferCalibration;

  const NodeReplacementRequestDto({
    required this.replacementNodeId,
    this.reason,
    this.transferCalibration = true,
  });

  JsonMap toJson() => {
        'replacementNodeId': replacementNodeId,
        if (reason != null) 'reason': reason,
        'transferCalibration': transferCalibration,
      };

  factory NodeReplacementRequestDto.fromJson(JsonMap json) =>
      NodeReplacementRequestDto(
        replacementNodeId: json['replacementNodeId']?.toString() ?? '',
        reason: json['reason']?.toString(),
        transferCalibration: json['transferCalibration'] as bool? ?? true,
      );
}

class NodeReplacementResultDto {
  final String oldNodeId;
  final String replacementNodeId;
  final String fieldId;
  final String zoneId;
  final String? monitoringPointId;
  final String replacedAt;
  final String? reason;
  final bool historicalMeasurementsPreserved;
  final Esp32NodeDto updatedReplacementNode;
  final Esp32NodeDto retiredNode;

  const NodeReplacementResultDto({
    required this.oldNodeId,
    required this.replacementNodeId,
    required this.fieldId,
    required this.zoneId,
    this.monitoringPointId,
    required this.replacedAt,
    this.reason,
    this.historicalMeasurementsPreserved = true,
    required this.updatedReplacementNode,
    required this.retiredNode,
  });

  factory NodeReplacementResultDto.fromJson(JsonMap json) =>
      NodeReplacementResultDto(
        oldNodeId: json['oldNodeId']?.toString() ?? '',
        replacementNodeId: json['replacementNodeId']?.toString() ?? '',
        fieldId: json['fieldId']?.toString() ?? '',
        zoneId: json['zoneId']?.toString() ?? '',
        monitoringPointId: json['monitoringPointId']?.toString(),
        replacedAt: json['replacedAt']?.toString() ??
            DateTime.now().toIso8601String(),
        reason: json['reason']?.toString(),
        historicalMeasurementsPreserved:
            json['historicalMeasurementsPreserved'] as bool? ?? true,
        updatedReplacementNode: Esp32NodeDto.fromJson(
          json['updatedReplacementNode'] as JsonMap? ?? {},
        ),
        retiredNode: Esp32NodeDto.fromJson(
          json['retiredNode'] as JsonMap? ?? {},
        ),
      );

  JsonMap toJson() => {
        'oldNodeId': oldNodeId,
        'replacementNodeId': replacementNodeId,
        'fieldId': fieldId,
        'zoneId': zoneId,
        if (monitoringPointId != null) 'monitoringPointId': monitoringPointId,
        'replacedAt': replacedAt,
        if (reason != null) 'reason': reason,
        'historicalMeasurementsPreserved': historicalMeasurementsPreserved,
        'updatedReplacementNode': updatedReplacementNode.toJson(),
        'retiredNode': retiredNode.toJson(),
      };
}

class TransmissionConfigDto {
  final int intervalSeconds;
  final bool isAdaptive;
  final String? reason;

  const TransmissionConfigDto({
    required this.intervalSeconds,
    this.isAdaptive = false,
    this.reason,
  });

  factory TransmissionConfigDto.fromJson(JsonMap json) => TransmissionConfigDto(
        intervalSeconds: int.tryParse(json['intervalSeconds']?.toString() ??
                json['transmissionIntervalSeconds']?.toString() ??
                '') ??
            300,
        isAdaptive: json['isAdaptive'] as bool? ?? false,
        reason: json['reason']?.toString() ?? json['adaptiveReason']?.toString(),
      );

  JsonMap toJson() => {
        'intervalSeconds': intervalSeconds,
        'isAdaptive': isAdaptive,
        if (reason != null) 'reason': reason,
      };
}

class MeasurementDto {
  final String id;
  final String timestamp;
  final String sensorId;
  final String pointId;
  final double rawValue;
  final double calibratedValue;
  final String qualityFlag;

  const MeasurementDto({
    required this.id,
    required this.timestamp,
    required this.sensorId,
    required this.pointId,
    required this.rawValue,
    required this.calibratedValue,
    this.qualityFlag = 'valid',
  });

  factory MeasurementDto.fromJson(JsonMap json) => MeasurementDto(
        id: json['id']?.toString() ?? '',
        timestamp: json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
        sensorId: json['sensorId']?.toString() ?? '',
        pointId: json['pointId']?.toString() ?? '',
        rawValue: (json['rawValue'] as num?)?.toDouble() ?? 0.0,
        calibratedValue: (json['calibratedValue'] as num?)?.toDouble() ?? 0.0,
        qualityFlag: json['qualityFlag']?.toString() ?? 'valid',
      );

  JsonMap toJson() => {
        'id': id,
        'timestamp': timestamp,
        'sensorId': sensorId,
        'pointId': pointId,
        'rawValue': rawValue,
        'calibratedValue': calibratedValue,
        'qualityFlag': qualityFlag,
      };
}

class SensorDto {
  final String id;
  final String nodeId;
  final String type;
  final int channelIndex;
  final String unit;
  final double? depthOffsetCm;
  final Map<String, double>? calibrationCoefficients;
  final MeasurementDto? latestMeasurement;
  final bool isActive;

  const SensorDto({
    required this.id,
    required this.nodeId,
    required this.type,
    this.channelIndex = 0,
    required this.unit,
    this.depthOffsetCm,
    this.calibrationCoefficients,
    this.latestMeasurement,
    this.isActive = true,
  });

  factory SensorDto.fromJson(JsonMap json) => SensorDto(
        id: json['id']?.toString() ?? '',
        nodeId: json['nodeId']?.toString() ?? '',
        type: json['type']?.toString() ?? 'waterLevelTube',
        channelIndex: int.tryParse(json['channelIndex']?.toString() ?? '') ?? 0,
        unit: json['unit']?.toString() ?? '',
        depthOffsetCm: json['depthOffsetCm'] == null
            ? null
            : double.tryParse(json['depthOffsetCm'].toString()),
        calibrationCoefficients: (json['calibrationCoefficients'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
        latestMeasurement: json['latestMeasurement'] is JsonMap
            ? MeasurementDto.fromJson(json['latestMeasurement'] as JsonMap)
            : null,
        isActive: json['isActive'] as bool? ?? true,
      );

  JsonMap toJson() => {
        'id': id,
        'nodeId': nodeId,
        'type': type,
        'channelIndex': channelIndex,
        'unit': unit,
        if (depthOffsetCm != null) 'depthOffsetCm': depthOffsetCm,
        if (calibrationCoefficients != null)
          'calibrationCoefficients': calibrationCoefficients,
        if (latestMeasurement != null)
          'latestMeasurement': latestMeasurement!.toJson(),
        'isActive': isActive,
      };
}

class MonitoringPointDto {
  final String id;
  final String fieldId;
  final String zoneId;
  final String code;
  final String label;
  final double? latitude;
  final double? longitude;
  final double? localX;
  final double? localY;
  final double? elevationMeters;
  final double relativeElevationCm;
  final double tubeDatumOffsetCm;
  final String? assignedNodeId;
  final bool isActive;

  const MonitoringPointDto({
    required this.id,
    required this.fieldId,
    required this.zoneId,
    required this.code,
    required this.label,
    this.latitude,
    this.longitude,
    this.localX,
    this.localY,
    this.elevationMeters,
    this.relativeElevationCm = 0.0,
    this.tubeDatumOffsetCm = 0.0,
    this.assignedNodeId,
    this.isActive = true,
  });

  factory MonitoringPointDto.fromJson(JsonMap json) => MonitoringPointDto(
        id: json['id']?.toString() ?? '',
        fieldId: json['fieldId']?.toString() ?? '',
        zoneId: json['zoneId']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        label: json['label']?.toString() ?? json['code']?.toString() ?? '',
        latitude: json['latitude'] == null
            ? null
            : double.tryParse(json['latitude'].toString()),
        longitude: json['longitude'] == null
            ? null
            : double.tryParse(json['longitude'].toString()),
        localX: json['localX'] == null
            ? null
            : double.tryParse(json['localX'].toString()),
        localY: json['localY'] == null
            ? null
            : double.tryParse(json['localY'].toString()),
        elevationMeters: json['elevationMeters'] == null
            ? null
            : double.tryParse(json['elevationMeters'].toString()),
        relativeElevationCm:
            double.tryParse(json['relativeElevationCm']?.toString() ?? '') ?? 0.0,
        tubeDatumOffsetCm:
            double.tryParse(json['tubeDatumOffsetCm']?.toString() ?? '') ?? 0.0,
        assignedNodeId: json['assignedNodeId']?.toString(),
        isActive: json['isActive'] as bool? ?? true,
      );

  JsonMap toJson() => {
        'id': id,
        'fieldId': fieldId,
        'zoneId': zoneId,
        'code': code,
        'label': label,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (localX != null) 'localX': localX,
        if (localY != null) 'localY': localY,
        if (elevationMeters != null) 'elevationMeters': elevationMeters,
        'relativeElevationCm': relativeElevationCm,
        'tubeDatumOffsetCm': tubeDatumOffsetCm,
        if (assignedNodeId != null) 'assignedNodeId': assignedNodeId,
        'isActive': isActive,
      };
}

class FieldDto {
  final String id;
  final String name;
  final String? description;
  final double areaSquareMeters;
  final String soilType;
  final String activeCropStage;
  final String awdProfileId;
  final String? centralControllerId;
  final List<Map<String, double>> boundaryCoordinates;
  final String createdAt;
  final String updatedAt;

  const FieldDto({
    required this.id,
    required this.name,
    this.description,
    this.areaSquareMeters = 10000.0,
    this.soilType = 'Clay Loam',
    this.activeCropStage = 'vegetativeTillering',
    this.awdProfileId = 'awd_standard_vegetative',
    this.centralControllerId,
    this.boundaryCoordinates = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory FieldDto.fromJson(JsonMap json) => FieldDto(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        areaSquareMeters: (json['areaSquareMeters'] as num?)?.toDouble() ?? 10000.0,
        soilType: json['soilType']?.toString() ?? 'Clay Loam',
        activeCropStage: json['activeCropStage']?.toString() ?? 'vegetativeTillering',
        awdProfileId: json['awdProfileId']?.toString() ?? 'awd_standard_vegetative',
        centralControllerId: json['centralControllerId']?.toString(),
        boundaryCoordinates: (json['boundaryCoordinates'] as List<dynamic>?)
                ?.map((item) => (item as Map<String, dynamic>)
                    .map((k, v) => MapEntry(k, (v as num).toDouble())))
                .toList() ??
            const [],
        createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        updatedAt: json['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      );

  JsonMap toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'areaSquareMeters': areaSquareMeters,
        'soilType': soilType,
        'activeCropStage': activeCropStage,
        'awdProfileId': awdProfileId,
        if (centralControllerId != null)
          'centralControllerId': centralControllerId,
        'boundaryCoordinates': boundaryCoordinates,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

class FieldTopologyDto {
  final FieldDto field;
  final List<MonitoringPointDto> points;
  final List<Esp32NodeDto> nodes;

  const FieldTopologyDto({
    required this.field,
    this.points = const [],
    this.nodes = const [],
  });

  factory FieldTopologyDto.fromJson(JsonMap json) => FieldTopologyDto(
        field: FieldDto.fromJson(json['field'] as JsonMap? ?? {}),
        points: (json['points'] as List<dynamic>?)
                ?.map((e) => MonitoringPointDto.fromJson(e as JsonMap))
                .toList() ??
            const [],
        nodes: (json['nodes'] as List<dynamic>?)
                ?.map((e) => Esp32NodeDto.fromJson(e as JsonMap))
                .toList() ??
            const [],
      );

  JsonMap toJson() => {
        'field': field.toJson(),
        'points': points.map((p) => p.toJson()).toList(),
        'nodes': nodes.map((n) => n.toJson()).toList(),
      };
}

class AutoIrrigationConfigDto {
  final String systemId;
  final bool isEnabled;
  final int maxDurationMinutes;
  final int minCooldownMinutes;
  final int allowedHoursStart;
  final int allowedHoursEnd;
  final double targetFloodDepthCm;
  final bool rainDelayEnabled;
  final int rainDelayHours;
  final double minConfidenceThreshold;
  final String? updatedAt;
  final String? updatedBy;

  const AutoIrrigationConfigDto({
    this.systemId = 'default',
    this.isEnabled = false,
    this.maxDurationMinutes = 45,
    this.minCooldownMinutes = 60,
    this.allowedHoursStart = 6,
    this.allowedHoursEnd = 18,
    this.targetFloodDepthCm = 5.0,
    this.rainDelayEnabled = true,
    this.rainDelayHours = 24,
    this.minConfidenceThreshold = 0.75,
    this.updatedAt,
    this.updatedBy,
  });

  factory AutoIrrigationConfigDto.fromJson(JsonMap json) =>
      AutoIrrigationConfigDto(
        systemId: json['systemId']?.toString() ?? 'default',
        isEnabled: json['isEnabled'] as bool? ?? false,
        maxDurationMinutes:
            (json['maxDurationMinutes'] as num?)?.toInt() ?? 45,
        minCooldownMinutes:
            (json['minCooldownMinutes'] as num?)?.toInt() ?? 60,
        allowedHoursStart: (json['allowedHoursStart'] as num?)?.toInt() ?? 6,
        allowedHoursEnd: (json['allowedHoursEnd'] as num?)?.toInt() ?? 18,
        targetFloodDepthCm:
            (json['targetFloodDepthCm'] as num?)?.toDouble() ?? 5.0,
        rainDelayEnabled: json['rainDelayEnabled'] as bool? ?? true,
        rainDelayHours: (json['rainDelayHours'] as num?)?.toInt() ?? 24,
        minConfidenceThreshold:
            (json['minConfidenceThreshold'] as num?)?.toDouble() ?? 0.75,
        updatedAt: json['updatedAt']?.toString(),
        updatedBy: json['updatedBy']?.toString(),
      );

  JsonMap toJson() => {
        'systemId': systemId,
        'isEnabled': isEnabled,
        'maxDurationMinutes': maxDurationMinutes,
        'minCooldownMinutes': minCooldownMinutes,
        'allowedHoursStart': allowedHoursStart,
        'allowedHoursEnd': allowedHoursEnd,
        'targetFloodDepthCm': targetFloodDepthCm,
        'rainDelayEnabled': rainDelayEnabled,
        'rainDelayHours': rainDelayHours,
        'minConfidenceThreshold': minConfidenceThreshold,
        if (updatedAt != null) 'updatedAt': updatedAt,
        if (updatedBy != null) 'updatedBy': updatedBy,
      };
}

class AutoIrrigationStatusDto {
  final String systemId;
  final String state;
  final String? activeCommandId;
  final String? startedAt;
  final int? targetDurationMinutes;
  final String? cooldownUntil;
  final String? lastEvaluationTime;
  final String? lastEvaluationResult;
  final String? lockoutReason;
  final String? lockoutTimestamp;
  final List<String> inhibitionReasons;

  const AutoIrrigationStatusDto({
    this.systemId = 'default',
    this.state = 'disabled',
    this.activeCommandId,
    this.startedAt,
    this.targetDurationMinutes,
    this.cooldownUntil,
    this.lastEvaluationTime,
    this.lastEvaluationResult,
    this.lockoutReason,
    this.lockoutTimestamp,
    this.inhibitionReasons = const [],
  });

  factory AutoIrrigationStatusDto.fromJson(JsonMap json) =>
      AutoIrrigationStatusDto(
        systemId: json['systemId']?.toString() ?? 'default',
        state: json['state']?.toString() ?? 'disabled',
        activeCommandId: json['activeCommandId']?.toString(),
        startedAt: json['startedAt']?.toString(),
        targetDurationMinutes:
            (json['targetDurationMinutes'] as num?)?.toInt(),
        cooldownUntil: json['cooldownUntil']?.toString(),
        lastEvaluationTime: json['lastEvaluationTime']?.toString(),
        lastEvaluationResult: json['lastEvaluationResult']?.toString(),
        lockoutReason: json['lockoutReason']?.toString(),
        lockoutTimestamp: json['lockoutTimestamp']?.toString(),
        inhibitionReasons: (json['inhibitionReasons'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
      );

  JsonMap toJson() => {
        'systemId': systemId,
        'state': state,
        if (activeCommandId != null) 'activeCommandId': activeCommandId,
        if (startedAt != null) 'startedAt': startedAt,
        if (targetDurationMinutes != null)
          'targetDurationMinutes': targetDurationMinutes,
        if (cooldownUntil != null) 'cooldownUntil': cooldownUntil,
        if (lastEvaluationTime != null)
          'lastEvaluationTime': lastEvaluationTime,
        if (lastEvaluationResult != null)
          'lastEvaluationResult': lastEvaluationResult,
        if (lockoutReason != null) 'lockoutReason': lockoutReason,
        if (lockoutTimestamp != null) 'lockoutTimestamp': lockoutTimestamp,
        'inhibitionReasons': inhibitionReasons,
      };
}

class ClearLockoutRequestDto {
  final String systemId;
  final String? resolutionNote;
  final String? clearedBy;

  const ClearLockoutRequestDto({
    this.systemId = 'default',
    this.resolutionNote,
    this.clearedBy,
  });

  factory ClearLockoutRequestDto.fromJson(JsonMap json) =>
      ClearLockoutRequestDto(
        systemId: json['systemId']?.toString() ?? 'default',
        resolutionNote: json['resolutionNote']?.toString(),
        clearedBy: json['clearedBy']?.toString(),
      );

  JsonMap toJson() => {
        'systemId': systemId,
        if (resolutionNote != null) 'resolutionNote': resolutionNote,
        if (clearedBy != null) 'clearedBy': clearedBy,
      };
}

class IrrigationActorDto {
  final String type;
  final String id;
  final String displayName;

  const IrrigationActorDto({
    required this.type,
    required this.id,
    required this.displayName,
  });

  factory IrrigationActorDto.fromJson(JsonMap json) => IrrigationActorDto(
        type: json['type']?.toString() ?? 'system',
        id: json['id']?.toString() ?? 'unknown',
        displayName: json['displayName']?.toString() ?? 'Unknown Actor',
      );

  JsonMap toJson() => {
        'type': type,
        'id': id,
        'displayName': displayName,
      };
}

class IrrigationExecutionAuditLogDto {
  final String id;
  final String systemId;
  final IrrigationActorDto actor;
  final String action;
  final String triggerContext;
  final double? triggeringDepthCm;
  final double? telemetryConfidenceScore;
  final String? cropStage;
  final int? targetDurationMinutes;
  final int? actualDurationMinutes;
  final String outcome;
  final String timestamp;
  final String? failureReason;

  const IrrigationExecutionAuditLogDto({
    required this.id,
    this.systemId = 'default',
    required this.actor,
    required this.action,
    required this.triggerContext,
    this.triggeringDepthCm,
    this.telemetryConfidenceScore,
    this.cropStage,
    this.targetDurationMinutes,
    this.actualDurationMinutes,
    required this.outcome,
    required this.timestamp,
    this.failureReason,
  });

  factory IrrigationExecutionAuditLogDto.fromJson(JsonMap json) =>
      IrrigationExecutionAuditLogDto(
        id: json['id']?.toString() ?? '',
        systemId: json['systemId']?.toString() ?? 'default',
        actor: IrrigationActorDto.fromJson(
            json['actor'] as JsonMap? ?? const {}),
        action: json['action']?.toString() ?? '',
        triggerContext: json['triggerContext']?.toString() ?? '',
        triggeringDepthCm: (json['triggeringDepthCm'] as num?)?.toDouble(),
        telemetryConfidenceScore:
            (json['telemetryConfidenceScore'] as num?)?.toDouble(),
        cropStage: json['cropStage']?.toString(),
        targetDurationMinutes:
            (json['targetDurationMinutes'] as num?)?.toInt(),
        actualDurationMinutes:
            (json['actualDurationMinutes'] as num?)?.toInt(),
        outcome: json['outcome']?.toString() ?? 'unknown',
        timestamp: json['timestamp']?.toString() ??
            DateTime.now().toIso8601String(),
        failureReason: json['failureReason']?.toString(),
      );

  JsonMap toJson() => {
        'id': id,
        'systemId': systemId,
        'actor': actor.toJson(),
        'action': action,
        'triggerContext': triggerContext,
        if (triggeringDepthCm != null) 'triggeringDepthCm': triggeringDepthCm,
        if (telemetryConfidenceScore != null)
          'telemetryConfidenceScore': telemetryConfidenceScore,
        if (cropStage != null) 'cropStage': cropStage,
        if (targetDurationMinutes != null)
          'targetDurationMinutes': targetDurationMinutes,
        if (actualDurationMinutes != null)
          'actualDurationMinutes': actualDurationMinutes,
        'outcome': outcome,
        'timestamp': timestamp,
        if (failureReason != null) 'failureReason': failureReason,
      };
}

class IrrigationAuditLogListDto {
  final List<IrrigationExecutionAuditLogDto> items;

  const IrrigationAuditLogListDto(this.items);

  factory IrrigationAuditLogListDto.fromJson(Object? json) {
    final rawItems = json is List
        ? json
        : json is JsonMap && json['items'] is List
            ? json['items'] as List
            : const [];
    return IrrigationAuditLogListDto(
      rawItems
          .whereType<JsonMap>()
          .map(IrrigationExecutionAuditLogDto.fromJson)
          .toList(growable: false),
    );
  }
}

class AuditActorDto {
  final String type;
  final String id;
  final String displayName;

  const AuditActorDto({
    required this.type,
    required this.id,
    required this.displayName,
  });

  factory AuditActorDto.fromJson(JsonMap json) => AuditActorDto(
        type: json['type']?.toString() ?? 'system',
        id: json['id']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? '',
      );

  JsonMap toJson() => {
        'type': type,
        'id': id,
        'displayName': displayName,
      };
}

class AuditTargetDto {
  final String type;
  final String id;
  final String? displayName;

  const AuditTargetDto({
    required this.type,
    required this.id,
    this.displayName,
  });

  factory AuditTargetDto.fromJson(JsonMap json) => AuditTargetDto(
        type: json['type']?.toString() ?? 'system',
        id: json['id']?.toString() ?? '',
        displayName: json['displayName']?.toString(),
      );

  JsonMap toJson() => {
        'type': type,
        'id': id,
        if (displayName != null) 'displayName': displayName,
      };
}

class AuditMetadataDto {
  final String? correlationId;
  final String? requestId;
  final String? clientIp;
  final JsonMap? priorState;
  final JsonMap? newState;
  final String? rationale;
  final String? failureReason;
  final JsonMap? ext;

  const AuditMetadataDto({
    this.correlationId,
    this.requestId,
    this.clientIp,
    this.priorState,
    this.newState,
    this.rationale,
    this.failureReason,
    this.ext,
  });

  factory AuditMetadataDto.fromJson(JsonMap json) => AuditMetadataDto(
        correlationId: json['correlationId']?.toString(),
        requestId: json['requestId']?.toString(),
        clientIp: json['clientIp']?.toString(),
        priorState: json['priorState'] is JsonMap ? json['priorState'] as JsonMap : null,
        newState: json['newState'] is JsonMap ? json['newState'] as JsonMap : null,
        rationale: json['rationale']?.toString(),
        failureReason: json['failureReason']?.toString(),
        ext: json['ext'] is JsonMap ? json['ext'] as JsonMap : null,
      );

  JsonMap toJson() => {
        if (correlationId != null) 'correlationId': correlationId,
        if (requestId != null) 'requestId': requestId,
        if (clientIp != null) 'clientIp': clientIp,
        if (priorState != null) 'priorState': priorState,
        if (newState != null) 'newState': newState,
        if (rationale != null) 'rationale': rationale,
        if (failureReason != null) 'failureReason': failureReason,
        if (ext != null) 'ext': ext,
      };
}

class AccountAuditEventDto {
  final String eventId;
  final String timestamp;
  final AuditActorDto actor;
  final String category;
  final String action;
  final AuditTargetDto target;
  final String result;
  final AuditMetadataDto metadata;

  const AccountAuditEventDto({
    required this.eventId,
    required this.timestamp,
    required this.actor,
    required this.category,
    required this.action,
    required this.target,
    required this.result,
    required this.metadata,
  });

  factory AccountAuditEventDto.fromJson(JsonMap json) => AccountAuditEventDto(
        eventId: json['eventId']?.toString() ?? '',
        timestamp: json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
        actor: json['actor'] is JsonMap
            ? AuditActorDto.fromJson(json['actor'] as JsonMap)
            : const AuditActorDto(type: 'system', id: 'sys', displayName: 'System'),
        category: json['category']?.toString() ?? 'system',
        action: json['action']?.toString() ?? '',
        target: json['target'] is JsonMap
            ? AuditTargetDto.fromJson(json['target'] as JsonMap)
            : const AuditTargetDto(type: 'system', id: 'sys'),
        result: json['result']?.toString() ?? 'success',
        metadata: json['metadata'] is JsonMap
            ? AuditMetadataDto.fromJson(json['metadata'] as JsonMap)
            : const AuditMetadataDto(),
      );

  JsonMap toJson() => {
        'eventId': eventId,
        'timestamp': timestamp,
        'actor': actor.toJson(),
        'category': category,
        'action': action,
        'target': target.toJson(),
        'result': result,
        'metadata': metadata.toJson(),
      };
}

class AccountAuditEventListDto {
  final List<AccountAuditEventDto> items;

  const AccountAuditEventListDto(this.items);

  factory AccountAuditEventListDto.fromJson(Object? json) {
    final rawItems = json is List
        ? json
        : json is JsonMap && json['items'] is List
            ? json['items'] as List
            : const [];
    return AccountAuditEventListDto(
      rawItems
          .whereType<JsonMap>()
          .map(AccountAuditEventDto.fromJson)
          .toList(growable: false),
    );
  }
}

class CommandStatusResponseDto {
  final String correlationId;
  final int? fieldId;
  final String operatorId;
  final String status;
  final String commandType;
  final String? rationale;
  final String? details;
  final String? createdAt;
  final String? updatedAt;

  const CommandStatusResponseDto({
    required this.correlationId,
    this.fieldId,
    required this.operatorId,
    required this.status,
    required this.commandType,
    this.rationale,
    this.details,
    this.createdAt,
    this.updatedAt,
  });

  factory CommandStatusResponseDto.fromJson(Object? json) {
    if (json is! JsonMap) {
      throw const FormatException('Expected a JSON object for CommandStatusResponseDto.');
    }
    return CommandStatusResponseDto(
      correlationId: json['correlationId']?.toString() ?? '',
      fieldId: json['fieldId'] is int
          ? json['fieldId'] as int
          : int.tryParse(json['fieldId']?.toString() ?? ''),
      operatorId: json['operatorId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'QUEUED',
      commandType: json['commandType']?.toString() ?? 'MANUAL_START',
      rationale: json['rationale']?.toString(),
      details: json['details']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}

class MasterStateDto {
  final bool masterEnabled;
  final String updatedBy;
  final String? notes;
  final String? updatedAt;

  const MasterStateDto({
    required this.masterEnabled,
    required this.updatedBy,
    this.notes,
    this.updatedAt,
  });

  factory MasterStateDto.fromJson(Object? json) {
    if (json is! JsonMap) {
      throw const FormatException('Expected a JSON object for MasterStateDto.');
    }
    return MasterStateDto(
      masterEnabled: json['masterEnabled'] == true,
      updatedBy: json['updatedBy']?.toString() ?? 'SYSTEM',
      notes: json['notes']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  JsonMap toJson() => {
    'enabled': masterEnabled,
    if (notes != null) 'notes': notes,
  };
}

class PairingRequestDto {
  final int id;
  final String nodeId;
  final String? hardwareModel;
  final String? firmwareVersion;
  final String? macAddress;
  final String pairingStatus; // PENDING, APPROVED, REJECTED
  final String? rejectionReason;
  final String requestedAt;
  final String? processedAt;
  final String? processedBy;
  final bool recognized;
  final int? existingEdgeNodeId;
  final String? existingLifecycleState;
  final int? existingZoneId;
  final String? existingZoneName;

  const PairingRequestDto({
    required this.id,
    required this.nodeId,
    this.hardwareModel,
    this.firmwareVersion,
    this.macAddress,
    required this.pairingStatus,
    this.rejectionReason,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
    this.recognized = false,
    this.existingEdgeNodeId,
    this.existingLifecycleState,
    this.existingZoneId,
    this.existingZoneName,
  });

  factory PairingRequestDto.fromJson(Object? json) {
    if (json is! JsonMap) {
      throw const FormatException('Expected a JSON object for PairingRequestDto.');
    }
    return PairingRequestDto(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      nodeId: json['nodeId']?.toString() ?? '',
      hardwareModel: json['hardwareModel']?.toString(),
      firmwareVersion: json['firmwareVersion']?.toString(),
      macAddress: json['macAddress']?.toString(),
      pairingStatus: json['pairingStatus']?.toString() ?? 'PENDING',
      rejectionReason: json['rejectionReason']?.toString(),
      requestedAt: json['requestedAt']?.toString() ?? '',
      processedAt: json['processedAt']?.toString(),
      processedBy: json['processedBy']?.toString(),
      recognized: json['recognized'] == true,
      existingEdgeNodeId: json['existingEdgeNodeId'] is int
          ? json['existingEdgeNodeId'] as int
          : int.tryParse(json['existingEdgeNodeId']?.toString() ?? ''),
      existingLifecycleState: json['existingLifecycleState']?.toString(),
      existingZoneId: json['existingZoneId'] is int
          ? json['existingZoneId'] as int
          : int.tryParse(json['existingZoneId']?.toString() ?? ''),
      existingZoneName: json['existingZoneName']?.toString(),
    );
  }
}

class CoreHealthDto {
  final String status;
  final bool masterEnabled;
  final bool databaseConnected;
  final bool telemetryIngestionActive;
  final int activeWebSocketSessions;
  final int recognizedNodesCount;
  final int onlineNodesCount;
  final int pendingPairingRequestsCount;
  final String timestamp;
  final JsonMap? details;

  const CoreHealthDto({
    required this.status,
    required this.masterEnabled,
    required this.databaseConnected,
    required this.telemetryIngestionActive,
    required this.activeWebSocketSessions,
    required this.recognizedNodesCount,
    required this.onlineNodesCount,
    required this.pendingPairingRequestsCount,
    required this.timestamp,
    this.details,
  });

  factory CoreHealthDto.fromJson(Object? json) {
    if (json is! JsonMap) {
      throw const FormatException('Expected a JSON object for CoreHealthDto.');
    }
    return CoreHealthDto(
      status: json['status']?.toString() ?? 'UP',
      masterEnabled: json['masterEnabled'] == true,
      databaseConnected: json['databaseConnected'] == true,
      telemetryIngestionActive: json['telemetryIngestionActive'] == true,
      activeWebSocketSessions: json['activeWebSocketSessions'] is int
          ? json['activeWebSocketSessions'] as int
          : int.tryParse(json['activeWebSocketSessions']?.toString() ?? '') ?? 0,
      recognizedNodesCount: json['recognizedNodesCount'] is int
          ? json['recognizedNodesCount'] as int
          : int.tryParse(json['recognizedNodesCount']?.toString() ?? '') ?? 0,
      onlineNodesCount: json['onlineNodesCount'] is int
          ? json['onlineNodesCount'] as int
          : int.tryParse(json['onlineNodesCount']?.toString() ?? '') ?? 0,
      pendingPairingRequestsCount: json['pendingPairingRequestsCount'] is int
          ? json['pendingPairingRequestsCount'] as int
          : int.tryParse(json['pendingPairingRequestsCount']?.toString() ?? '') ?? 0,
      timestamp: json['timestamp']?.toString() ?? '',
      details: json['details'] is JsonMap ? json['details'] as JsonMap : null,
    );
  }
}
