import '../../domain/models/field_alert.dart';
import '../../domain/models/field_dashboard_summary.dart';
import '../../domain/models/field_recommendation.dart';
import '../../../awd/domain/models/awd_analytics_summary.dart';
import '../../../awd/domain/models/awd_threshold_config.dart';
import '../../../awd/domain/models/crop_growth_stage.dart';
import '../../../awd/domain/services/awd_rule_engine.dart';
import '../../../irrigation/data/repositories/irrigation_repository.dart';
import '../../../irrigation/domain/models/centralized_irrigation.dart';
import '../../../zones/data/repositories/zone_repository.dart';
import '../../../zones/domain/models/monitoring_zone.dart';

enum MockState { normal, empty, stale, error }

abstract class FieldDashboardRepository {
  Future<FieldDashboardSummary> fetchDashboardSummary({
    MockState mockState = MockState.normal,
  });
}

class FieldDashboardRepositoryImpl implements FieldDashboardRepository {
  final ZoneRepository _zoneRepository;
  final IrrigationRepository _irrigationRepository;

  FieldDashboardRepositoryImpl({
    ZoneRepository? zoneRepository,
    IrrigationRepository? irrigationRepository,
  })  : _zoneRepository = zoneRepository ?? ZoneRepositoryImpl(),
        _irrigationRepository =
            irrigationRepository ?? IrrigationRepositoryImpl();

  @override
  Future<FieldDashboardSummary> fetchDashboardSummary({
    MockState mockState = MockState.normal,
  }) async {
    final zones = await _zoneRepository.fetchMonitoringZones();
    final system = await _irrigationRepository.fetchSystemStatus();

    final now = DateTime.now();
    final lastUpdated = now;

    // Find wetter vs drier zones
    MonitoringZone? wetterZone;
    MonitoringZone? drierZone;
    if (zones.isNotEmpty) {
      wetterZone = zones.reduce(
        (a, b) => a.soilMoisturePercent > b.soilMoisturePercent ? a : b,
      );
      drierZone = zones.reduce(
        (a, b) => a.soilMoisturePercent < b.soilMoisturePercent ? a : b,
      );
    }

    final isPumpRunning = system.mainPumpState == PumpState.active;
    final needsWater = drierZone != null && drierZone.soilMoisturePercent < 45;

    final condition = needsWater
        ? FieldConditionStatus.refluxNeeded
        : FieldConditionStatus.optimal;

    final conditionLabel = needsWater
        ? 'Reflux Irrigation Recommended'
        : 'Optimal Moisture Balance';

    final awdLabel = needsWater
        ? 'AWD Reflux Required'
        : 'Safe AWD Drying';

    final actionText = needsWater
        ? 'Activate centralized irrigation to supply drier zone ${drierZone.code}.'
        : 'No immediate irrigation required. Maintain current AWD monitoring.';

    final alerts = [
      if (needsWater)
        FieldAlert(
          id: 'alert-1',
          title: 'Low Moisture Level in ${drierZone.code}',
          message:
              '${drierZone.code} moisture is ${drierZone.soilMoisturePercent.toStringAsFixed(1)}%, reaching the AWD threshold.',
          severity: AlertSeverity.warning,
          timestamp: now.subtract(const Duration(minutes: 18)),
          zoneCode: drierZone.code,
        ),
      FieldAlert(
        id: 'alert-2',
        title: 'Central Pump Operational',
        message:
            'Centralized irrigation system is ${isPumpRunning ? "active" : "idle"}.',
        severity: AlertSeverity.info,
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
    ];

    final recommendations = [
      if (needsWater)
        FieldRecommendation(
          id: 'rec-1',
          title: 'Run Centralized Irrigation Pulse',
          description:
              'Zone ${drierZone.code} and others require moisture replenishment. Run the central pump for 45–60 mins.',
          urgency: RecommendationUrgency.high,
          actionType: ActionableType.startCentralIrrigation,
          recommendedDurationMinutes: 60,
        )
      else
        const FieldRecommendation(
          id: 'rec-2',
          title: 'Maintain AWD Soil Aeration',
          description:
              'Overall moisture balance across all monitoring zones is within optimal range. Continue observation.',
          urgency: RecommendationUrgency.low,
          actionType: ActionableType.noActionNeeded,
        ),
    ];

    final confidence = AwdRuleEngine.calculateConfidence(zones, now: lastUpdated);
    final fieldAwdStatus = condition == FieldConditionStatus.flooded
        ? FieldAwdStatus.flooded
        : (condition == FieldConditionStatus.criticallyDry
            ? FieldAwdStatus.criticalDryness
            : (needsWater ? FieldAwdStatus.refloodNeeded : FieldAwdStatus.safeDry));

    final autoEligibility = AwdRuleEngine.evaluateAutomationEligibility(
      fieldStatus: fieldAwdStatus,
      averageWaterDepthCm: zones.isNotEmpty
          ? zones.map((z) => z.waterLevelCm).reduce((a, b) => a + b) /
              zones.length
          : 0.0,
      minWaterDepthCm: zones.isNotEmpty
          ? zones.map((z) => z.waterLevelCm).reduce((a, b) => a < b ? a : b)
          : 0.0,
      confidence: confidence,
      isStaleData: mockState == MockState.stale,
      hasConflictingConditions: false,
      flaggedOutlierZoneCodes: const [],
      config: const AwdThresholdConfig(cropStage: CropGrowthStage.vegetative),
      now: lastUpdated,
    );

    return FieldDashboardSummary(
      overallCondition: condition,
      overallConditionLabel: conditionLabel,
      awdStatusLabel: awdLabel,
      requiresIrrigation: needsWater,
      isIrrigationRunning: isPumpRunning,
      recommendedActionText: actionText,
      wetterZoneCode: wetterZone?.code,
      drierZoneCode: drierZone?.code,
      lastUpdated: lastUpdated,
      centralIrrigation: system,
      monitoringZones: zones,
      activeAlerts: alerts,
      recommendations: recommendations,
      forceStale: mockState == MockState.stale,
      confidence: confidence,
      autoEligibility: autoEligibility,
    );
  }
}
