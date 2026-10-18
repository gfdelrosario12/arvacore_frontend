import '../../../nodes/domain/models/esp32_node.dart';
import '../../../nodes/domain/models/monitoring_point.dart';
import '../../../nodes/domain/models/spatial_coordinates.dart';
import '../../../nodes/domain/models/transmission_config.dart';

enum ZoneStatus { optimal, warning, critical, offline }
enum TrendDirection { rising, falling, stable }

class ZoneTrendAnalysis {
  final TrendDirection direction;
  final double rateCmPerHour;
  final String label;

  const ZoneTrendAnalysis({
    required this.direction,
    required this.rateCmPerHour,
    required this.label,
  });

  factory ZoneTrendAnalysis.fromHistory(List<double> history) {
    if (history.length < 2) {
      return const ZoneTrendAnalysis(
        direction: TrendDirection.stable,
        rateCmPerHour: 0.0,
        label: 'Stable (0.0 cm/h)',
      );
    }
    final first = history.first;
    final last = history.last;
    final delta = last - first;
    final hours = (history.length - 1).toDouble();
    final rate = delta / (hours > 0 ? hours : 1.0);

    if (delta > 0.2) {
      return ZoneTrendAnalysis(
        direction: TrendDirection.rising,
        rateCmPerHour: rate,
        label: 'Rising (+${rate.toStringAsFixed(1)} cm/h)',
      );
    } else if (delta < -0.2) {
      return ZoneTrendAnalysis(
        direction: TrendDirection.falling,
        rateCmPerHour: rate,
        label: 'Falling (${rate.toStringAsFixed(1)} cm/h)',
      );
    } else {
      final sign = rate >= 0 ? '+' : '';
      return ZoneTrendAnalysis(
        direction: TrendDirection.stable,
        rateCmPerHour: rate,
        label: 'Stable ($sign${rate.toStringAsFixed(1)} cm/h)',
      );
    }
  }
}

/// Represents an agronomic or hydrological monitoring zone within a Field.
///
/// Strictly observational; does NOT contain independent pump or valve actuation controls.
class MonitoringZone {
  final String id;
  final String fieldId;
  final String code; // Dynamic alphanumeric code e.g. "Z1", "Z2", "Q1", "North"
  final String name;
  final double spatialWeight; // Area weight (0.0 .. 1.0) for field aggregation
  final double soilMoisturePercent;
  final double waterLevelCm;
  final double temperatureCelsius;
  final double humidityPercent;
  final int batteryPercent;
  final ZoneStatus status;
  final DateTime lastUpdated;
  final bool isOnline;
  final int rssiDbm;
  final double snrDb;
  final String hardwareModel;
  final String firmwareVersion;
  final List<double> waterLevelHistory;
  final List<double> waterLevelHistory24h;
  final List<double> waterLevelHistory7d;
  final List<String> assignedNodeIds;
  final List<String> monitoringPointIds;
  final SpatialCoordinates? coordinates;
  final TransmissionConfig? transmissionConfig;
  final double? waterLevelDistanceCm;
  final double? calibratedBottomOffsetCm;
  final String areaType; // 'QUARTER', 'SECTION', 'RANGE', 'IRRIGATION_ZONE', 'CUSTOM'
  final String? cropType;
  final double? lengthMeters;
  final double? widthMeters;
  final double? areaSize;
  final String areaUnit;
  final double relativeX;
  final double relativeY;
  final double relativeWidth;
  final double relativeHeight;
  final String operationalStatus;
  final bool isArchived;

  const MonitoringZone({
    required this.id,
    this.fieldId = 'field-01',
    required this.code,
    required this.name,
    this.spatialWeight = 0.25,
    required this.soilMoisturePercent,
    required this.waterLevelCm,
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.batteryPercent,
    required this.status,
    required this.lastUpdated,
    this.isOnline = true,
    this.rssiDbm = -85,
    this.snrDb = 9.2,
    this.hardwareModel = 'ArvaNode LoRa Node v2',
    this.firmwareVersion = 'v1.4.2',
    this.waterLevelHistory = const [4.5, 4.8, 5.0, 5.2, 5.1],
    this.waterLevelHistory24h = const [4.2, 4.5, 4.8, 5.0, 5.2],
    this.waterLevelHistory7d = const [3.5, 4.0, 4.5, 4.8, 5.2],
    this.assignedNodeIds = const [],
    this.monitoringPointIds = const [],
    this.coordinates,
    this.transmissionConfig,
    this.waterLevelDistanceCm,
    this.calibratedBottomOffsetCm = 101.6,
    this.areaType = 'QUARTER',
    this.cropType = 'Rice - Inbred NSIC Rc222',
    this.lengthMeters,
    this.widthMeters,
    this.areaSize,
    this.areaUnit = 'hectares',
    this.relativeX = 0.0,
    this.relativeY = 0.0,
    this.relativeWidth = 1.0,
    this.relativeHeight = 1.0,
    this.operationalStatus = 'READY',
    this.isArchived = false,
  });

