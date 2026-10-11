import 'package:flutter/material.dart';
import '../../../core/api/api_dtos.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/widgets.dart';
import '../../control/domain/models/control_enums.dart';
import '../../irrigation/data/repositories/irrigation_repository.dart';
import '../../irrigation/domain/models/centralized_irrigation.dart';
import '../../nodes/data/repositories/node_repository.dart';
import '../../nodes/domain/models/models.dart';
import '../../nodes/presentation/widgets/node_registration_dialog.dart';
import '../../nodes/presentation/widgets/spatial_field_canvas_visualizer.dart';

import '../../nodes/presentation/widgets/transmission_interval_dialog.dart';
import '../../zones/data/datasources/zone_data_source.dart';
import '../../zones/data/repositories/zone_repository.dart';
import '../../zones/domain/models/monitoring_zone.dart';
import 'widgets/dynamic_zone_grid_visualizer.dart';
import 'widgets/field_header_overview_card.dart';
import 'widgets/zone_detail_bottom_sheet.dart';

enum FieldVisualizationMode { matrix, spatial }

class FieldScreen extends StatefulWidget {
  final VoidCallback? onNavigateToControl;
  final ZoneRepository? repository;
  final NodeRepository? nodeRepository;
  final IrrigationRepository? irrigationRepository;
  final ControlUserRole userRole;

  const FieldScreen({
    super.key,
    this.onNavigateToControl,
    this.repository,
    this.nodeRepository,
    this.irrigationRepository,
    this.userRole = ControlUserRole.operator,
  });

  @override
  State<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends State<FieldScreen> {
  late final ZoneRepository _zoneRepository;
  late final NodeRepository _nodeRepository;
  late final IrrigationRepository _irrigationRepository;

  bool _isLoading = true;
  String? _errorMessage;
  List<MonitoringZone> _zones = [];
  List<Esp32Node> _nodes = [];
  CentralizedIrrigation? _centralIrrigation;
  ZoneMockState _currentMockState = ZoneMockState.normal;
  FieldVisualizationMode _visMode = FieldVisualizationMode.matrix;
  String? _selectedZoneCode;

  @override
  void initState() {
    super.initState();
    _zoneRepository = widget.repository ?? ZoneRepositoryImpl();
    _nodeRepository = widget.nodeRepository ?? MockNodeRepository();
    _irrigationRepository = widget.irrigationRepository ?? IrrigationRepositoryImpl();
    _loadZones();
  }

  Future<void> _loadZones({ZoneMockState? overrideState}) async {
    final stateToFetch = overrideState ?? _currentMockState;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentMockState = stateToFetch;
    });

