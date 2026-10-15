import 'dart:convert';
import '../../features/audit/domain/models/account_audit_event.dart';
import '../../features/audit/domain/models/audit_actor.dart';
import '../../features/audit/domain/models/audit_category.dart';
import '../../features/audit/domain/models/audit_metadata.dart';
import '../../features/audit/domain/models/audit_result.dart';
import '../../features/audit/domain/models/audit_target.dart';
import '../../features/control/domain/models/central_control_telemetry.dart';
import '../../features/control/domain/models/control_command_result.dart';
import '../../features/control/domain/models/control_enums.dart';
import '../../features/auth/domain/models/auth_token.dart';
import '../../features/auth/domain/models/user_session.dart';
import '../../features/field/domain/models/models.dart';
import '../../features/irrigation/domain/models/auto_irrigation_config.dart';
import '../../features/irrigation/domain/models/auto_irrigation_status.dart';
import '../../features/irrigation/domain/models/irrigation_execution_audit_log.dart';
import '../../features/nodes/domain/models/models.dart';
import '../../features/zones/domain/models/monitoring_zone.dart';
import 'api_dtos.dart';

class ApiMappers {
  static Field field(FieldDto dto) {
    return Field(
      id: dto.id,
      name: dto.name,
      description: dto.description,
      areaSquareMeters: dto.areaSquareMeters,
      soilType: dto.soilType,
      activeCropStage: _enumValue(
        CropStage.values,
        dto.activeCropStage,
        CropStage.vegetativeTillering,
      ),
      awdProfileId: dto.awdProfileId,
      centralControllerId: dto.centralControllerId,
      boundaryCoordinates: dto.boundaryCoordinates,
      createdAt: _date(dto.createdAt) ?? DateTime.now(),
      updatedAt: _date(dto.updatedAt) ?? DateTime.now(),
    );
  }

  static FieldDto fieldDto(Field domain) {
    return FieldDto(
      id: domain.id,
      name: domain.name,
      description: domain.description,
      areaSquareMeters: domain.areaSquareMeters,
      soilType: domain.soilType,
      activeCropStage: domain.activeCropStage.name,
      awdProfileId: domain.awdProfileId,
      centralControllerId: domain.centralControllerId,
      boundaryCoordinates: domain.boundaryCoordinates,
      createdAt: domain.createdAt.toIso8601String(),
      updatedAt: domain.updatedAt.toIso8601String(),
    );
  }

  static MonitoringPoint monitoringPoint(MonitoringPointDto dto) {
    return MonitoringPoint(
      id: dto.id,
      fieldId: dto.fieldId,
      zoneId: dto.zoneId,
      code: dto.code,
      label: dto.label,
      coordinates: (dto.latitude != null || dto.localX != null)
          ? SpatialCoordinates(
              latitude: dto.latitude,
              longitude: dto.longitude,
              localX: dto.localX,
              localY: dto.localY,
              elevationMeters: dto.elevationMeters,
            )
          : null,
      relativeElevationCm: dto.relativeElevationCm,
      tubeDatumOffsetCm: dto.tubeDatumOffsetCm,
      assignedNodeId: dto.assignedNodeId,
      isActive: dto.isActive,
    );
  }

  static MonitoringPointDto monitoringPointDto(MonitoringPoint domain) {
    return MonitoringPointDto(
      id: domain.id,
      fieldId: domain.fieldId,
      zoneId: domain.zoneId,
      code: domain.code,
      label: domain.label,
      latitude: domain.coordinates?.latitude,
      longitude: domain.coordinates?.longitude,
      localX: domain.coordinates?.localX,
      localY: domain.coordinates?.localY,
      elevationMeters: domain.coordinates?.elevationMeters,
      relativeElevationCm: domain.relativeElevationCm,
      tubeDatumOffsetCm: domain.tubeDatumOffsetCm,
      assignedNodeId: domain.assignedNodeId,
      isActive: domain.isActive,
    );
  }

  static Sensor sensor(SensorDto dto) {
    return Sensor(
      id: dto.id,
      nodeId: dto.nodeId,
      type: _enumValue(SensorType.values, dto.type, SensorType.waterLevelTube),
      channelIndex: dto.channelIndex,
      unit: dto.unit,
      depthOffsetCm: dto.depthOffsetCm,
      calibrationCoefficients: dto.calibrationCoefficients,
      latestMeasurement: dto.latestMeasurement != null
          ? measurement(dto.latestMeasurement!)
          : null,
      isActive: dto.isActive,
    );
  }