  /// Legacy adapter creating a MonitoringZone view from a decoupled MonitoringPoint and its mounted Esp32Node.
  factory MonitoringZone.fromPointAndNode({
    required MonitoringPoint point,
    Esp32Node? node,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final isOnline = node?.isOnline ?? false;
    final waterLevel = node?.waterLevelCm ?? 0.0;
    final soilMoisture = node?.soilMoisturePercent ?? 0.0;

    ZoneStatus status = ZoneStatus.optimal;
    if (!isOnline) {
      status = ZoneStatus.offline;
    } else if (waterLevel < -10.0 || soilMoisture < 20.0) {
      status = ZoneStatus.critical;
    } else if (waterLevel < -5.0 || soilMoisture < 35.0) {
      status = ZoneStatus.warning;
    }

    return MonitoringZone(
      id: point.id,
      fieldId: point.fieldId,
      code: point.code,
      name: point.label,
      soilMoisturePercent: soilMoisture,
      waterLevelCm: waterLevel,
      waterLevelDistanceCm: node?.waterLevelDistanceCm,
      temperatureCelsius: node?.temperatureCelsius ?? 28.0,
      humidityPercent: node?.humidityPercent ?? 75.0,
      batteryPercent: node?.batteryPercent ?? 100,
      status: status,
      lastUpdated: node?.lastSeen ?? now,
      isOnline: isOnline,
      rssiDbm: node?.rssiDbm ?? -85,
      snrDb: node?.snrDb ?? 9.0,
      hardwareModel: node?.hardwareRevision ?? 'ArvaNode',
      firmwareVersion: node?.firmwareVersion ?? '1.0.0',
      assignedNodeIds: node != null ? [node.id] : const [],
      monitoringPointIds: [point.id],
      coordinates: point.coordinates ?? node?.coordinates,
      transmissionConfig: node?.transmissionConfig,
    );
  }

  ZoneTrendAnalysis get trendAnalysis =>
      ZoneTrendAnalysis.fromHistory(waterLevelHistory);

  ZoneTrendAnalysis trendAnalysisFor(List<double> history) =>
      ZoneTrendAnalysis.fromHistory(history);

  MonitoringZone copyWith({
    String? id,
    String? fieldId,
    String? code,
    String? name,
    double? spatialWeight,
    double? soilMoisturePercent,
    double? waterLevelCm,
    double? waterLevelDistanceCm,
    double? calibratedBottomOffsetCm,
    double? temperatureCelsius,
    double? humidityPercent,
    int? batteryPercent,
    ZoneStatus? status,
    DateTime? lastUpdated,
    bool? isOnline,
    int? rssiDbm,
    double? snrDb,
    String? hardwareModel,
    String? firmwareVersion,
    List<double>? waterLevelHistory,
    List<double>? waterLevelHistory24h,
    List<double>? waterLevelHistory7d,
    List<String>? assignedNodeIds,
    List<String>? monitoringPointIds,
    SpatialCoordinates? coordinates,
    TransmissionConfig? transmissionConfig,
    String? areaType,
    String? cropType,
    double? lengthMeters,
    double? widthMeters,
    double? areaSize,
    String? areaUnit,
    double? relativeX,
    double? relativeY,
    double? relativeWidth,
    double? relativeHeight,
    String? operationalStatus,
    bool? isArchived,
  }) {
    return MonitoringZone(
      id: id ?? this.id,
      fieldId: fieldId ?? this.fieldId,
      code: code ?? this.code,
      name: name ?? this.name,
      spatialWeight: spatialWeight ?? this.spatialWeight,
      soilMoisturePercent: soilMoisturePercent ?? this.soilMoisturePercent,
      waterLevelCm: waterLevelCm ?? this.waterLevelCm,
      waterLevelDistanceCm: waterLevelDistanceCm ?? this.waterLevelDistanceCm,
      calibratedBottomOffsetCm: calibratedBottomOffsetCm ?? this.calibratedBottomOffsetCm,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isOnline: isOnline ?? this.isOnline,
      rssiDbm: rssiDbm ?? this.rssiDbm,
      snrDb: snrDb ?? this.snrDb,
      hardwareModel: hardwareModel ?? this.hardwareModel,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      waterLevelHistory: waterLevelHistory ?? this.waterLevelHistory,
      waterLevelHistory24h: waterLevelHistory24h ?? this.waterLevelHistory24h,
      waterLevelHistory7d: waterLevelHistory7d ?? this.waterLevelHistory7d,
      assignedNodeIds: assignedNodeIds ?? this.assignedNodeIds,
      monitoringPointIds: monitoringPointIds ?? this.monitoringPointIds,
      coordinates: coordinates ?? this.coordinates,
      transmissionConfig: transmissionConfig ?? this.transmissionConfig,
      areaType: areaType ?? this.areaType,
      cropType: cropType ?? this.cropType,
      lengthMeters: lengthMeters ?? this.lengthMeters,
      widthMeters: widthMeters ?? this.widthMeters,
      areaSize: areaSize ?? this.areaSize,
      areaUnit: areaUnit ?? this.areaUnit,
      relativeX: relativeX ?? this.relativeX,
      relativeY: relativeY ?? this.relativeY,
      relativeWidth: relativeWidth ?? this.relativeWidth,
      relativeHeight: relativeHeight ?? this.relativeHeight,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  factory MonitoringZone.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return MonitoringZone(
      id: json['id']?.toString() ?? '',
      fieldId: json['fieldId']?.toString() ?? 'field-01',
      code: json['code'] as String? ?? 'Z',
      name: json['name'] as String? ?? 'Zone',
      cropType: json['cropType'] as String? ?? 'Rice',
      areaType: json['areaType'] as String? ?? 'QUARTER',
      lengthMeters: (json['lengthMeters'] as num?)?.toDouble() ?? (json['length_meters'] as num?)?.toDouble(),
      widthMeters: (json['widthMeters'] as num?)?.toDouble() ?? (json['width_meters'] as num?)?.toDouble(),
      areaSize: (json['areaSize'] as num?)?.toDouble() ?? (json['area_size'] as num?)?.toDouble(),
      areaUnit: json['areaUnit'] as String? ?? json['area_unit'] as String? ?? 'hectares',
      relativeX: (json['relativeX'] as num?)?.toDouble() ?? (json['relative_x'] as num?)?.toDouble() ?? 0.0,
      relativeY: (json['relativeY'] as num?)?.toDouble() ?? (json['relative_y'] as num?)?.toDouble() ?? 0.0,
      relativeWidth: (json['relativeWidth'] as num?)?.toDouble() ?? (json['relative_width'] as num?)?.toDouble() ?? 1.0,
      relativeHeight: (json['relativeHeight'] as num?)?.toDouble() ?? (json['relative_height'] as num?)?.toDouble() ?? 1.0,
      operationalStatus: json['operationalStatus'] as String? ?? json['operational_status'] as String? ?? 'READY',
      isArchived: json['isArchived'] == true || json['is_archived'] == true,
      soilMoisturePercent: (json['soilMoisturePercent'] as num?)?.toDouble() ?? (json['targetMoisturePercentage'] as num?)?.toDouble() ?? 50.0,
      waterLevelCm: (json['waterLevelCm'] as num?)?.toDouble() ?? 3.0,
      temperatureCelsius: 28.0,
      humidityPercent: 75.0,
      batteryPercent: 95,
      status: ZoneStatus.optimal,
      lastUpdated: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) ?? now : now,
      assignedNodeIds: (json['assignedNodeIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fieldId': fieldId,
    'code': code,
    'name': name,
    'areaType': areaType,
    'cropType': cropType,
    'lengthMeters': lengthMeters,
    'widthMeters': widthMeters,
    'areaSize': areaSize,
    'areaUnit': areaUnit,
    'relativeX': relativeX,
    'relativeY': relativeY,
    'relativeWidth': relativeWidth,
    'relativeHeight': relativeHeight,
    'operationalStatus': operationalStatus,
    'isArchived': isArchived,
    'assignedNodeIds': assignedNodeIds,
  };
}