    try {
      final zones = await _zoneRepository.fetchMonitoringZones(
        mockState: stateToFetch,
      );
      final nodes = await _nodeRepository.fetchNodes();
      final sys = await _irrigationRepository.fetchSystemStatus();
      if (mounted) {
        setState(() {
          _zones = zones;
          _nodes = nodes;
          _centralIrrigation = sys;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _handleZoneSelection(MonitoringZone zone) {
    setState(() => _selectedZoneCode = zone.code);
    final assignedNodes = _nodes
        .where(
          (n) =>
              zone.assignedNodeIds.contains(n.id) ||
              n.assignedZoneId == zone.id ||
              n.assignedZoneId == zone.code,
        )
        .toList();
    ZoneDetailBottomSheet.show(
      context,
      zone: zone,
      assignedNodes: assignedNodes,
      userRole: widget.userRole,
      onConfigureInterval: (node) => _configureNodeInterval(node),
    );
  }

  Future<void> _configureNodeInterval(Esp32Node node) async {
    await TransmissionIntervalDialog.show(
      context,
      node: node,
      userRole: widget.userRole,
      onConfigure: (interval, {bool isAdaptive = false, String? reason}) async {
        await _nodeRepository.configureTransmissionInterval(
          node.id,
          TransmissionConfigDto(
            intervalSeconds: interval,
            isAdaptive: isAdaptive,
            reason: reason,
          ),
        );
        await _loadZones();
        return true;
      },
    );
  }

  Future<void> _openNodeScanner() async {
    final discovered = await _nodeRepository.fetchDiscoveredNodes();
    if (!mounted) return;
    final registered = await NodeRegistrationDialog.show(
      context,
      discoveredNodes: discovered,
      onRegister: (request) async {
        await _nodeRepository.registerNode(request);
        await _loadZones();
        return true;
      },
    );
    if (registered == true) {
      await _loadZones();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const LoadingStateWidget(
        message: 'Loading Field Zone Telemetry...',
      );
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: _buildHeader(theme),
          ),
          Expanded(
            child: ErrorStateWidget(
              title: 'Gateway Telemetry Error',
              message: _errorMessage!,
              onRetry: () => _loadZones(overrideState: ZoneMockState.normal),
            ),
          ),
        ],
      );
    }

    if (_zones.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: _buildHeader(theme),
          ),
          Expanded(
            child: EmptyStateWidget(
              title: 'No Monitoring Zones',
              message: 'No sensor nodes deployed or active in this field.',
              actionLabel: 'Reset Telemetry',
              onAction: () => _loadZones(overrideState: ZoneMockState.normal),
            ),
          ),
        ],
      );
    }

    final isStale = _currentMockState == ZoneMockState.stale;

    return RefreshIndicator(
      onRefresh: () => _loadZones(),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: AppDimensions.spaceSm),
            // Mode Selector Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.grid_view, size: 16),
                    label: const Text('Matrix Grid'),
                    selected: _visMode == FieldVisualizationMode.matrix,
                    onSelected: (_) => setState(
                      () => _visMode = FieldVisualizationMode.matrix,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  ChoiceChip(
                    avatar: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Spatial Field Map'),
                    selected: _visMode == FieldVisualizationMode.spatial,
                    onSelected: (_) => setState(
                      () => _visMode = FieldVisualizationMode.spatial,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            _buildCentralActuatorsCard(_centralIrrigation),
            const SizedBox(height: AppDimensions.spaceMd),
            FieldHeaderOverviewCard(
              zones: _zones,
              isStale: isStale,
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            if (_visMode == FieldVisualizationMode.spatial)
              SpatialFieldCanvasVisualizer(
                nodes: _nodes,
                onNodeSelected: (node) {
                  final zone = _zones
                      .where(
                        (z) =>
                            z.id == node.assignedZoneId ||
                            z.code == node.assignedZoneId ||
                            z.code.toLowerCase() ==
                                node.assignedZoneId
                                    ?.toLowerCase()
                                    .replaceAll('zone-', ''),
                      )
                      .firstOrNull;
                  if (zone != null) {
                    _handleZoneSelection(zone);
                  }
                },
                onConfigureInterval: (node) => _configureNodeInterval(node),
              )
            else
              DynamicZoneGridVisualizer(
                zones: _zones,
                selectedZoneCode: _selectedZoneCode,
                onZoneSelected: _handleZoneSelection,
              ),
            const SizedBox(height: AppDimensions.spaceLg),
            Text(
              'Detailed Zone Telemetry List',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _zones.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppDimensions.spaceMd),
              itemBuilder: (context, index) {
                return _buildZoneCard(_zones[index]);
              },
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            _buildMonitoringNoticeCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AquaSense Field Monitoring',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Independent Telemetry Monitoring Zones',
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        PopupMenuButton<ZoneMockState>(
          icon: const Icon(Icons.tune, color: AppColors.primary),
          tooltip: 'Simulate UI States',
          onSelected: (ZoneMockState state) => _loadZones(overrideState: state),
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: ZoneMockState.normal,
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                  SizedBox(width: 8),
                  Text('Normal State'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: ZoneMockState.stale,
              child: Row(
                children: [
                  Icon(Icons.history, size: 18, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text('Stale Telemetry'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: ZoneMockState.unavailable,
              child: Row(
                children: [
                  Icon(Icons.sensors_off, size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Gateway Offline'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: ZoneMockState.empty,
              child: Row(
                children: [
                  Icon(Icons.inbox, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Empty State'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: ZoneMockState.error,
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Error State'),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: _openNodeScanner,
          icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
          tooltip: 'Scan & Register Dynamic Node',
        ),
        IconButton(
          onPressed: () => _loadZones(),
          icon: const Icon(Icons.sync, color: AppColors.primary),
          tooltip: 'Sync Field Data',
        ),
      ],
    );
  }

  Widget _buildMonitoringNoticeCard(ThemeData theme) {
    return AquaCard(
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Read-Only Monitoring Zones',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.zoneNotice,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(MonitoringZone zone) {
    return AquaCard(
      onTap: () => _handleZoneSelection(zone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spaceSm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Text(
                        zone.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Text(
                        zone.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              StatusBadge.zoneStatus(zone.status.name, compact: true),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: SensorMetricTile(
                  label: 'Soil Moisture',
                  value: '${zone.soilMoisturePercent.toStringAsFixed(1)}%',
                  icon: Icons.water,
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Water Level',
                  value: zone.waterLevelCm.toStringAsFixed(1),
                  unit: 'cm',
                  icon: Icons.waves,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Row(
            children: [
              Expanded(
                child: SensorMetricTile(
                  label: 'Signal (RSSI)',
                  value: '${zone.rssiDbm}',
                  unit: 'dBm',
                  icon: Icons.cell_tower,
                  color: AppColors.primaryLight,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Sensor Battery',
                  value: zone.batteryPercent.toString(),
                  unit: '%',
                  icon: zone.batteryPercent < 20
                      ? Icons.battery_alert
                      : Icons.battery_full,
                  color: zone.batteryPercent < 20
                      ? AppColors.error
                      : AppColors.deviceBatteryGood,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCentralActuatorsCard(CentralizedIrrigation? sys) {
    if (sys == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final pumpText = sys.mainPumpState == PumpState.active
        ? 'PUMPING'
        : (sys.mainPumpState == PumpState.warning
            ? 'WARNING'
            : (sys.mainPumpState == PumpState.offline ? 'OFFLINE' : 'OFF'));
    final valveText = sys.distributionValveState == ValveState.open
        ? 'OPEN'
        : (sys.distributionValveState == ValveState.partial ? 'PARTIAL' : 'CLOSED');
    final ctrlText = sys.mainPumpState == PumpState.offline ? 'OFFLINE' : 'ONLINE';

    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.settings_remote_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Text(
                        'Central Field Hardware Status',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              StatusBadge.deviceStatus(ctrlText, compact: true),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          const Divider(),
          const SizedBox(height: AppDimensions.spaceSm),
          Row(
            children: [
              Expanded(
                child: SensorMetricTile(
                  label: 'Main Pump',
                  value: pumpText,
                  icon: Icons.power_settings_new,
                  color: sys.mainPumpState == PumpState.active ? AppColors.pumpActive : AppColors.primary,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Main Valve',
                  value: valveText,
                  icon: Icons.alt_route,
                  color: sys.distributionValveState == ValveState.open ? AppColors.valveOpen : AppColors.primary,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Flow Rate',
                  value: sys.flowRateLitersPerMin.toStringAsFixed(1),
                  unit: 'L/min',
                  icon: Icons.speed,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
