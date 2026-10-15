import 'package:flutter/material.dart';
import '../../../core/api/api_dtos.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/widgets.dart';
import '../../../features/auth/domain/models/user_role.dart';
import '../../../core/api/api_factory.dart';
import '../../control/domain/models/control_enums.dart';
import '../../nodes/data/repositories/api_node_repository.dart';
import '../../nodes/data/repositories/node_repository.dart';
import '../../nodes/domain/models/models.dart';
import '../../nodes/presentation/widgets/node_registration_dialog.dart';
import '../domain/models/models.dart';
import 'providers/diagnostics_provider.dart';
import 'widgets/device_detail_dialog.dart';

class DeviceDiagnosticsScreen extends StatefulWidget {
  final DiagnosticsNotifier? notifier;
  final NodeRepository? nodeRepository;

  const DeviceDiagnosticsScreen({
    super.key,
    this.notifier,
    this.nodeRepository,
  });

  @override
  State<DeviceDiagnosticsScreen> createState() => _DeviceDiagnosticsScreenState();
}

class _DeviceDiagnosticsScreenState extends State<DeviceDiagnosticsScreen> {
  late DiagnosticsNotifier _notifier;
  late final NodeRepository _nodeRepository;
  List<NodeDiscoveryInfo> _discoveredNodes = [];
  List<Esp32Node> _allNodes = [];

  @override
  void initState() {
    super.initState();
    _notifier = widget.notifier ?? DiagnosticsNotifier();
    _nodeRepository = widget.nodeRepository ??
        ApiNodeRepository(ApiRepositoryFactory().nodes);
    _notifier.addListener(_onStateChanged);
    _loadDiscoveredNodes();
  }

