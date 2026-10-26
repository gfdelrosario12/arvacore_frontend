import 'node_telemetry_snapshot.dart';

/// Models the 6 standardized agricultural sensor categories for an ArvaNode.
///
/// Designed in accordance with ArvaCore physical and thesis specifications:
/// 1. Water Level Sensor (Ultrasonic distance in cm & calibrated water depth cm)
/// 2. Soil Moisture & Matric Potential Sensor (% volumetric & matric tension kPa)
/// 3. Ambient Temperature & Relative Humidity (°C & % RH)
/// 4. Leaf Wetness Sensor (Surface wetness index / duration)
/// 5. Soil Temperature & Chemical Property Probes (Soil temp °C, pH, EC mS/cm)
/// 6. Optical Chlorophyll / Leaf Color Sensor (SPAD index / LCC scale)
class NodeSensorCategories {
  final String nodeId;
  final String? zoneCode;
  final bool isOnline;
  final DateTime? lastSeen;

  // Category 1: Water Level
  final double? waterLevelCm;
  final double? waterLevelDistanceCm;
  final String? ultrasonicSensorHealth;

  // Category 2: Soil Moisture & Matric Potential
  final double? soilMoisturePercent;
  final double? matricPotentialKpa;
  final String? soilSensorHealth;

  // Category 3: Ambient Temperature & Relative Humidity
  final double? ambientTemperatureCelsius;
  final double? relativeHumidityPercent;

  // Category 4: Leaf Wetness Sensor
  final double? leafWetnessScore;
  final bool isLeafWetnessEquipped;

  // Category 5: Soil Temperature & Chemical Property Probes
  final double? soilTemperatureCelsius;
  final double? soilPh;
  final double? electricalConductivityEc;
  final bool isSoilChemicalEquipped;

  // Category 6: Optical Chlorophyll / Leaf Color Sensor
  final double? chlorophyllSpadIndex;
  final int? leafColorChartLevel;
  final bool isOpticalChlorophyllEquipped;

  // Power & Infrastructure
  final double? batteryVoltage;
  final int? batteryPercent;
  final String? telemetryStatus;

  const NodeSensorCategories({
    required this.nodeId,
    this.zoneCode,
    this.isOnline = false,
    this.lastSeen,
    this.waterLevelCm,
    this.waterLevelDistanceCm,
    this.ultrasonicSensorHealth,
    this.soilMoisturePercent,
    this.matricPotentialKpa,
    this.soilSensorHealth,
    this.ambientTemperatureCelsius,
    this.relativeHumidityPercent,
    this.leafWetnessScore,
    this.isLeafWetnessEquipped = false,
    this.soilTemperatureCelsius,
    this.soilPh,
    this.electricalConductivityEc,
    this.isSoilChemicalEquipped = false,
    this.chlorophyllSpadIndex,
    this.leafColorChartLevel,
    this.isOpticalChlorophyllEquipped = false,
    this.batteryVoltage,
    this.batteryPercent,
    this.telemetryStatus,
  });

  /// Factory from [NodeTelemetrySnapshot]
  factory NodeSensorCategories.fromSnapshot(NodeTelemetrySnapshot snapshot) {
    return NodeSensorCategories(
      nodeId: snapshot.nodeId,
      zoneCode: snapshot.monitoringZoneCode,
      isOnline: snapshot.isOnline,
      lastSeen: snapshot.lastTelemetryAt ?? snapshot.lastReceivedAt,
      waterLevelCm: snapshot.waterLevelCm,
      waterLevelDistanceCm: snapshot.waterLevelDistanceCm,
      ultrasonicSensorHealth: snapshot.ultrasonicSensorHealth,
      soilMoisturePercent: snapshot.soilMoisturePercent,
      matricPotentialKpa: null, // Physical ArvaNode standard build does not install tensiometer
      soilSensorHealth: snapshot.soilSensorHealth,
      ambientTemperatureCelsius: snapshot.temperatureCelsius,
      relativeHumidityPercent: snapshot.humidityPercent,
      leafWetnessScore: null,
      isLeafWetnessEquipped: false,
      soilTemperatureCelsius: null,
      soilPh: null,
      electricalConductivityEc: null,
      isSoilChemicalEquipped: false,
      chlorophyllSpadIndex: null,
      leafColorChartLevel: null,
      isOpticalChlorophyllEquipped: false,
      batteryVoltage: snapshot.batteryVoltage,
      batteryPercent: snapshot.batteryPercent,
      telemetryStatus: snapshot.telemetryStatus,
    );
  }
}