  static SensorDto sensorDto(Sensor domain) {
    return SensorDto(
      id: domain.id,
      nodeId: domain.nodeId,
      type: domain.type.name,
      channelIndex: domain.channelIndex,
      unit: domain.unit,
      depthOffsetCm: domain.depthOffsetCm,
      calibrationCoefficients: domain.calibrationCoefficients,
      latestMeasurement: domain.latestMeasurement != null
          ? measurementDto(domain.latestMeasurement!)
          : null,
      isActive: domain.isActive,
    );
  }

  static Measurement measurement(MeasurementDto dto) {
    return Measurement(
      id: dto.id,
      timestamp: _date(dto.timestamp) ?? DateTime.now(),
      sensorId: dto.sensorId,
      pointId: dto.pointId,
      rawValue: dto.rawValue,
      calibratedValue: dto.calibratedValue,
      qualityFlag: _enumValue(
        MeasurementQuality.values,
        dto.qualityFlag,
        MeasurementQuality.valid,
      ),
    );
  }

  static MeasurementDto measurementDto(Measurement domain) {
    return MeasurementDto(
      id: domain.id,
      timestamp: domain.timestamp.toIso8601String(),
      sensorId: domain.sensorId,
      pointId: domain.pointId,
      rawValue: domain.rawValue,
      calibratedValue: domain.calibratedValue,
      qualityFlag: domain.qualityFlag.name,
    );
  }

  static Esp32Node esp32Node(ResourceDto dto) {
    final data = dto.data;
    return Esp32Node(
      id: dto.id ?? _string(data['id'], fallback: 'unknown-node'),
      macAddress: _string(data['macAddress'], fallback: '00:00:00:00:00:00'),
      displayName: _string(data['displayName'] ?? data['name'], fallback: 'ESP32 Node'),
      assignedFieldId: data['assignedFieldId']?.toString(),
      assignedZoneId: data['assignedZoneId']?.toString(),
      assignedPointId: data['assignedPointId']?.toString(),
      coordinates: spatialCoordinates(data['coordinates'] ?? data),
      transmissionConfig: transmissionConfig(data['transmissionConfig'] ?? data),
      isOnline: data['isOnline'] as bool? ?? false,
      lifecycleState: _enumValue(
        NodeLifecycleStatus.values,
        data['lifecycleState'] ?? data['lifecycleStatus'],
        NodeLifecycleStatus.active,
      ),
      commissioningToken: data['commissioningToken']?.toString(),
      replacedByNodeId: data['replacedByNodeId']?.toString(),
      replacesNodeId: data['replacesNodeId']?.toString(),
      replacedAt: _date(data['replacedAt']),
      commissionedAt: _date(data['commissionedAt']),
      hardwareRevision: _string(data['hardwareRevision'], fallback: 'v2.1'),
      firmwareVersion: _string(data['firmwareVersion'], fallback: '1.0.0'),
      batteryPercent: _intNullable(data['batteryPercent']),
      batteryVoltage: _doubleNullable(data['batteryVoltage']),
      rssiDbm: _intNullable(data['rssiDbm']),
      snrDb: _doubleNullable(data['snrDb']),
      lastSeen: _date(data['lastSeen']) ?? DateTime.now(),
      soilMoisturePercent: _doubleNullable(data['soilMoisturePercent'] ?? data['soilMoisture']),
      waterLevelCm: _doubleNullable(data['waterLevelCm'] ?? data['waterLevel']),
      temperatureCelsius: _doubleNullable(data['temperatureCelsius'] ?? data['temperature']),
      humidityPercent: _doubleNullable(data['humidityPercent'] ?? data['humidity']),
    );
  }

