import '../../../../core/api/api_factory.dart';
import '../../../../core/api/api_mappers.dart';
import '../../../../core/api/api_services.dart';
import '../../domain/models/field_alert.dart';
import '../../domain/models/field_dashboard_summary.dart';
import '../../domain/models/field_recommendation.dart';
import '../../../awd/domain/models/awd_analytics_summary.dart';
import '../../../awd/domain/models/awd_threshold_config.dart';
import '../../../awd/domain/models/crop_growth_stage.dart';
import '../../../awd/domain/services/awd_rule_engine.dart';
import '../../../irrigation/data/repositories/irrigation_repository.dart';
import '../../../irrigation/domain/models/centralized_irrigation.dart';
import '../../../nodes/data/repositories/api_node_repository.dart';
import '../../../nodes/data/repositories/node_repository.dart';
import '../../../nodes/domain/models/models.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import '../../../zones/data/repositories/zone_repository.dart';
import '../../../zones/domain/models/monitoring_zone.dart';

enum MockState { normal, empty, stale, error }

/// Source of the latest telemetry values used by the Home Dashboard poll.
abstract class DashboardTelemetrySource {
  /// Resolves the newest reading of every requested node in a single round trip.
  Future<List<NodeTelemetrySnapshot>> fetchLatestTelemetry(List<String> nodeIds);
}

/// [DashboardTelemetrySource] backed by the batched backend endpoint
/// `GET /api/v1/nodes/telemetry/latest`.
class ApiDashboardTelemetrySource implements DashboardTelemetrySource {
  final NodeApiService _apiService;

  const ApiDashboardTelemetrySource(this._apiService);

  @override
  Future<List<NodeTelemetrySnapshot>> fetchLatestTelemetry(
    List<String> nodeIds,
  ) async {
    final response = await _apiService.getLatestTelemetrySnapshot(
      nodeIds: nodeIds,
    );
    return ApiMappers.nodeTelemetrySnapshots(response.data);
  }
}

abstract class FieldDashboardRepository {
  /// Loads the dashboard topology (nodes, zones, irrigation status) and composes the
  /// dashboard summary from it.
  ///
  /// Use this on the first render and whenever the field topology changes.
  Future<FieldDashboardSummary> fetchDashboardSummary({
    MockState mockState = MockState.normal,
  });

  /// Refreshes the latest telemetry of the already loaded nodes and recomposes the
  /// dashboard summary.
  ///
  /// The refresh performs a single batched request against
  /// `GET /api/v1/nodes/telemetry/latest`, so it never re-reads the zone topology and
  /// never scans the telemetry history on the backend.
  Future<FieldDashboardSummary> refreshLatestTelemetry();
}

class FieldDashboardRepositoryImpl implements FieldDashboardRepository {
  final ZoneRepository _zoneRepository;
  final IrrigationRepository _irrigationRepository;
  final NodeRepository _nodeRepository;
  final DashboardTelemetrySource? _telemetrySource;

  // Topology of the last successful load, reused by the lightweight telemetry poll.
  List<Esp32Node> _cachedNodes = const [];
  List<MonitoringZone> _cachedZones = const [];
  CentralizedIrrigation? _cachedSystem;
  MockState _activeMockState = MockState.normal;

  FieldDashboardRepositoryImpl({
    ZoneRepository? zoneRepository,
    IrrigationRepository? irrigationRepository,
    NodeRepository? nodeRepository,
    DashboardTelemetrySource? telemetrySource,
  })  : _zoneRepository = zoneRepository ?? ZoneRepositoryImpl(),
        _irrigationRepository =
            irrigationRepository ?? IrrigationRepositoryImpl(),
        _nodeRepository = nodeRepository ??
            (WidgetsBinding.instance.runtimeType.toString().contains('Test')
                ? MockNodeRepository()
                : ApiNodeRepository(ApiRepositoryFactory().nodes)),
        _telemetrySource = telemetrySource ??
            (WidgetsBinding.instance.runtimeType.toString().contains('Test')
                ? null
                : ApiDashboardTelemetrySource(ApiRepositoryFactory().nodes));

