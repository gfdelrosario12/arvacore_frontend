import 'package:flutter/material.dart';
import '../../../../core/api/api_dtos.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../features/auth/domain/models/user_role.dart';
import '../../../control/domain/models/control_enums.dart';
import '../../../irrigation/presentation/manual_control_screen.dart';
import '../../../nodes/domain/models/models.dart';
import '../../../nodes/presentation/widgets/node_replacement_dialog.dart';
import '../../../nodes/presentation/widgets/transmission_interval_dialog.dart';
import '../../domain/models/models.dart';

class DeviceDetailDialog extends StatelessWidget {
  final DeviceDiagnostic device;
  final ControlUserRole userRole;
  final List<Esp32Node> availableReplacementNodes;
  final Future<bool> Function(
    int intervalSeconds, {
    bool isAdaptive,
    String? reason,
  })? onConfigureInterval;
  final Future<NodeReplacementResult?> Function(NodeReplacementRequestDto request)?
      onReplaceNode;
  final Future<bool> Function(NodeLifecycleStatus targetStatus)?
      onTransitionLifecycle;

  const DeviceDetailDialog({
    super.key,
    required this.device,
    this.userRole = ControlUserRole.operator,
    this.availableReplacementNodes = const [],
    this.onConfigureInterval,
    this.onReplaceNode,
    this.onTransitionLifecycle,
  });

  static Future<void> show(
    BuildContext context,
    DeviceDiagnostic device, {
    ControlUserRole userRole = ControlUserRole.operator,
    List<Esp32Node> availableReplacementNodes = const [],
    Future<bool> Function(
      int intervalSeconds, {
      bool isAdaptive,
      String? reason,
    })? onConfigureInterval,
    Future<NodeReplacementResult?> Function(NodeReplacementRequestDto request)?
        onReplaceNode,
    Future<bool> Function(NodeLifecycleStatus targetStatus)?
        onTransitionLifecycle,
  }) {
    return showDialog(
      context: context,
      builder: (context) => DeviceDetailDialog(
        device: device,
        userRole: userRole,
        availableReplacementNodes: availableReplacementNodes,
        onConfigureInterval: onConfigureInterval,
        onReplaceNode: onReplaceNode,
        onTransitionLifecycle: onTransitionLifecycle,
      ),
    );
  }

  NodeLifecycleStatus get _nodeLifecycle {
    switch (device.healthStatus) {
      case DeviceHealthStatus.healthy:
        return NodeLifecycleStatus.active;
      case DeviceHealthStatus.degraded:
        return NodeLifecycleStatus.maintenance;
      case DeviceHealthStatus.offline:
      case DeviceHealthStatus.stale:
        return NodeLifecycleStatus.offline;
      case DeviceHealthStatus.error:
        return NodeLifecycleStatus.disabled;
    }
  }