  static Esp32Node esp32NodeFromDto(Esp32NodeDto dto) {
    return Esp32Node(
      id: dto.id,
      macAddress: dto.macAddress,
      displayName: dto.displayName,
      assignedFieldId: dto.assignedFieldId,
      assignedZoneId: dto.assignedZoneId,
      coordinates: (dto.latitude != null || dto.localX != null)
          ? SpatialCoordinates(
              latitude: dto.latitude,
              longitude: dto.longitude,
              localX: dto.localX,
              localY: dto.localY,
            )
          : null,
      transmissionConfig: TransmissionConfig(
        intervalSeconds: dto.transmissionIntervalSeconds,
        isAdaptive: dto.isAdaptive,
        adaptiveReason: dto.adaptiveReason,
      ),
      isOnline: dto.isOnline,
      lifecycleState: _enumValue(
        NodeLifecycleStatus.values,
        dto.lifecycleState,
        NodeLifecycleStatus.active,
      ),
      commissioningToken: dto.commissioningToken,
      replacedByNodeId: dto.replacedByNodeId,
      replacesNodeId: dto.replacesNodeId,
      replacedAt: _date(dto.replacedAt),
      commissionedAt: _date(dto.commissionedAt),
      batteryPercent: dto.batteryPercent,
      batteryVoltage: dto.batteryVoltage,
      rssiDbm: dto.rssiDbm,
      snrDb: dto.snrDb,
      lastSeen: _date(dto.lastSeen) ?? DateTime.now(),
      soilMoisturePercent: _doubleNullable(dto.latestTelemetry?['soilMoisturePercent']),
      waterLevelCm: _doubleNullable(dto.latestTelemetry?['waterLevelCm']),
      temperatureCelsius: _doubleNullable(dto.latestTelemetry?['temperatureCelsius']),
      humidityPercent: _doubleNullable(dto.latestTelemetry?['humidityPercent']),
    );
  }

  static NodeReplacementResult nodeReplacementResult(NodeReplacementResultDto dto) {
    return NodeReplacementResult(
      oldNodeId: dto.oldNodeId,
      replacementNodeId: dto.replacementNodeId,
      fieldId: dto.fieldId,
      zoneId: dto.zoneId,
      monitoringPointId: dto.monitoringPointId,
      replacedAt: _date(dto.replacedAt) ?? DateTime.now(),
      reason: dto.reason,
      historicalMeasurementsPreserved: dto.historicalMeasurementsPreserved,
      updatedReplacementNode: esp32NodeFromDto(dto.updatedReplacementNode),
      retiredNode: esp32NodeFromDto(dto.retiredNode),
    );
  }

  static SpatialCoordinates spatialCoordinates(Object? raw) {
    if (raw is! Map) return const SpatialCoordinates();
    final map = Map<String, dynamic>.from(raw);
    return SpatialCoordinates(
      latitude: _doubleNullable(map['latitude']),
      longitude: _doubleNullable(map['longitude']),
      localX: _doubleNullable(map['localX']),
      localY: _doubleNullable(map['localY']),
      elevationMeters: _doubleNullable(map['elevationMeters']),
    );
  }

  static TransmissionConfig transmissionConfig(Object? raw) {
    if (raw is! Map) {
      return TransmissionConfig(
        intervalSeconds: 300,
        isAdaptive: false,
        lastConfiguredAt: DateTime.now(),
      );
    }
    final map = Map<String, dynamic>.from(raw);
    return TransmissionConfig(
      intervalSeconds: _int(map['intervalSeconds'] ?? map['transmissionIntervalSeconds'], fallback: 300),
      isAdaptive: map['isAdaptive'] as bool? ?? false,
      adaptiveReason: map['adaptiveReason']?.toString() ?? map['reason']?.toString(),
      lastConfiguredAt: _date(map['lastConfiguredAt']) ?? DateTime.now(),
    );
  }

  static NodeDiscoveryInfo nodeDiscoveryInfo(ResourceDto dto) {
    final data = dto.data;
    return NodeDiscoveryInfo(
      id: dto.id ?? _string(data['id'], fallback: 'disc-node'),
      macAddress: _string(data['macAddress'], fallback: '00:00:00:00:00:00'),
      hardwareModel: _string(data['hardwareModel'], fallback: 'ESP32 LoRa Node'),
      firmwareVersion: _string(data['firmwareVersion'], fallback: '1.0.0'),
      rssiDbm: _int(data['rssiDbm'], fallback: -85),
      detectedAt: _date(data['detectedAt']) ?? DateTime.now(),
    );
  }
  static UserSession userSession(AuthResponseDto dto) {
    var user = Map<String, dynamic>.from(dto.user);

    // If user map has missing username or role, extract claims from accessToken
    if (!user.containsKey('username') || !user.containsKey('role')) {
      try {
        final parts = dto.accessToken.split('.');
        if (parts.length >= 2) {
          var padded = parts[1];
          final remainder = padded.length % 4;
          if (remainder != 0) {
            padded = padded.padRight(padded.length + (4 - remainder), '=');
          }
          final decoded = String.fromCharCodes(base64Url.decode(padded));
          final payload = jsonDecode(decoded) as Map<String, dynamic>;
          user['username'] ??= payload['sub'] ?? payload['username'];
          user['role'] ??= payload['role'] ?? payload['user_role'];
          user['id'] ??= payload['userId'] ?? payload['id'];
        }
      } catch (_) {}
    }

    final rawToken = AuthToken(
      accessToken: dto.accessToken,
      refreshToken: dto.refreshToken ?? '',
      expiresAt: _date(user['expiresAt']) ??
          DateTime.now().add(const Duration(hours: 24)),
    );

    final enrichedToken = AuthToken.withClaimsFromJwt(rawToken);

    return UserSession(
      userId: _string(user['id'] ?? user['userId'], fallback: '1'),
      username: _string(user['username'], fallback: 'admin'),
      email: _string(user['email'], fallback: ''),
      role: _string(user['role'], fallback: 'ROLE_ADMIN'),
      token: enrichedToken,
    );
  }

