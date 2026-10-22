import '../../../awd/domain/models/awd_automation_eligibility.dart';
import '../../../awd/domain/models/awd_confidence.dart';
import '../../../irrigation/domain/models/centralized_irrigation.dart';
import '../../../nodes/domain/models/esp32_node.dart';
import '../../../zones/domain/models/monitoring_zone.dart';
import 'field_alert.dart';
import 'field_recommendation.dart';

enum FieldConditionStatus { optimal, refluxNeeded, flooded, criticallyDry }

class FieldDashboardSummary {
  final FieldConditionStatus overallCondition;
  final String overallConditionLabel;
  final String awdStatusLabel;
  final bool requiresIrrigation;
  final bool isIrrigationRunning;
  final String recommendedActionText;
  final String? highestMoistureZoneCode;
  final String? lowestMoistureZoneCode;
  final DateTime lastUpdated;
  final CentralizedIrrigation centralIrrigation;
  final List<MonitoringZone> monitoringZones;
  final List<Esp32Node> connectedNodes;
  final List<FieldAlert> activeAlerts;
  final List<FieldRecommendation> recommendations;
  final bool forceStale;
  final AwdConfidence? confidence;
  final AwdAutomationEligibility? autoEligibility;

  const FieldDashboardSummary({
    required this.overallCondition,
    required this.overallConditionLabel,
    required this.awdStatusLabel,
    required this.requiresIrrigation,
    required this.isIrrigationRunning,
    required this.recommendedActionText,
    String? highestMoistureZoneCode,
    String? lowestMoistureZoneCode,
    String? wetterZoneCode,
    String? drierZoneCode,
    required this.lastUpdated,
    required this.centralIrrigation,
    required this.monitoringZones,
    this.connectedNodes = const [],
    required this.activeAlerts,
    required this.recommendations,
    this.forceStale = false,
    this.confidence,
    this.autoEligibility,
  })  : highestMoistureZoneCode = highestMoistureZoneCode ?? wetterZoneCode,
        lowestMoistureZoneCode = lowestMoistureZoneCode ?? drierZoneCode;

  String? get wetterZoneCode => highestMoistureZoneCode;
  String? get drierZoneCode => lowestMoistureZoneCode;

  bool get isStale =>
      forceStale || DateTime.now().difference(lastUpdated).inMinutes >= 15;

  /// Returns a copy of this summary with the given fields replaced.
  ///
  /// Used by the Home Dashboard to flag the retained readings as stale when the backend
  /// became unreachable, without discarding the last received values.
  FieldDashboardSummary copyWith({
    FieldConditionStatus? overallCondition,
    String? overallConditionLabel,
    String? awdStatusLabel,
    bool? requiresIrrigation,
    bool? isIrrigationRunning,
    String? recommendedActionText,
    DateTime? lastUpdated,
    CentralizedIrrigation? centralIrrigation,
    List<MonitoringZone>? monitoringZones,
    List<Esp32Node>? connectedNodes,
    List<FieldAlert>? activeAlerts,
    List<FieldRecommendation>? recommendations,
    bool? forceStale,
    AwdConfidence? confidence,
    AwdAutomationEligibility? autoEligibility,
  }) {
    return FieldDashboardSummary(
      overallCondition: overallCondition ?? this.overallCondition,
      overallConditionLabel:
          overallConditionLabel ?? this.overallConditionLabel,
      awdStatusLabel: awdStatusLabel ?? this.awdStatusLabel,
      requiresIrrigation: requiresIrrigation ?? this.requiresIrrigation,
      isIrrigationRunning: isIrrigationRunning ?? this.isIrrigationRunning,
      recommendedActionText:
          recommendedActionText ?? this.recommendedActionText,
      highestMoistureZoneCode: highestMoistureZoneCode,
      lowestMoistureZoneCode: lowestMoistureZoneCode,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      centralIrrigation: centralIrrigation ?? this.centralIrrigation,
      monitoringZones: monitoringZones ?? this.monitoringZones,
      connectedNodes: connectedNodes ?? this.connectedNodes,
      activeAlerts: activeAlerts ?? this.activeAlerts,
      recommendations: recommendations ?? this.recommendations,
      forceStale: forceStale ?? this.forceStale,
      confidence: confidence ?? this.confidence,
      autoEligibility: autoEligibility ?? this.autoEligibility,
    );
  }
}