  Future<void> _loadDiscoveredNodes() async {
    try {
      final List<NodeDiscoveryInfo> disc = [];
      try {
        final pending = await ApiRepositoryFactory().system.getPendingPairingRequests();
        for (final p in pending) {
          disc.add(NodeDiscoveryInfo(
            id: p.nodeId,
            macAddress: p.macAddress ?? p.nodeId,
            hardwareModel: p.hardwareModel ?? 'ESP32 Wi-Fi Node',
            firmwareVersion: p.firmwareVersion ?? '1.0.0',
            rssiDbm: -65,
            detectedAt: DateTime.tryParse(p.requestedAt) ?? DateTime.now(),
            pairingRequestId: p.id,
            recognized: p.recognized,
            pairingStatus: p.pairingStatus,
            existingLifecycleState: p.existingLifecycleState,
            existingZoneId: p.existingZoneId,
            existingZoneName: p.existingZoneName,
          ));
        }
      } catch (_) {}

      try {
        final unassigned = await _nodeRepository.fetchDiscoveredNodes();
        for (final u in unassigned) {
          if (!disc.any((d) => d.macAddress == u.macAddress || d.id == u.id)) {
            disc.add(u);
          }
        }
      } catch (_) {}

      final nodes = await _nodeRepository.fetchNodes();
      if (mounted) {
        setState(() {
          _discoveredNodes = disc;
          _allNodes = nodes;
        });
      }
    } catch (_) {}
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openNodeRegistration() async {
    await _loadDiscoveredNodes();
    if (!mounted) return;
    await NodeRegistrationDialog.show(
      context,
      discoveredNodes: _discoveredNodes,
      onRegister: (request) async {
        try {
          final matching = _discoveredNodes.firstWhere(
            (d) => d.macAddress == request.macAddress,
            orElse: () => _discoveredNodes.first,
          );
          if (matching.pairingRequestId != null) {
            int? zoneNum;
            if (request.zoneId.isNotEmpty) {
              zoneNum = int.tryParse(request.zoneId.replaceAll(RegExp(r'[^0-9]'), ''));
            }
            await ApiRepositoryFactory().system.approvePairingRequest(
              matching.pairingRequestId!,
              nodeId: request.displayName.isNotEmpty ? request.displayName : matching.id,
              identityType: 'MAC_ADDRESS',
              identityValue: request.macAddress,
              macAddress: request.macAddress,
              hardwareModel: matching.hardwareModel,
              monitoringZoneId: zoneNum,
            );
          } else {
            await _nodeRepository.registerNode(request);
          }
          _notifier.fetchDiagnostics();
          _loadDiscoveredNodes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Registered node ${request.displayName}')),
            );
          }
          return true;
        } catch (_) {
          return false;
        }
      },
    );
  }

  @override
  void dispose() {
    if (widget.notifier == null) {
      _notifier.dispose();
    } else {
      _notifier.removeListener(_onStateChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _notifier.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Diagnostics'),
        actions: [
          AuthorizationGate(
            requiredRole: UserRole.operator,
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Register ESP32 Node',
              onPressed: _openNodeRegistration,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _notifier.fetchDiagnostics();
              _loadDiscoveredNodes();
            },
            tooltip: 'Refresh Diagnostics',
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: RefreshIndicator(
          onRefresh: () => _notifier.fetchDiagnostics(),
          child: state.isLoading && state.devices.isEmpty
              ? const LoadingStateWidget(message: 'Scanning system hardware diagnostics...')
              : state.errorMessage != null && state.devices.isEmpty
                  ? ErrorStateWidget(
                      message: state.errorMessage!,
                      onRetry: _notifier.fetchDiagnostics,
                    )
                  : state.devices.isEmpty
                      ? EmptyStateWidget(
                          title: 'No Devices Registered',
                          message: 'No monitoring nodes, gateway, or central controller telemetry is available.',
                          actionLabel: 'Retry Scan',
                          onAction: _notifier.fetchDiagnostics,
                        )
                      : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.errorMessage != null)
                        _buildInlineWarning(state.errorMessage!),
                      if (state.devices.any((device) => device.healthStatus == DeviceHealthStatus.stale))
                        _buildInlineWarning('Some device telemetry is stale. Check last-seen times before taking action.'),
                      // System Health Header
                      _buildSystemHealthHeader(state),
                      const SizedBox(height: AppDimensions.spaceMd),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('All Devices'),
                              selected: state.categoryFilter == null,
                              onSelected: (_) => _notifier.setCategoryFilter(null),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: Text('Nodes (${state.sensorNodes.length})'),
                              selected: state.categoryFilter == DeviceCategory.sensorNode,
                              onSelected: (sel) => _notifier.setCategoryFilter(sel ? DeviceCategory.sensorNode : null),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('LoRa Gateway'),
                              selected: state.categoryFilter == DeviceCategory.gateway,
                              onSelected: (sel) => _notifier.setCategoryFilter(sel ? DeviceCategory.gateway : null),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Central Controller'),
                              selected: state.categoryFilter == DeviceCategory.centralController,
                              onSelected: (sel) => _notifier.setCategoryFilter(sel ? DeviceCategory.centralController : null),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),

                      // Monitoring Nodes Section
                      if (state.categoryFilter == null || state.categoryFilter == DeviceCategory.sensorNode) ...[
                        _buildSectionHeader('Sensor Telemetry Nodes (${state.sensorNodes.length})', 'Read-Only Monitoring Nodes'),
                        const SizedBox(height: AppDimensions.spaceSm),
                        ...state.sensorNodes.map((node) => _buildDeviceCard(node)),
                        const SizedBox(height: AppDimensions.spaceMd),
                      ],

                      // Gateway Section
                      if ((state.categoryFilter == null || state.categoryFilter == DeviceCategory.gateway) &&
                          state.gateway != null) ...[
                        _buildSectionHeader('LoRaWAN Network Gateway', 'Field Wireless Infrastructure'),
                        const SizedBox(height: AppDimensions.spaceSm),
                        _buildDeviceCard(state.gateway!),
                        const SizedBox(height: AppDimensions.spaceMd),
                      ],

                      // Central Controller Section
                      if ((state.categoryFilter == null || state.categoryFilter == DeviceCategory.centralController) &&
                          state.centralController != null) ...[
                        _buildSectionHeader('Central Irrigation Controller', 'Central Field Actuators (Scope: ENTIRE FIELD)'),
                        const SizedBox(height: AppDimensions.spaceSm),
                        _buildDeviceCard(state.centralController!),
                        const SizedBox(height: AppDimensions.spaceMd),
                      ],
                      if (state.filteredDevices.isEmpty)
                        const EmptyStateWidget(
                          title: 'No Matching Devices',
                          message: 'No diagnostics match the selected category filter.',
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSystemHealthHeader(DiagnosticsStateData state) {
    final theme = Theme.of(context);
    final isAllHealthy = state.warningCount == 0 && state.errorCount == 0;

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
                  Icon(
                    isAllHealthy ? Icons.health_and_safety : Icons.warning_amber_rounded,
                    color: isAllHealthy ? AppColors.pumpActive : AppColors.alertWarning,
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  Expanded(
                    child: Text(
                      'System Health Overview',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              StatusBadge.deviceStatus(
                isAllHealthy ? 'OPTIMAL' : 'DEGRADED',
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          Row(
            children: [
              Expanded(
                child: SensorMetricTile(
                  label: 'Healthy Devices',
                  value: '${state.healthyCount}/${state.totalDevices}',
                  icon: Icons.check_circle,
                  color: AppColors.pumpActive,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Warnings',
                  value: '${state.warningCount}',
                  icon: Icons.warning,
                  color: AppColors.alertWarning,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Offline/Faults',
                  value: '${state.errorCount}',
                  icon: Icons.error,
                  color: AppColors.alertError,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildDeviceCard(DeviceDiagnostic device) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      child: AquaCard(
        child: InkWell(
          onTap: () => DeviceDetailDialog.show(
            context,
            device,
            userRole: ControlUserRole.operator,
            availableReplacementNodes: _allNodes
                .where((n) =>
                    n.id != device.id &&
                    n.lifecycleState != NodeLifecycleStatus.decommissioned)
                .toList(),
            onConfigureInterval: device.category == DeviceCategory.sensorNode
                ? (interval, {bool isAdaptive = false, String? reason}) async {
                    try {
                      await _nodeRepository.configureTransmissionInterval(
                        device.id,
                        TransmissionConfigDto(
                          intervalSeconds: interval,
                          isAdaptive: isAdaptive,
                          reason: reason,
                        ),
                      );
                      await _notifier.fetchDiagnostics();
                      return true;
                    } catch (_) {
                      return false;
                    }
                  }
                : null,
            onReplaceNode: device.category == DeviceCategory.sensorNode
                ? (req) async {
                    try {
                      final result =
                          await _nodeRepository.executeNodeReplacement(
                        oldNodeId: device.id,
                        replacementNodeId: req.replacementNodeId,
                        reason: req.reason,
                        transferCalibration: req.transferCalibration,
                      );
                      await _notifier.fetchDiagnostics();
                      await _loadDiscoveredNodes();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Successfully replaced node ${result.replacedNodeId} with ${result.replacementNodeId}',
                            ),
                          ),
                        );
                      }
                      return result;
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to replace node: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      return null;
                    }
                  }
                : null,
            onTransitionLifecycle: device.category == DeviceCategory.sensorNode
                ? (targetStatus) async {
                    try {
                      await _nodeRepository.transitionLifecycle(
                        nodeId: device.id,
                        targetStatus: targetStatus,
                      );
                      await _notifier.fetchDiagnostics();
                      await _loadDiscoveredNodes();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Updated ${device.name} status to ${targetStatus.name}',
                            ),
                          ),
                        );
                      }
                      return true;
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update status: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                      return false;
                    }
                  }
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        device.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    StatusBadge.deviceStatus(
                      device.healthStatus.name.toUpperCase(),
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  device.diagnosticMessage,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                _buildDeviceMetrics(device),
                const SizedBox(height: AppDimensions.spaceSm),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: AppDimensions.spaceXs,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SCOPE: ${device.targetScope}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    if (device.transmissionIntervalSeconds != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: device.isAdaptiveInterval
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : AppColors.primaryLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'INTERVAL: ${device.transmissionIntervalSeconds}s${device.isAdaptiveInterval ? ' (ADAPTIVE)' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: device.isAdaptiveInterval ? AppColors.accent : AppColors.primary,
                          ),
                        ),
                      ),
                    if (device.batteryPercent != null)
                      Text(
                        'Battery: ${device.batteryPercent}%',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceMetrics(DeviceDiagnostic device) {
    final rows = <Widget>[
      _buildMetricRow([
        _metricTile('State', device.isOnline ? 'ONLINE' : 'OFFLINE', Icons.power_settings_new),
        _metricTile('Last seen', _formatTime(device.lastSeen), Icons.access_time),
      ]),
    ];

    if (device.category == DeviceCategory.sensorNode) {
      rows.add(_buildMetricRow([
        _metricTile('Battery', device.batteryPercent == null ? 'N/A' : '${device.batteryPercent}%', Icons.battery_full),
        _metricTile('RSSI / SNR', '${device.rssiDbm ?? 'N/A'} / ${device.snrDb?.toStringAsFixed(1) ?? 'N/A'}', Icons.cell_tower),
      ]));
      rows.add(_buildMetricRow([
        _metricTile('Communication', device.communicationStatus ?? 'Telemetry link'),
        _metricTile('Measurement', device.lastMeasurement ?? 'No measurement'),
      ]));
      if (device.transmissionIntervalSeconds != null) {
        rows.add(_buildMetricRow([
          _metricTile(
            'Interval',
            '${device.transmissionIntervalSeconds}s${device.isAdaptiveInterval ? " (Adaptive)" : ""}',
            Icons.timer_outlined,
          ),
          _metricTile(
            'Coordinates',
            device.latitude != null && device.longitude != null
                ? '${device.latitude!.toStringAsFixed(4)}, ${device.longitude!.toStringAsFixed(4)}'
                : (device.localX != null && device.localY != null
                    ? '(${device.localX!.toStringAsFixed(1)}m, ${device.localY!.toStringAsFixed(1)}m)'
                    : 'Unassigned'),
            Icons.location_on_outlined,
          ),
        ]));
      }
    } else if (device.category == DeviceCategory.gateway) {
      rows.add(_buildMetricRow([
        _metricTile('Connectivity', device.communicationStatus ?? (device.isOnline ? 'Connected' : 'Offline'), Icons.wifi),
        _metricTile('Uplink', device.uplinkStatus ?? 'N/A', Icons.upload),
      ]));
      rows.add(_buildMetricRow([
        _metricTile('Downlink', device.downlinkStatus ?? 'N/A', Icons.download),
        _metricTile('Retransmit', device.packetRetransmissionRate == null ? 'N/A' : '${device.packetRetransmissionRate!.toStringAsFixed(1)}%', Icons.sync_problem),
      ]));
      rows.add(_buildMetricRow([
        _metricTile('Backhaul', device.backhaulStatus ?? 'N/A', Icons.cell_tower),
        _metricTile('Last communication', _formatTime(device.lastCommunication ?? device.lastSeen), Icons.access_time),
      ]));
    } else {
      rows.add(_buildMetricRow([
        _metricTile('Pump', device.pumpState ?? 'N/A', Icons.water_drop),
        _metricTile('Main valve', device.valveState ?? 'N/A', Icons.toggle_on),
      ]));
      rows.add(_buildMetricRow([
        _metricTile('Last command', device.lastCommand ?? 'N/A', Icons.send),
        _metricTile('Result', device.lastCommandResult ?? 'N/A', Icons.task_alt),
      ]));
      rows.add(_buildMetricRow([
        _metricTile('Last communication', _formatTime(device.lastCommunication ?? device.lastSeen), Icons.access_time),
        _metricTile('Scope', device.targetScope, Icons.public),
      ]));
    }

    return Column(children: rows);
  }

  Widget _buildMetricRow(List<Widget> metrics) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      child: Row(
        children: metrics.map((metric) => Expanded(child: metric)).toList(),
      ),
    );
  }

  Widget _metricTile(String label, String value, [IconData? icon]) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlineWarning(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.alertWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.alertWarning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.alertWarning),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} $hour:$minute';
  }
}