  static AuthToken token(AuthResponseDto dto) {
    final rawToken = AuthToken(
      accessToken: dto.accessToken,
      refreshToken: dto.refreshToken ?? '',
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );
    return AuthToken.withClaimsFromJwt(rawToken);
  }

  static MonitoringZone monitoringZone(ResourceDto dto) {
    final data = dto.data;
    final history = _doubles(data['waterLevelHistory']);
    return MonitoringZone(
      id: dto.id ?? _string(data['id'], fallback: 'unknown'),
      code: _string(data['code'] ?? data['quarter'], fallback: 'Q1'),
      name: _string(data['name'], fallback: 'Monitoring Quarter'),
      soilMoisturePercent: _double(data['soilMoisturePercent'] ?? data['soilMoisture']),
      waterLevelCm: _double(data['waterLevelCm'] ?? data['waterLevel']),
      temperatureCelsius: _double(data['temperatureCelsius'] ?? data['temperature']),
      humidityPercent: _double(data['humidityPercent'] ?? data['humidity']),
      batteryPercent: _int(data['batteryPercent'] ?? data['battery']),
      status: _zoneStatus(data['status']),
      lastUpdated: _date(data['lastUpdated'] ?? data['updatedAt']) ?? DateTime.now(),
      isOnline: data['isOnline'] as bool? ?? true,
      rssiDbm: _int(data['rssiDbm'] ?? data['rssi'], fallback: -85),
      snrDb: _double(data['snrDb'] ?? data['snr'], fallback: 0),
      hardwareModel: _string(data['hardwareModel'], fallback: 'ArvaNode LoRa Node'),
      firmwareVersion: _string(data['firmwareVersion'], fallback: 'Unknown'),
      waterLevelHistory: history.isEmpty ? const [0] : history,
      waterLevelHistory24h: _doubles(data['waterLevelHistory24h']),
      waterLevelHistory7d: _doubles(data['waterLevelHistory7d']),
      assignedNodeIds: _strings(data['assignedNodeIds'] ?? data['nodeIds']),
      coordinates: spatialCoordinates(data['coordinates'] ?? data),
      transmissionConfig: data['transmissionConfig'] != null ||
              data['transmissionIntervalSeconds'] != null
          ? transmissionConfig(data['transmissionConfig'] ?? data)
          : null,
    );
  }

  static CentralControlTelemetry centralTelemetry(ResourceDto dto) {
    final data = dto.data;
    return CentralControlTelemetry(
      controllerId: dto.id ?? _string(data['controllerId'], fallback: 'CTRL-FIELD'),
      controllerState: _enumValue(
        CentralControllerState.values,
        data['controllerState'],
        CentralControllerState.offline,
      ),
      pumpStatus: _enumValue(PumpStatus.values, data['pumpStatus'], PumpStatus.off),
      valveStatus: _enumValue(
        MainValveStatus.values,
        data['valveStatus'],
        MainValveStatus.closed,
      ),
      irrigationState: _enumValue(
        IrrigationState.values,
        data['irrigationState'],
        IrrigationState.idle,
      ),
      startTime: _date(data['startTime']),
      durationMinutes: _intNullable(data['durationMinutes']),
      flowRateLitersPerMin: _double(data['flowRateLitersPerMin']),
      linePressureBar: _double(data['linePressureBar']),
      lastUpdated: _date(data['lastUpdated'] ?? data['updatedAt']) ?? DateTime.now(),
      target: _string(data['target'], fallback: CentralControlTelemetry.fixedTarget),
      isStale: data['isStale'] as bool? ?? false,
    );
  }

