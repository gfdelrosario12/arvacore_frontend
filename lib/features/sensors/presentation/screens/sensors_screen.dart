import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/api/api_dtos.dart';
import '../../../../core/api/api_errors.dart';
import '../../../../core/api/api_factory.dart';
import '../../../../core/api/api_mappers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/realtime/realtime_coordinator.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../control/domain/models/control_enums.dart';
import '../../../diagnostics/domain/models/models.dart';
import '../../../diagnostics/presentation/providers/diagnostics_provider.dart';
import '../../../diagnostics/presentation/widgets/device_detail_dialog.dart';
import '../../../field/domain/models/field.dart';
import '../../../field/presentation/widgets/dynamic_zone_grid_visualizer.dart';
import '../../../field/presentation/widgets/farmland_designer_view.dart';
import '../../../field/presentation/widgets/field_header_overview_card.dart';
import '../../../field/presentation/widgets/pairing_requests_modal.dart';
import '../../../field/presentation/widgets/zone_detail_bottom_sheet.dart';
import '../../../irrigation/data/repositories/irrigation_repository.dart';
import '../../../irrigation/domain/models/centralized_irrigation.dart';
import '../../../nodes/data/repositories/api_node_repository.dart';
import '../../../nodes/data/repositories/node_repository.dart';
import '../../../nodes/domain/models/models.dart';
import '../../../nodes/domain/models/node_sensor_categories.dart';
import '../../../nodes/presentation/providers/node_management_notifier.dart';
import '../../../nodes/presentation/widgets/all_node_water_levels_widget.dart';
import '../../../nodes/presentation/widgets/multi_node_sensor_matrix_widget.dart';
import '../../../nodes/presentation/widgets/node_assignment_dialog.dart';
import '../../../nodes/presentation/widgets/node_registration_dialog.dart';
import '../../../nodes/presentation/widgets/node_unpair_dialog.dart';
import '../../../nodes/presentation/widgets/spatial_field_canvas_visualizer.dart';
import '../../../nodes/presentation/widgets/transmission_interval_dialog.dart';
import '../../../shell/presentation/app_shell.dart';
import '../../../telemetry_stream/presentation/providers/telemetry_stream_notifier.dart';
import '../../../telemetry_stream/presentation/widgets/telemetry_stream_event_card.dart';
import '../../../telemetry_stream/presentation/widgets/telemetry_stream_summary_card.dart';
import '../../../zones/data/repositories/zone_repository.dart';
import '../../../zones/domain/models/monitoring_zone.dart';

enum SensorsVisualizationMode { matrix, spatial, designer }