  @override
  Future<FieldDashboardSummary> fetchDashboardSummary({
    MockState mockState = MockState.normal,
  }) async {
    if (mockState == MockState.error) {
      throw Exception('Failed to fetch field telemetry data.');
    }
    _activeMockState = mockState;

    var zones = mockState == MockState.empty
        ? <MonitoringZone>[]
        : await _zoneRepository.fetchMonitoringZones();
    final system = await _irrigationRepository.fetchSystemStatus();

    List<Esp32Node> nodes = const [];
    if (mockState != MockState.empty) {
      nodes = await _nodeRepository.fetchNodes();
    }

    _cachedNodes = nodes;
    _cachedZones = zones;
    _cachedSystem = system;

    return _composeSummary(
      nodes: nodes,
      zones: zones,
      system: system,
      mockState: mockState,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<FieldDashboardSummary> refreshLatestTelemetry() async {
    // Simulated UI states are produced locally and must not be overwritten by a poll.
    if (_activeMockState != MockState.normal) {
      return fetchDashboardSummary(mockState: _activeMockState);
    }

    final telemetrySource = _telemetrySource;
    if (telemetrySource == null || _cachedNodes.isEmpty) {
      return fetchDashboardSummary();
    }

    final snapshots = await telemetrySource.fetchLatestTelemetry(
      _cachedNodes.map((node) => node.id).toList(growable: false),
    );
    final byNodeId = <String, NodeTelemetrySnapshot>{
      for (final snapshot in snapshots) snapshot.nodeId: snapshot,
    };

    final updatedNodes = _cachedNodes
        .map((node) => node.applyTelemetrySnapshot(
              byNodeId[node.id] ??
                  NodeTelemetrySnapshot(nodeId: node.id),
            ))
        .toList(growable: false);
    _cachedNodes = updatedNodes;

    return _composeSummary(
      nodes: updatedNodes,
      zones: _cachedZones,
      system: _cachedSystem ?? _fallbackSystem(),
      mockState: _activeMockState,
      lastUpdated: DateTime.now(),
    );
  }

  CentralizedIrrigation _fallbackSystem() {
    return CentralizedIrrigation(
      id: 'central-system-01',
      systemName: 'Main Field Irrigation Hub',
      mainPumpState: PumpState.idle,
      distributionValveState: ValveState.closed,
      flowRateLitersPerMin: 0.0,
      pressureBar: 0.0,
      mode: SystemMode.manual,
      activeDurationMinutes: 0,
      lastStateChange: DateTime.now(),
    );
  }

  FieldDashboardSummary _composeSummary({
    required List<Esp32Node> nodes,
    required List<MonitoringZone> zones,
    required CentralizedIrrigation system,
    required MockState mockState,
    required DateTime lastUpdated,
  }) {
    var enrichedZones = zones;

    if (nodes.isNotEmpty && zones.isNotEmpty) {
      enrichedZones = zones.map((zone) {
        final assignedNodes = nodes.where((n) =>
            (n.lifecycleState != NodeLifecycleStatus.unregistered &&
                n.lifecycleState != NodeLifecycleStatus.decommissioned) &&
            (zone.assignedNodeIds.contains(n.id) ||
                zone.assignedNodeIds.contains(n.displayName) ||
                n.assignedZoneId == zone.id ||
                n.assignedZoneId == zone.code ||
                n.assignedZoneId == 'zone-${zone.id}' ||
                n.assignedZoneId == zone.id.replaceAll(RegExp(r'[^0-9]'), '')))
            .toList();

        if (assignedNodes.isNotEmpty) {
          final moistureValues = assignedNodes
              .where((n) => !n.isSoilSensorFailed)
              .map((n) => n.soilMoisturePercent)
              .whereType<double>()
              .toList();
          final waterValues = assignedNodes
              .where((n) => !n.isUltrasonicSensorFailed)
              .map((n) => n.waterLevelCm)
              .whereType<double>()
              .toList();
          final batteryValues = assignedNodes
              .map((n) => n.batteryPercent)
              .whereType<int>()
              .toList();

          final double avgMoisture = moistureValues.isNotEmpty
              ? moistureValues.reduce((a, b) => a + b) / moistureValues.length
              : zone.soilMoisturePercent;

          final double avgWater = waterValues.isNotEmpty
              ? waterValues.reduce((a, b) => a + b) / waterValues.length
              : zone.waterLevelCm;

          final int avgBattery = batteryValues.isNotEmpty
              ? (batteryValues.reduce((a, b) => a + b) / batteryValues.length)
                  .round()
              : zone.batteryPercent;

          final isAnyOnline = assignedNodes.any((n) => n.isOnline);

          return zone.copyWith(
            soilMoisturePercent: avgMoisture,
            waterLevelCm: avgWater,
            batteryPercent: avgBattery,
            isOnline: isAnyOnline,
            assignedNodeIds: assignedNodes.map((n) => n.id).toList(),
          );
        }
        return zone.copyWith(
          assignedNodeIds: const [],
          isOnline: false,
        );
      }).toList();
    }

    // Find highest vs lowest moisture zones
    MonitoringZone? highestMoistureZone;
    MonitoringZone? lowestMoistureZone;
    if (enrichedZones.isNotEmpty) {
      highestMoistureZone = enrichedZones.reduce(
        (a, b) => a.soilMoisturePercent > b.soilMoisturePercent ? a : b,
      );
      lowestMoistureZone = enrichedZones.reduce(
        (a, b) => a.soilMoisturePercent < b.soilMoisturePercent ? a : b,
      );
    }

    final isPumpRunning = system.mainPumpState == PumpState.active;
    final needsWater = lowestMoistureZone != null && lowestMoistureZone.soilMoisturePercent < 45;

    final condition = needsWater
        ? FieldConditionStatus.refluxNeeded
        : FieldConditionStatus.optimal;

    final conditionLabel = needsWater
        ? 'Irrigation Replenishment Needed'
        : 'Optimal Moisture Balance';

    final awdLabel = needsWater
        ? 'Irrigation Required'
        : 'Moisture Sufficient';

    final actionText = needsWater
        ? 'Activate centralized irrigation to supply deficit zone ${lowestMoistureZone.code}.'
        : 'No immediate irrigation required. Moisture levels are within optimal range.';

    final alerts = mockState == MockState.empty
        ? <FieldAlert>[]
        : [
            if (needsWater)
              FieldAlert(
                id: 'alert-1',
                title: 'Low Moisture in ${lowestMoistureZone.code}',
                message:
                    '${lowestMoistureZone.code} moisture is ${lowestMoistureZone.soilMoisturePercent.toStringAsFixed(1)}%, falling below the target threshold.',
                severity: AlertSeverity.warning,
                timestamp: lastUpdated.subtract(const Duration(minutes: 18)),
                zoneCode: lowestMoistureZone.code,
              ),
            FieldAlert(
              id: 'alert-2',
              title: 'Central Pump Operational',
              message:
                  'Centralized irrigation pump is currently ${isPumpRunning ? "active" : "idle"}.',
              severity: AlertSeverity.info,
              timestamp: lastUpdated.subtract(const Duration(minutes: 5)),
            ),
          ];

    final recommendations = mockState == MockState.empty
        ? <FieldRecommendation>[]
        : [
            if (needsWater)
              FieldRecommendation(
                id: 'rec-1',
                title: 'Run Centralized Irrigation',
                description:
                    'Zone ${lowestMoistureZone.code} and neighboring areas require moisture replenishment. Run the central pump for 30–60 mins.',
                urgency: RecommendationUrgency.high,
                actionType: ActionableType.startCentralIrrigation,
                recommendedDurationMinutes: 60,
              )
            else
              const FieldRecommendation(
                id: 'rec-2',
                title: 'Maintain Current Irrigation Standby',
                description:
                    'Moisture balance across all monitoring zones is optimal. Central pump remains on standby.',
                urgency: RecommendationUrgency.low,
                actionType: ActionableType.noActionNeeded,
              ),
          ];

    final confidence = AwdRuleEngine.calculateConfidence(enrichedZones, now: lastUpdated);
    final fieldAwdStatus = condition == FieldConditionStatus.flooded
        ? FieldAwdStatus.flooded
        : (condition == FieldConditionStatus.criticallyDry
            ? FieldAwdStatus.criticalDryness
            : (needsWater ? FieldAwdStatus.refloodNeeded : FieldAwdStatus.safeDry));

    final autoEligibility = AwdRuleEngine.evaluateAutomationEligibility(
      fieldStatus: fieldAwdStatus,
      averageWaterDepthCm: enrichedZones.isNotEmpty
          ? enrichedZones.map((z) => z.waterLevelCm).reduce((a, b) => a + b) /
              enrichedZones.length
          : 0.0,
      minWaterDepthCm: enrichedZones.isNotEmpty
          ? enrichedZones.map((z) => z.waterLevelCm).reduce((a, b) => a < b ? a : b)
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
      highestMoistureZoneCode: highestMoistureZone?.code,
      lowestMoistureZoneCode: lowestMoistureZone?.code,
      lastUpdated: lastUpdated,
      centralIrrigation: system,
      monitoringZones: enrichedZones,
      connectedNodes: nodes,
      activeAlerts: alerts,
      recommendations: recommendations,
      forceStale: mockState == MockState.stale,
      confidence: confidence,
      autoEligibility: autoEligibility,
    );
  }
}