  static ControlCommandResult commandResult(
    ResourceDto dto,
    CommandType type,
  ) {
    final data = dto.data;
    return ControlCommandResult(
      commandId: dto.id ?? _string(data['commandId'], fallback: 'API-COMMAND'),
      type: type,
      outcome: _enumValue(CommandOutcome.values, data['outcome'], CommandOutcome.failed),
      message: _string(data['message'], fallback: 'Command response received.'),
      timestamp: _date(data['timestamp']) ?? DateTime.now(),
    );
  }

  static AutoIrrigationConfig autoIrrigationConfig(AutoIrrigationConfigDto dto) {
    return AutoIrrigationConfig(
      systemId: dto.systemId,
      isEnabled: dto.isEnabled,
      maxDurationMinutes: dto.maxDurationMinutes,
      minCooldownMinutes: dto.minCooldownMinutes,
      allowedHoursStart: dto.allowedHoursStart,
      allowedHoursEnd: dto.allowedHoursEnd,
      targetFloodDepthCm: dto.targetFloodDepthCm,
      rainDelayEnabled: dto.rainDelayEnabled,
      rainDelayHours: dto.rainDelayHours,
      minConfidenceThreshold: dto.minConfidenceThreshold,
      updatedAt: _date(dto.updatedAt),
      updatedBy: dto.updatedBy,
    );
  }

  static AutoIrrigationConfigDto autoIrrigationConfigDto(
      AutoIrrigationConfig domain) {
    return AutoIrrigationConfigDto(
      systemId: domain.systemId,
      isEnabled: domain.isEnabled,
      maxDurationMinutes: domain.maxDurationMinutes,
      minCooldownMinutes: domain.minCooldownMinutes,
      allowedHoursStart: domain.allowedHoursStart,
      allowedHoursEnd: domain.allowedHoursEnd,
      targetFloodDepthCm: domain.targetFloodDepthCm,
      rainDelayEnabled: domain.rainDelayEnabled,
      rainDelayHours: domain.rainDelayHours,
      minConfidenceThreshold: domain.minConfidenceThreshold,
      updatedAt: domain.updatedAt?.toIso8601String(),
      updatedBy: domain.updatedBy,
    );
  }

  static AutoIrrigationStatus autoIrrigationStatus(AutoIrrigationStatusDto dto) {
    return AutoIrrigationStatus(
      systemId: dto.systemId,
      state: _enumValue(
        AutoIrrigationState.values,
        dto.state,
        AutoIrrigationState.disabled,
      ),
      activeCommandId: dto.activeCommandId,
      startedAt: _date(dto.startedAt),
      targetDurationMinutes: dto.targetDurationMinutes,
      cooldownUntil: _date(dto.cooldownUntil),
      lastEvaluationTime: _date(dto.lastEvaluationTime),
      lastEvaluationResult: dto.lastEvaluationResult,
      lockoutReason: dto.lockoutReason,
      lockoutTimestamp: _date(dto.lockoutTimestamp),
      inhibitionReasons: dto.inhibitionReasons,
    );
  }

  static AutoIrrigationStatusDto autoIrrigationStatusDto(
      AutoIrrigationStatus domain) {
    return AutoIrrigationStatusDto(
      systemId: domain.systemId,
      state: domain.state.name,
      activeCommandId: domain.activeCommandId,
      startedAt: domain.startedAt?.toIso8601String(),
      targetDurationMinutes: domain.targetDurationMinutes,
      cooldownUntil: domain.cooldownUntil?.toIso8601String(),
      lastEvaluationTime: domain.lastEvaluationTime?.toIso8601String(),
      lastEvaluationResult: domain.lastEvaluationResult,
      lockoutReason: domain.lockoutReason,
      lockoutTimestamp: domain.lockoutTimestamp?.toIso8601String(),
      inhibitionReasons: domain.inhibitionReasons,
    );
  }

  static IrrigationActor irrigationActor(IrrigationActorDto dto) {
    return IrrigationActor(
      type: _enumValue(
        IrrigationActorType.values,
        dto.type,
        IrrigationActorType.system,
      ),
      id: dto.id,
      displayName: dto.displayName,
    );
  }

  static IrrigationActorDto irrigationActorDto(IrrigationActor domain) {
    return IrrigationActorDto(
      type: domain.type.name,
      id: domain.id,
      displayName: domain.displayName,
    );
  }