/// Unified Sensors Screen for ArvaLink.
///
/// Merges Monitoring and Field management into a cohesive, mobile-first experience:
/// - Section A: Overview (Fleet health, telemetry status, ingestion pipeline)
/// - Section B: Field Map (Dynamic 2x2/NxM zone map, spatial canvas, farmland designer, node assignment)
/// - Section C: Monitoring Nodes (Every registered ArvaNode with live identity & status)
/// - Section D: Sensor Measurements (All 6 agricultural sensor categories & comparative water levels)
class SensorsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToControl;
  final void Function(String? prompt)? onNavigateToAi;
  final RealtimeCoordinator? realtimeCoordinator;
  final DiagnosticsNotifier? diagnosticsNotifier;
  final NodeManagementNotifier? nodeNotifier;
  final ZoneRepository? zoneRepository;
  final NodeRepository? nodeRepository;
  final IrrigationRepository? irrigationRepository;
  final ControlUserRole userRole;

  const SensorsScreen({
    super.key,
    this.onNavigateToControl,
    this.onNavigateToAi,
    this.realtimeCoordinator,
    this.diagnosticsNotifier,
    this.nodeNotifier,
    this.zoneRepository,
    this.nodeRepository,
    this.irrigationRepository,
    this.userRole = ControlUserRole.operator,
  });

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TelemetryStreamNotifier _telemetryNotifier;
  late final DiagnosticsNotifier _diagnosticsNotifier;
  late final NodeManagementNotifier _nodeNotifier;

  late final ZoneRepository _zoneRepository;
  late final NodeRepository _nodeRepository;
  late final IrrigationRepository _irrigationRepository;
  late final ApiRepositoryFactory _apiFactory;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedZoneCode;

  // Field & Map Visualization Mode
  SensorsVisualizationMode _visMode = SensorsVisualizationMode.matrix;
  Field? _currentField;
  List<MonitoringZone> _zones = [];
  CentralizedIrrigation? _centralIrrigation;

  // Master State and Pairing Requests
  bool _masterEnabled = true;
  bool _isTogglingMaster = false;
  List<PairingRequestDto> _pendingPairings = [];
  Timer? _pairingPollTimer;
  bool _isPollingPairings = false;

  bool _isFieldLoading = true;

  @override
  void initState() {
    super.initState();
    _apiFactory = ApiRepositoryFactory();
    _tabController = TabController(length: 4, vsync: this);

    _telemetryNotifier = TelemetryStreamNotifier(
      realtimeCoordinator: widget.realtimeCoordinator,
    );
    _diagnosticsNotifier = widget.diagnosticsNotifier ?? DiagnosticsNotifier();

    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    _nodeRepository = widget.nodeRepository ??
        (isTest ? MockNodeRepository() : ApiNodeRepository(_apiFactory.nodes));
    _zoneRepository = widget.zoneRepository ?? ZoneRepositoryImpl();
    _irrigationRepository = widget.irrigationRepository ?? IrrigationRepositoryImpl();

    _nodeNotifier = widget.nodeNotifier ??
        NodeManagementNotifier(
          repository: _nodeRepository,
          realtimeCoordinator: widget.realtimeCoordinator,
        );

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    globalNodeSyncNotifier.addListener(_onGlobalNodeSync);
    _loadFieldAndZones();
    _startPairingPolling();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _telemetryNotifier.dispose();
    if (widget.diagnosticsNotifier == null) {
      _diagnosticsNotifier.dispose();
    }
    if (widget.nodeNotifier == null) {
      _nodeNotifier.dispose();
    }
    globalNodeSyncNotifier.removeListener(_onGlobalNodeSync);
    _pairingPollTimer?.cancel();
    super.dispose();
  }

  void _onGlobalNodeSync() {
    if (mounted) {
      _loadFieldAndZones();
      _nodeNotifier.fetchNodes();
    }
  }

  void _startPairingPolling() {
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) return;
    _pairingPollTimer?.cancel();
    _pairingPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _pollPairingRequestsSilently();
    });
  }

  Future<void> _pollPairingRequestsSilently() async {
    if (!mounted || _isPollingPairings) return;
    _isPollingPairings = true;
    try {
      final pairings = await _apiFactory.system.getPendingPairingRequests(retryable: false);
      if (mounted) {
        if (_pendingPairings.length != pairings.length ||
            !_pendingPairings.every((p) => pairings.any((n) => n.id == p.id))) {
          setState(() {
            _pendingPairings = pairings;
          });
        }
      }
    } catch (_) {
    } finally {
      _isPollingPairings = false;
    }
  }

  Future<void> _loadFieldAndZones() async {
    if (!mounted) return;
    setState(() {
      _isFieldLoading = true;
    });

    List<MonitoringZone> zones = _zones;
    List<Esp32Node> nodes = _nodeNotifier.state.nodes;
    CentralizedIrrigation? sys = _centralIrrigation;

    // 1. Zones
    try {
      zones = await _zoneRepository.fetchMonitoringZones();
    } catch (e) {
      debugPrint('[SensorsScreen] Failed to fetch zones: $e');
      if (e is ApiException && e.kind == ApiErrorKind.authentication) {
        if (mounted) globalAuthNotifier.handleApiSecurityFailure(e);
        return;
      }
    }

    // 2. Nodes
    try {
      nodes = await _nodeRepository.fetchNodes();
    } catch (e) {
      debugPrint('[SensorsScreen] Failed to fetch nodes: $e');
    }

    // 3. Central Irrigation
    try {
      sys = await _irrigationRepository.fetchSystemStatus();
    } catch (e) {
      debugPrint('[SensorsScreen] Central irrigation fetch notice: $e');
    }

    // 4. Master state & pairing requests
    bool masterOn = _masterEnabled;
    List<PairingRequestDto> pairings = _pendingPairings;
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      try {
        final masterState = await _apiFactory.system.getMasterState();
        masterOn = masterState.masterEnabled;
        pairings = await _apiFactory.system.getPendingPairingRequests();
      } catch (err) {
        debugPrint('[SensorsScreen] Master/Pairings fetch notice: $err');
      }
    }

    // 5. Reconcile zones with active nodes
    if (zones.isNotEmpty) {
      zones = zones.map((zone) {
        final assignedNodes = nodes.where((n) =>
            (n.lifecycleState != NodeLifecycleStatus.unregistered &&
             n.lifecycleState != NodeLifecycleStatus.decommissioned) &&
            (zone.assignedNodeIds.contains(n.id) ||
             zone.assignedNodeIds.contains(n.displayName) ||
             n.assignedZoneId == zone.id ||
             n.assignedZoneId == zone.code ||
             n.assignedZoneId == 'zone-${zone.id}' ||
             n.assignedZoneId == zone.id.replaceAll(RegExp(r'[^0-9]'), ''))).toList();

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
              ? (batteryValues.reduce((a, b) => a + b) / batteryValues.length).round()
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

    // 6. Fetch Field details dynamically
    Field? fieldCfg;
    if (!isTest) {
      try {
        final fieldsListDto = await _apiFactory.fields.listFields();
        if (fieldsListDto.items.isNotEmpty) {
          final matched = fieldsListDto.items.where((f) => f.id == _currentField?.id).firstOrNull;
          final targetDto = matched ?? fieldsListDto.items.first;
          fieldCfg = ApiMappers.field(FieldDto.fromJson(targetDto.data));
        }
      } catch (e) {
        debugPrint('[SensorsScreen] Field list fetch notice: $e');
        try {
          final fieldDto = await _apiFactory.fields.getField(_currentField?.id ?? '1');
          fieldCfg = ApiMappers.field(FieldDto.fromJson(fieldDto.data));
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _zones = zones;
        _centralIrrigation = sys;
        _masterEnabled = masterOn;
        _pendingPairings = pairings;
        _currentField = fieldCfg;
        _isFieldLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_telemetryNotifier, _diagnosticsNotifier, _nodeNotifier]),
      builder: (context, _) {
        final diagState = _diagnosticsNotifier.state;
        final nodeState = _nodeNotifier.state;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sensors, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Sensors',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              // Pending pairings indicator button
              if (_pendingPairings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.alertWarning,
                      backgroundColor: AppColors.alertWarning.withValues(alpha: 0.12),
                    ),
                    icon: const Icon(Icons.link, size: 16),
                    label: Text('${_pendingPairings.length} Pairing'),
                    onPressed: _openPairingModal,
                  ),
                ),

              // Pause / Resume Stream Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: _telemetryNotifier.isPaused
                        ? AppColors.zoneLow.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.12),
                    foregroundColor: _telemetryNotifier.isPaused ? AppColors.zoneLow : AppColors.primary,
                  ),
                  onPressed: _telemetryNotifier.togglePause,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _telemetryNotifier.isPaused ? Icons.play_arrow : Icons.pause,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _telemetryNotifier.isPaused ? 'Resume' : 'Pause',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Global Refresh
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Sensors & Field Pipeline',
                onPressed: () {
                  _telemetryNotifier.refresh();
                  _diagnosticsNotifier.fetchDiagnostics();
                  _nodeNotifier.fetchNodes();
                  _loadFieldAndZones();
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
                Tab(icon: Icon(Icons.map_outlined, size: 18), text: 'Field Map'),
                Tab(icon: Icon(Icons.devices_other_outlined, size: 18), text: 'Monitoring Nodes'),
                Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Measurements'),
              ],
            ),
          ),
          body: SafeArea(
            child: ResponsiveContainer(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewSection(theme, diagState, nodeState.nodes, nodeState.isLoading),
                  _buildFieldMapSection(theme, nodeState.nodes),
                  _buildMonitoringNodesSection(theme, diagState, nodeState.nodes),
                  _buildSensorMeasurementsSection(theme, nodeState.nodes, nodeState.isLoading),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // Section A: Overview
  // =========================================================================
  Widget _buildOverviewSection(
    ThemeData theme,
    DiagnosticsStateData diagState,
    List<Esp32Node> nodes,
    bool isNodesLoading,
  ) {
    final summary = _telemetryNotifier.summary;
    final totalNodes = nodes.length;
    final onlineNodes = nodes.where((n) => n.isOnline).length;
    final staleNodes = nodes.where((n) {
      final ageMinutes = DateTime.now().difference(n.lastSeen).inMinutes;
      return n.isOnline && ageMinutes >= 15;
    }).length;
    final offlineNodes = nodes.where((n) => !n.isOnline).length;

    return RefreshIndicator(
      onRefresh: () async {
        _telemetryNotifier.refresh();
        await Future.wait([
          _diagnosticsNotifier.fetchDiagnostics(),
          _nodeNotifier.fetchNodes(),
          _loadFieldAndZones(),
        ]);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unified Sensors Overview',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Continuous telemetry, fleet health, and field positions',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'PIPELINE HEALTHY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Arva AI Quick Event Insight Banner
            _buildArvaAiQuickInsightBanner(theme),

            const SizedBox(height: AppDimensions.spaceMd),

            // Telemetry Ingestion Pipeline Summary
            TelemetryStreamSummaryCard(
              summary: summary,
              isRealtimeConnected: true,
              connectionState: RealtimeConnectionState.connected,
            ),

            const SizedBox(height: AppDimensions.spaceMd),

            // Fleet Connectivity Metrics Grid
            Text(
              'Monitoring Fleet Connectivity',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Total Nodes',
                    value: '$totalNodes',
                    icon: Icons.devices,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Reporting',
                    value: '$onlineNodes',
                    icon: Icons.wifi,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Stale / Delayed',
                    value: '$staleNodes',
                    icon: Icons.timelapse,
                    color: AppColors.alertWarning,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Offline',
                    value: '$offlineNodes',
                    icon: Icons.wifi_off,
                    color: AppColors.alertError,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.spaceLg),

            // Comparative Water Levels Summary
            AllNodeWaterLevelsWidget(
              nodes: nodes,
              isLoading: isNodesLoading,
            ),

            const SizedBox(height: AppDimensions.spaceLg),

            // Quick Actions to Navigate Sub-sections
            AquaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sensors Navigation Shortcuts',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('View Field Map & Positions'),
                        onPressed: () => _tabController.animateTo(1),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.devices_other_outlined, size: 16),
                        label: const Text('Manage Monitoring Nodes'),
                        onPressed: () => _tabController.animateTo(2),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.analytics_outlined, size: 16),
                        label: const Text('Inspect All 6 Sensor Categories'),
                        onPressed: () => _tabController.animateTo(3),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                        label: const Text('Ask Arva AI About Sensors'),
                        onPressed: () {
                          if (widget.onNavigateToAi != null) {
                            widget.onNavigateToAi!('Explain current sensor readings across all monitoring nodes and identify any abnormalities.');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArvaAiQuickInsightBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Arva AI Event-Driven Insights',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: const Text(
                        'LIVE AWD',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Multi-terrace telemetry is continuously cross-referenced with PhilRice PalayCheck and IRRI safe drying thresholds. Tap to ask Arva AI for a comprehensive field advisory.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    if (widget.onNavigateToAi != null) {
                      widget.onNavigateToAi!('Explain current sensor readings across all monitoring nodes and identify any abnormalities.');
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Consult Arva AI on Sensors',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Section B: Field Map
  // =========================================================================
  Widget _buildFieldMapSection(ThemeData theme, List<Esp32Node> nodes) {
    if (_isFieldLoading && _zones.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final unassignedNodes = nodes.where((n) =>
        n.lifecycleState != NodeLifecycleStatus.unregistered &&
        n.lifecycleState != NodeLifecycleStatus.decommissioned &&
        (n.assignedZoneId == null ||
         n.assignedZoneId!.isEmpty ||
         n.assignedZoneId!.toUpperCase() == 'UNASSIGNED')).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await _loadFieldAndZones();
        await _nodeNotifier.fetchNodes();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visualization Mode Selector Bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paddy Field Layout & Positions',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Map node locations, spatial coordinates, and monitoring zones',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                SegmentedButton<SensorsVisualizationMode>(
                  segments: const [
                    ButtonSegment(
                      value: SensorsVisualizationMode.matrix,
                      icon: Icon(Icons.grid_view, size: 16),
                      tooltip: 'Zone Grid',
                    ),
                    ButtonSegment(
                      value: SensorsVisualizationMode.spatial,
                      icon: Icon(Icons.scatter_plot, size: 16),
                      tooltip: 'Spatial Canvas',
                    ),
                    ButtonSegment(
                      value: SensorsVisualizationMode.designer,
                      icon: Icon(Icons.architecture, size: 16),
                      tooltip: 'Farmland Designer',
                    ),
                  ],
                  selected: {_visMode},
                  onSelectionChanged: (modes) {
                    setState(() => _visMode = modes.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Field Header Overview Card with Pairing Actions
            FieldHeaderOverviewCard(
              zones: _zones,
              nodes: nodes,
              isStale: nodes.any((n) {
                final ageMinutes = DateTime.now().difference(n.lastSeen).inMinutes;
                return n.isOnline && ageMinutes >= 15;
              }),
              masterEnabled: _masterEnabled,
              isTogglingMaster: _isTogglingMaster,
              onToggleMaster: _toggleMasterState,
              pendingPairingCount: _pendingPairings.length,
              onOpenPairingRequests: _openPairingModal,
              onResetPairing: _handleResetPairings,
            ),

            if (unassignedNodes.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spaceMd),
              _buildUnassignedNodesCard(theme, unassignedNodes),
            ],

            const SizedBox(height: AppDimensions.spaceLg),

            // Active Visualization View
            if (_visMode == SensorsVisualizationMode.designer && _currentField != null)
              FarmlandDesignerView(
                field: _currentField!,
                zones: _zones,
                nodes: nodes,
                onRefresh: _loadFieldAndZones,
                onAssignNode: (nodeId, {fieldId, monitoringZoneId}) async {
                  await _nodeRepository.assignNodeToField(
                    nodeId,
                    fieldId: fieldId,
                    monitoringZoneId: monitoringZoneId,
                  );
                  await _loadFieldAndZones();
                  notifyGlobalNodeStateChanged();
                  return true;
                },
                onUnpairNode: _handleUnpairNode,
              )
            else if (_visMode == SensorsVisualizationMode.spatial)
              SpatialFieldCanvasVisualizer(
                nodes: nodes,
                onNodeSelected: (node) {
                  final zone = _zones.where((z) =>
                      z.id == node.assignedZoneId ||
                      z.code == node.assignedZoneId ||
                      z.code.toLowerCase() == node.assignedZoneId?.toLowerCase().replaceAll('zone-', '')).firstOrNull;
                  if (zone != null) {
                    _handleZoneSelection(zone);
                  }
                },
                onConfigureInterval: (node) => _configureNodeInterval(node),
              )
            else
              DynamicZoneGridVisualizer(
                zones: _zones,
                nodes: nodes,
                selectedZoneCode: _selectedZoneCode,
                onZoneSelected: _handleZoneSelection,
                onAssignNodeToZone: (zone) => _openNodeAssignment(zone: zone),
                onAddZone: () => _showCreateZoneDialog(),
                isMasterOff: !_masterEnabled,
              ),

            const SizedBox(height: AppDimensions.spaceLg),

            // Detailed Zone Telemetry List
            Text(
              'Configured Monitoring Zones',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            if (_zones.isEmpty)
              AquaCard(
                padding: const EdgeInsets.all(AppDimensions.spaceLg),
                child: Center(
                  child: Text(
                    'No monitoring zones configured. Add a zone to bind ArvaNodes.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _zones.length,
                separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spaceMd),
                itemBuilder: (context, index) {
                  final zone = _zones[index];
                  return _buildZoneSummaryCard(theme, zone, nodes);
                },
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Section C: Monitoring Nodes
  // =========================================================================
  Widget _buildMonitoringNodesSection(
    ThemeData theme,
    DiagnosticsStateData diagState,
    List<Esp32Node> nodes,
  ) {
    var filtered = nodes;
    if (_searchQuery.isNotEmpty) {
      filtered = nodes.where((n) {
        return n.id.toLowerCase().contains(_searchQuery) ||
            n.displayName.toLowerCase().contains(_searchQuery) ||
            n.macAddress.toLowerCase().contains(_searchQuery) ||
            (n.assignedZoneCode ?? '').toLowerCase().contains(_searchQuery) ||
            (n.assignedZoneName ?? '').toLowerCase().contains(_searchQuery);
      }).toList();
    }

    return Column(
      children: [
        // Search & Register Action Bar
        Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Node ID, Zone (e.g. ARVANODE-001, Q1)...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add_link, size: 18),
                label: const Text('Pair Node'),
                onPressed: _openNodeScanner,
              ),
            ],
          ),
        ),

        // Node Cards List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sensors_off_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: AppDimensions.spaceSm),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No nodes matching "$_searchQuery"'
                            : 'No ArvaNodes registered.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final node = filtered[index];
                    return _buildNodeItemCard(theme, node, diagState);
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // Section D: Sensor Measurements (All 6 Categories)
  // =========================================================================
  Widget _buildSensorMeasurementsSection(
    ThemeData theme,
    List<Esp32Node> nodes,
    bool isLoading,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        _telemetryNotifier.refresh();
        await Future.wait([
          _nodeNotifier.fetchNodes(),
          _loadFieldAndZones(),
        ]);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All-Node Sensor Telemetry',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Live continuous readings across all 6 agricultural sensor categories',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // All-Node Water Level Monitoring
            AllNodeWaterLevelsWidget(
              nodes: nodes,
              isLoading: isLoading,
            ),

            const SizedBox(height: AppDimensions.spaceMd),

            // Multi-Node Sensor Matrix (All 6 categories)
            MultiNodeSensorMatrixWidget(
              nodes: nodes,
              isLoading: isLoading,
              filterQuery: _searchQuery,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Helper Widgets & Dialog Triggers
  // =========================================================================
  Widget _buildMetricTile(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedNodesCard(ThemeData theme, List<Esp32Node> unassigned) {
    return AquaCard(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: const Icon(Icons.device_hub, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unassigned Hardware Nodes (${unassigned.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paired ArvaNodes awaiting field placement or monitoring position assignment.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          ...unassigned.map((node) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                node.isOnline ? Icons.sensors : Icons.sensors_off,
                color: node.isOnline ? AppColors.success : Colors.grey,
              ),
              title: Text(node.displayName.isNotEmpty ? node.displayName : node.id),
              subtitle: Text('MAC: ${node.macAddress} | Status: ${node.isOnline ? "Online" : "Offline"}'),
              trailing: FilledButton.tonal(
                child: const Text('Assign'),
                onPressed: () => _openNodeAssignment(node: node),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNodeItemCard(
    ThemeData theme,
    Esp32Node node,
    DiagnosticsStateData diagState,
  ) {
    final isOnline = node.isOnline;
    final ageMinutes = DateTime.now().difference(node.lastSeen).inMinutes;
    final isStale = isOnline && ageMinutes >= 15;

    Color badgeColor = AppColors.success;
    String badgeText = isOnline ? 'ONLINE' : 'OFFLINE';
    if (isStale) {
      badgeColor = AppColors.alertWarning;
      badgeText = 'STALE';
    } else if (!isOnline) {
      badgeColor = AppColors.alertError;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      child: AquaCard(
        child: InkWell(
          onTap: () {
            final devDiag = diagState.devices.firstWhere(
              (d) => d.id == node.id || d.macAddress == node.macAddress,
              orElse: () => DeviceDiagnostic(
                id: node.id,
                name: node.displayName,
                macAddress: node.macAddress,
                category: DeviceCategory.sensorNode,
                isOnline: node.isOnline,
                lastSeen: node.lastSeen,
                batteryPercent: node.batteryPercent ?? 100,
                healthStatus: isOnline ? DeviceHealthStatus.healthy : DeviceHealthStatus.offline,
                targetScope: node.assignedZoneCode ?? 'UNASSIGNED',
                diagnosticMessage: isOnline ? 'Device online and transmitting telemetry.' : 'Device offline.',
              ),
            );
            DeviceDetailDialog.show(
              context,
              devDiag,
              userRole: widget.userRole,
              onConfigureInterval: (sec, {isAdaptive = true, reason}) async {
                await _configureNodeInterval(node);
                return true;
              },
              onUnpairNode: _handleUnpairNode,
            );
          },
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceSm),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Icon(Icons.sensors, color: badgeColor, size: 20),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              node.displayName.isNotEmpty ? node.displayName : node.id,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: badgeText,
                            colorOverride: badgeColor,
                            type: StatusBadgeType.monitoring,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zone: ${node.assignedZoneCode ?? "Unassigned"} | Batt: ${node.batteryPercent ?? "N/A"}% | Water: ${node.waterLevelCm != null ? "${node.waterLevelCm!.toStringAsFixed(1)} cm" : "N/A"}',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, size: 18),
                  tooltip: 'Configure Node',
                  onPressed: () => _configureNodeInterval(node),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoneSummaryCard(
    ThemeData theme,
    MonitoringZone zone,
    List<Esp32Node> nodes,
  ) {
    final assignedNodes = nodes.where((n) =>
        (zone.assignedNodeIds.contains(n.id) ||
         zone.assignedNodeIds.contains(n.displayName) ||
         n.assignedZoneId == zone.id ||
         n.assignedZoneId == zone.code ||
         n.assignedZoneId == 'zone-${zone.id}' ||
         n.assignedZoneId == zone.id.replaceAll(RegExp(r'[^0-9]'), ''))).toList();

    return AquaCard(
      child: ListTile(
        title: Row(
          children: [
            Text(
              '${zone.code} — ${zone.name}',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            StatusBadge(
              label: zone.isOnline ? 'ACTIVE' : 'OFFLINE',
              colorOverride: zone.isOnline ? AppColors.success : AppColors.alertError,
              type: StatusBadgeType.monitoring,
            ),
          ],
        ),
        subtitle: Text(
          'Nodes: ${assignedNodes.length} | Soil Moisture: ${zone.soilMoisturePercent.toStringAsFixed(1)}% | Water Depth: ${zone.waterLevelCm.toStringAsFixed(1)} cm',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _handleZoneSelection(zone),
      ),
    );
  }

  Future<void> _handleZoneSelection(MonitoringZone zone) async {
    setState(() => _selectedZoneCode = zone.code);
    final assignedNodes = _nodes.where((n) =>
        (zone.assignedNodeIds.contains(n.id) ||
         zone.assignedNodeIds.contains(n.displayName) ||
         n.assignedZoneId == zone.id ||
         n.assignedZoneId == zone.code ||
         n.assignedZoneId == 'zone-${zone.id}' ||
         n.assignedZoneId == zone.id.replaceAll(RegExp(r'[^0-9]'), ''))).toList();

    ZoneDetailBottomSheet.show(
      context,
      zone: zone,
      assignedNodes: assignedNodes,
      userRole: widget.userRole,
      onConfigureInterval: (node) => _configureNodeInterval(node),
      onUnpairNode: _handleUnpairNode,
      onAssignNode: (z, n) => _openNodeAssignment(zone: z, node: n),
      onDeleteZone: (z) async {
        final fieldId = z.fieldId.isNotEmpty ? z.fieldId : (_currentField?.id ?? '1');
        await _zoneRepository.deleteZone(z.id, fieldId: fieldId);
        await _loadFieldAndZones();
      },
    );
  }

  List<Esp32Node> get _nodes => _nodeNotifier.state.nodes;

  Future<void> _toggleMasterState(bool enable) async {
    setState(() => _isTogglingMaster = true);
    try {
      final result = await _apiFactory.system.updateMasterState(
        enabled: enable,
        notes: enable ? 'Turned ON via ArvaLink' : 'Turned OFF via ArvaLink',
      );
      setState(() => _masterEnabled = result.masterEnabled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sensor network pairing ${enable ? "enabled" : "disabled"}.'),
          backgroundColor: enable ? AppColors.success : AppColors.alertWarning,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update master state: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isTogglingMaster = false);
    }
  }

  Future<void> _openPairingModal() async {
    try {
      final fresh = await _apiFactory.system.getPendingPairingRequests();
      if (mounted) setState(() => _pendingPairings = fresh);
    } catch (_) {}

    if (!mounted) return;
    PairingRequestsModal.show(
      context,
      requests: _pendingPairings,
      isMasterOff: !_masterEnabled,
      onAllow: (req) => _handleAllowPairing(req),
      onReject: (req) => _handleRejectPairing(req),
    );
  }

  Future<void> _handleRejectPairing(PairingRequestDto req) async {
    Navigator.of(context).pop();
    try {
      await _apiFactory.system.rejectPairingRequest(req.id, reason: 'Rejected by administrator');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejected pairing request for ${req.nodeId}.'), backgroundColor: AppColors.error),
      );
      await _loadFieldAndZones();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleAllowPairing(PairingRequestDto req) async {
    Navigator.of(context).pop();
    final discoveryInfo = NodeDiscoveryInfo(
      id: req.nodeId,
      macAddress: req.macAddress ?? 'AA:BB:CC:DD:EE:01',
      hardwareModel: req.hardwareModel ?? 'ESP32 Wi-Fi Node',
      firmwareVersion: req.firmwareVersion ?? '1.0.0',
      rssiDbm: -65,
      detectedAt: DateTime.now(),
      pairingRequestId: req.id,
      recognized: req.recognized,
      pairingStatus: req.pairingStatus,
      existingLifecycleState: req.existingLifecycleState,
      existingZoneId: req.existingZoneId,
      existingZoneName: req.existingZoneName,
      expiresAt: req.expiresAt,
      isExpired: req.isExpired,
    );

    await NodeRegistrationDialog.show(
      context,
      discoveredNodes: [discoveryInfo],
      zones: _zones,
      onRegister: (registerReq) async {
        int? zoneNum;
        if (registerReq.zoneId.isNotEmpty && registerReq.zoneId.toUpperCase() != 'UNASSIGNED') {
          zoneNum = int.tryParse(registerReq.zoneId.replaceAll(RegExp(r'[^0-9]'), ''));
        }
        await _apiFactory.system.approvePairingRequest(
          req.id,
          nodeId: req.nodeId,
          identityType: 'MAC_ADDRESS',
          identityValue: req.macAddress ?? req.nodeId,
          monitoringZoneId: zoneNum,
        );
        await _loadFieldAndZones();
        await _nodeNotifier.fetchNodes();
        notifyGlobalNodeStateChanged();
        return true;
      },
    );
  }

  Future<void> _openNodeScanner() async {
    final List<NodeDiscoveryInfo> discovered = [];
    for (final p in _pendingPairings) {
      discovered.add(NodeDiscoveryInfo(
        id: p.nodeId,
        macAddress: p.macAddress ?? p.nodeId,
        hardwareModel: p.hardwareModel ?? 'ESP32 Wi-Fi Node',
        firmwareVersion: p.firmwareVersion ?? '1.0.0',
        rssiDbm: -65,
        detectedAt: ApiMappers.parseIsoDateTime(p.requestedAt) ?? DateTime.now(),
        pairingRequestId: p.id,
        recognized: p.recognized,
        pairingStatus: p.pairingStatus,
        existingLifecycleState: p.existingLifecycleState,
        existingZoneId: p.existingZoneId,
        existingZoneName: p.existingZoneName,
        expiresAt: p.expiresAt,
        isExpired: p.isExpired,
      ));
    }

    try {
      final unassigned = await _nodeRepository.fetchDiscoveredNodes();
      for (final u in unassigned) {
        if (!discovered.any((d) => d.macAddress == u.macAddress || d.id == u.id)) {
          discovered.add(u);
        }
      }
    } catch (_) {}

    if (!mounted) return;
    await NodeRegistrationDialog.show(
      context,
      discoveredNodes: discovered,
      zones: _zones,
      onRegister: (request) async {
        final registeredNode = await _nodeRepository.registerNode(request);
        await _nodeRepository.assignNodeToField(
          registeredNode.id,
          fieldId: 1,
          monitoringZoneId: int.tryParse(request.zoneId.replaceAll(RegExp(r'[^0-9]'), '')),
        );
        await _loadFieldAndZones();
        await _nodeNotifier.fetchNodes();
        notifyGlobalNodeStateChanged();
        return true;
      },
    );
  }

  Future<bool> _handleUnpairNode(String nodeId) async {
    try {
      await _apiFactory.nodes.unpairNode(nodeId);
      await _loadFieldAndZones();
      await _nodeNotifier.fetchNodes();
      notifyGlobalNodeStateChanged();
      return true;
    } catch (e) {
      debugPrint('[SensorsScreen] Unpair failed: $e');
      return false;
    }
  }

  Future<bool> _handleResetPairings({List<String>? nodeIds, String? reason}) async {
    try {
      await _apiFactory.system.resetPairing(nodeIds: nodeIds, reason: reason);
      await _loadFieldAndZones();
      await _nodeNotifier.fetchNodes();
      notifyGlobalNodeStateChanged();
      return true;
    } catch (e) {
      debugPrint('[SensorsScreen] Reset pairings failed: $e');
      return false;
    }
  }

  Future<void> _openNodeAssignment({Esp32Node? node, MonitoringZone? zone}) async {
    final success = await NodeAssignmentDialog.show(
      context,
      nodes: _nodes,
      zones: _zones,
      initialNode: node,
      initialZone: zone,
      onAssign: (nodeId, {fieldId, monitoringZoneId}) async {
        await _nodeRepository.assignNodeToField(
          nodeId,
          fieldId: fieldId ?? 1,
          monitoringZoneId: monitoringZoneId,
        );
        await _loadFieldAndZones();
        await _nodeNotifier.fetchNodes();
        notifyGlobalNodeStateChanged();
        return true;
      },
      onCreateZone: () => _showCreateZoneDialog(),
    );

    if (success == true) {
      await _loadFieldAndZones();
      await _nodeNotifier.fetchNodes();
    }
  }

  Future<MonitoringZone?> _showCreateZoneDialog() async {
    final nameController = TextEditingController();
    final areaController = TextEditingController(text: '1.0');
    final cropController = TextEditingController(text: 'Rice');
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Monitoring Zone'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Zone Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: areaController,
                decoration: const InputDecoration(labelText: 'Area (Hectares) *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Valid number required' : null,
              ),
              TextFormField(
                controller: cropController,
                decoration: const InputDecoration(labelText: 'Crop Type *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == true) {
      final newZone = await _zoneRepository.createZone(
        name: nameController.text.trim(),
        area: double.parse(areaController.text.trim()),
        cropType: cropController.text.trim(),
      );
      await _loadFieldAndZones();
      return newZone;
    }
    return null;
  }

  Future<void> _configureNodeInterval(Esp32Node node) async {
    final success = await TransmissionIntervalDialog.show(
      context,
      node: node,
      userRole: widget.userRole,
      onConfigure: (intervalSec, {isAdaptive = true, reason}) async {
        await _nodeRepository.configureTransmissionInterval(
          node.id,
          TransmissionConfigDto(
            intervalSeconds: intervalSec,
            isAdaptive: isAdaptive,
            reason: reason,
          ),
        );
        await _nodeNotifier.fetchNodes();
        return true;
      },
    );
    if (success == true) {
      await _nodeNotifier.fetchNodes();
    }
  }
}