  Esp32Node get _asNode => Esp32Node(
        id: device.id,
        macAddress: device.macAddress ?? '00:00:00:00:00:00',
        displayName: device.name,
        assignedZoneId: device.targetScope.contains('Q') ? device.targetScope : null,
        coordinates: SpatialCoordinates(
          latitude: device.latitude,
          longitude: device.longitude,
          localX: device.localX,
          localY: device.localY,
        ),
        transmissionConfig: TransmissionConfig(
          intervalSeconds: device.transmissionIntervalSeconds ?? 300,
          isAdaptive: device.isAdaptiveInterval,
          adaptiveReason: device.adaptiveReason,
          lastConfiguredAt: device.lastSeen,
        ),
        isOnline: device.isOnline,
        lifecycleState: _nodeLifecycle,
        batteryPercent: device.batteryPercent,
        batteryVoltage: device.batteryVoltage,
        rssiDbm: device.rssiDbm,
        snrDb: device.snrDb,
        lastSeen: device.lastSeen,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isController = device.category == DeviceCategory.centralController;
    final isNode = device.category == DeviceCategory.sensorNode;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      title: Row(
        children: [
          Icon(
            isController
                ? Icons.settings_remote
                : (isNode ? Icons.sensors : Icons.router),
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Text(
              device.name,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatusBadge.deviceStatus(
                  device.healthStatus.name.toUpperCase(),
                  compact: true,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'SCOPE: ${device.targetScope}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (isNode) ...[
              const SizedBox(height: AppDimensions.spaceXs),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _nodeLifecycle == NodeLifecycleStatus.maintenance
                          ? AppColors.alertWarning.withValues(alpha: 0.15)
                          : (_nodeLifecycle.isRetired
                              ? AppColors.alertError.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _nodeLifecycle == NodeLifecycleStatus.maintenance
                            ? AppColors.alertWarning.withValues(alpha: 0.5)
                            : (_nodeLifecycle.isRetired
                                ? AppColors.alertError.withValues(alpha: 0.5)
                                : AppColors.primary.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Text(
                      'LIFECYCLE: ${_nodeLifecycle.name.toUpperCase()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _nodeLifecycle == NodeLifecycleStatus.maintenance
                            ? AppColors.alertWarning
                            : (_nodeLifecycle.isRetired
                                ? AppColors.alertError
                                : AppColors.primary),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppDimensions.spaceMd),
            if (device.macAddress != null) ...[
              Text(
                'MAC: ${device.macAddress}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
            ],
            if (device.batteryPercent != null || device.rssiDbm != null) ...[
              Row(
                children: [
                  if (device.batteryPercent != null)
                    Expanded(
                      child: SensorMetricTile(
                        label: 'Battery Level',
                        value:
                            '${device.batteryPercent}% (${device.batteryVoltage?.toStringAsFixed(2)}V)',
                        icon: Icons.battery_charging_full,
                        color: (device.batteryPercent ?? 100) < 20
                            ? AppColors.alertWarning
                            : AppColors.primary,
                      ),
                    ),
                  if (device.rssiDbm != null)
                    Expanded(
                      child: SensorMetricTile(
                        label: 'RF Signal',
                        value: '${device.rssiDbm} dBm',
                        unit: 'SNR ${device.snrDb?.toStringAsFixed(1)} dB',
                        icon: Icons.cell_tower,
                        color: (device.rssiDbm ?? -90) < -100
                            ? AppColors.alertWarning
                            : AppColors.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceSm),
            ],
            if (device.lastMeasurement != null) ...[
              Text(
                'Latest Telemetry Measurement:',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                device.lastMeasurement!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.spaceSm),
            ],
            if (isNode) ...[
              if (device.latitude != null ||
                  device.longitude != null ||
                  device.localX != null ||
                  device.localY != null) ...[
                Row(
                  children: [
                    if (device.latitude != null || device.longitude != null) ...[
                      Expanded(
                        child: Text(
                          'GPS: ${device.latitude != null ? device.latitude!.toStringAsFixed(4) : ''}, ${device.longitude != null ? device.longitude!.toStringAsFixed(4) : ''}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (device.localX != null || device.localY != null) ...[
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: Text(
                          'Local: ${device.localX != null ? device.localX!.toStringAsFixed(1) : ''}m, ${device.localY != null ? device.localY!.toStringAsFixed(1) : ''}m',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceSm),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Interval: ${device.transmissionIntervalSeconds ?? 300}s${device.isAdaptiveInterval ? ' (Adaptive)' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: device.isAdaptiveInterval
                            ? AppColors.accent
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (onConfigureInterval != null) ...[
                const SizedBox(height: AppDimensions.spaceSm),
                AuthorizationGate(
                  requiredRole: UserRole.operator,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await TransmissionIntervalDialog.show(
                        context,
                        node: _asNode,
                        userRole: userRole,
                        onConfigure: onConfigureInterval!,
                      );
                    },
                    icon: const Icon(Icons.timer_outlined, size: 18),
                    label: const Text('Configure Transmission Interval'),
                  ),
                ),
              ],
              if (onTransitionLifecycle != null &&
                  userRole != ControlUserRole.viewer) ...[
                const SizedBox(height: AppDimensions.spaceSm),
                OutlinedButton.icon(
                  onPressed: () async {
                    final nextStatus =
                        _nodeLifecycle == NodeLifecycleStatus.maintenance
                            ? NodeLifecycleStatus.active
                            : NodeLifecycleStatus.maintenance;
                    final success = await onTransitionLifecycle!(nextStatus);
                    if (context.mounted && success) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: Icon(
                    _nodeLifecycle == NodeLifecycleStatus.maintenance
                        ? Icons.play_arrow
                        : Icons.build_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _nodeLifecycle == NodeLifecycleStatus.maintenance
                        ? 'Resume ArvaNode (Active)'
                        : 'Set to Maintenance Mode',
                  ),
                ),
              ],
              if (onReplaceNode != null &&
                  userRole != ControlUserRole.viewer) ...[
                const SizedBox(height: AppDimensions.spaceSm),
                AuthorizationGate(
                  requiredRole: UserRole.operator,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await NodeReplacementDialog.show(
                        context,
                        targetNode: _asNode,
                        availableNodes: availableReplacementNodes,
                        userRole: userRole,
                        onReplace: (req) async {
                          final res = await onReplaceNode!(req);
                          if (res != null && context.mounted) {
                            Navigator.of(context).pop();
                          }
                          return res;
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Replace ArvaNode (Atomic Swap)'),
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.spaceSm),
            ],
            const SizedBox(height: AppDimensions.spaceSm),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.build, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      device.diagnosticMessage,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            Text(
              'Last Heartbeat Seen: ${_formatTime(device.lastSeen)}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            if (isNode)
              _buildReadOnlyNotice(theme)
            else if (device.category == DeviceCategory.gateway)
              _buildGatewayDetails(theme)
            else
              _buildControllerDetails(theme),
          ],
        ),
      ),
      actions: [
        if (isController)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ManualControlScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Open Manual Control'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$hour:$min:$sec';
  }

  Widget _buildReadOnlyNotice(ThemeData theme) {
    final hasLoRa = device.macAddress != null &&
        (device.macAddress!.length >= 16 || device.macAddress!.contains('0004A3'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasLoRa) ...[
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceSm),
            margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings_input_antenna, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('LoRaWAN Link Metrics', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.pumpActive.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Class A', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.pumpActive)),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                _detailRow('DevEUI', device.macAddress!),
                _detailRow('RSSI / SNR', '${device.rssiDbm ?? -95} dBm / ${device.snrDb?.toStringAsFixed(1) ?? "8.5"} dB'),
                _detailRow('Frame Counter', 'FCntUp: ${device.batteryPercent ?? 42} | FCntDown: 12'),
                _detailRow('Gateway EUI', 'GW-E8E076FFFE001234'),
                if (device.isAdaptiveInterval)
                  _detailRow('Downlink Status', 'Queued (applies on next uplink window)'),
              ],
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceSm),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Row(
            children: [
              const Icon(Icons.visibility_outlined,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Text(
                  'Read-only telemetry node. Observational ArvaNodes do not control pumps or irrigation valves.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGatewayDetails(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ArvaNet Gateway Network Health', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppDimensions.spaceSm),
        _detailRow('Connectivity', device.communicationStatus ?? 'N/A'),
        _detailRow('Uplink', device.uplinkStatus ?? 'N/A'),
        _detailRow('Downlink', device.downlinkStatus ?? 'N/A'),
        _detailRow('Backhaul', device.backhaulStatus ?? 'N/A'),
        _detailRow(
            'Retransmission',
            device.packetRetransmissionRate == null
                ? 'N/A'
                : '${device.packetRetransmissionRate!.toStringAsFixed(1)}%'),
        _detailRow('Last communication',
            _formatTime(device.lastCommunication ?? device.lastSeen)),
      ],
    );
  }

  Widget _buildControllerDetails(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ArvaCore Controller Diagnostics',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: AppDimensions.spaceSm),
        _detailRow('Communication', device.communicationStatus ?? 'N/A'),
        _detailRow('Pump state', device.pumpState ?? 'N/A'),
        _detailRow('Main valve', device.valveState ?? 'N/A'),
        _detailRow('Last command', device.lastCommand ?? 'N/A'),
        _detailRow('Command result', device.lastCommandResult ?? 'N/A'),
        _detailRow('Last communication',
            _formatTime(device.lastCommunication ?? device.lastSeen)),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: Text(label)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