  static IrrigationExecutionAuditLog irrigationExecutionAuditLog(
      IrrigationExecutionAuditLogDto dto) {
    return IrrigationExecutionAuditLog(
      id: dto.id,
      systemId: dto.systemId,
      actor: irrigationActor(dto.actor),
      action: dto.action,
      triggerContext: dto.triggerContext,
      triggeringDepthCm: dto.triggeringDepthCm,
      telemetryConfidenceScore: dto.telemetryConfidenceScore,
      cropStage: dto.cropStage,
      targetDurationMinutes: dto.targetDurationMinutes,
      actualDurationMinutes: dto.actualDurationMinutes,
      outcome: dto.outcome,
      timestamp: _date(dto.timestamp) ?? DateTime.now(),
      failureReason: dto.failureReason,
    );
  }

  static IrrigationExecutionAuditLogDto irrigationExecutionAuditLogDto(
      IrrigationExecutionAuditLog domain) {
    return IrrigationExecutionAuditLogDto(
      id: domain.id,
      systemId: domain.systemId,
      actor: irrigationActorDto(domain.actor),
      action: domain.action,
      triggerContext: domain.triggerContext,
      triggeringDepthCm: domain.triggeringDepthCm,
      telemetryConfidenceScore: domain.telemetryConfidenceScore,
      cropStage: domain.cropStage,
      targetDurationMinutes: domain.targetDurationMinutes,
      actualDurationMinutes: domain.actualDurationMinutes,
      outcome: domain.outcome,
      timestamp: domain.timestamp.toIso8601String(),
      failureReason: domain.failureReason,
    );
  }

  static AuditActor auditActor(AuditActorDto dto) {
    return AuditActor.fromJson(dto.toJson());
  }

  static AuditActorDto auditActorDto(AuditActor domain) {
    return AuditActorDto.fromJson(domain.toJson());
  }

  static AuditCategory auditCategory(String categoryStr) {
    return AuditCategory.fromJson(categoryStr);
  }

  static AuditResult auditResult(String resultStr) {
    return AuditResult.fromJson(resultStr);
  }

  static AuditTarget auditTarget(AuditTargetDto dto) {
    return AuditTarget.fromJson(dto.toJson());
  }

  static AuditTargetDto auditTargetDto(AuditTarget domain) {
    return AuditTargetDto.fromJson(domain.toJson());
  }

  static AuditMetadata auditMetadata(AuditMetadataDto dto) {
    return AuditMetadata.fromJson(dto.toJson());
  }

  static AuditMetadataDto auditMetadataDto(AuditMetadata domain) {
    return AuditMetadataDto.fromJson(domain.toJson());
  }

  static AccountAuditEvent accountAuditEvent(AccountAuditEventDto dto) {
    return AccountAuditEvent.fromJson(dto.toJson());
  }

  static AccountAuditEventDto accountAuditEventDto(AccountAuditEvent domain) {
    return AccountAuditEventDto.fromJson(domain.toJson());
  }

  static String _string(Object? value, {required String fallback}) =>
      value?.toString() ?? fallback;

  static int _int(Object? value, {int fallback = 0}) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;

  static int? _intNullable(Object? value) =>
      value == null ? null : int.tryParse(value.toString());

  static double _double(Object? value, {double fallback = 0}) =>
      double.tryParse(value?.toString() ?? '') ?? fallback;

  static double? _doubleNullable(Object? value) =>
      value == null ? null : double.tryParse(value.toString());

  static List<double> _doubles(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => _double(item)).toList(growable: false);
  }

  static List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime? parseIsoDateTime(Object? value) => _date(value);

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty) return null;
    final parsed = DateTime.tryParse(str);
    if (parsed != null) return parsed;
    // Nanosecond timestamps (more than 6 digits after decimal point) fail DateTime.tryParse
    final dotIndex = str.indexOf('.');
    if (dotIndex != -1) {
      // Find where timezone offset or 'Z' begins, or end of string
      final zOrPlusOrMinus = str.indexOf(RegExp(r'[Z+-]'), dotIndex);
      final fracEnd = zOrPlusOrMinus != -1 ? zOrPlusOrMinus : str.length;
      final fracLength = fracEnd - (dotIndex + 1);
      if (fracLength > 6) {
        // Truncate fractional seconds to 6 digits (microseconds)
        final truncatedStr = str.substring(0, dotIndex + 7) + (zOrPlusOrMinus != -1 ? str.substring(zOrPlusOrMinus) : '');
        return DateTime.tryParse(truncatedStr);
      }
    }
    return null;
  }

  static ZoneStatus _zoneStatus(Object? value) => _enumValue(
        ZoneStatus.values,
        value,
        ZoneStatus.offline,
      );

  static T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
    final name = raw?.toString().split('.').last;
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => fallback,
    );
  }
}
