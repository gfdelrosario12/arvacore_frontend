import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../control/domain/models/control_enums.dart';
import '../../../nodes/domain/models/models.dart';
import '../../../nodes/presentation/widgets/node_unpair_dialog.dart';
import '../../../zones/domain/models/monitoring_zone.dart'
    as zone_models;
import '../../../zones/presentation/zone_analysis_screen.dart';
import '../../../home/presentation/widgets/ultrasonic_water_level_diagram.dart';

class ZoneDetailBottomSheet extends StatelessWidget {
  final zone_models.MonitoringZone zone;
  final List<Esp32Node> assignedNodes;
  final ControlUserRole userRole;
  final Future<void> Function(Esp32Node node)? onConfigureInterval;
  final void Function(zone_models.MonitoringZone zone, Esp32Node? node)? onAssignNode;
  final Future<void> Function(zone_models.MonitoringZone zone)? onDeleteZone;
  final Future<bool> Function(String nodeId)? onUnpairNode;

  const ZoneDetailBottomSheet({
    super.key,
    required this.zone,
    this.assignedNodes = const [],
    this.userRole = ControlUserRole.operator,
    this.onConfigureInterval,
    this.onAssignNode,
    this.onDeleteZone,
    this.onUnpairNode,
  });

  static void show(
    BuildContext context, {
    required zone_models.MonitoringZone zone,
    List<Esp32Node> assignedNodes = const [],
    ControlUserRole userRole = ControlUserRole.operator,
    Future<void> Function(Esp32Node node)? onConfigureInterval,
    void Function(zone_models.MonitoringZone zone, Esp32Node? node)? onAssignNode,
    Future<void> Function(zone_models.MonitoringZone zone)? onDeleteZone,
    Future<bool> Function(String nodeId)? onUnpairNode,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ZoneDetailBottomSheet(
        zone: zone,
        assignedNodes: assignedNodes,
        userRole: userRole,
        onConfigureInterval: onConfigureInterval,
        onAssignNode: onAssignNode,
        onDeleteZone: onDeleteZone,
        onUnpairNode: onUnpairNode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transmission = zone.transmissionConfig;
    final nodeCount = assignedNodes.length;
    final onlineCount = assignedNodes.where((n) => n.isOnline).length;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppDimensions.spaceMd,
        right: AppDimensions.spaceMd,
        top: AppDimensions.spaceMd,
        bottom: MediaQuery.of(context).padding.bottom + AppDimensions.spaceMd,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            zone.code,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spaceSm),
                          StatusBadge.zoneStatus(zone.status.name, compact: true),
                        ],
                      ),
                      Text(
                        zone.name,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildFreshnessBadge(zone),
                          _buildReliabilityBadge(zone),
                        ],
                      ),
                    ],
                  ),
                ),
                StatusBadge.deviceStatus(
                  assignedNodes.isEmpty
                      ? (zone.isOnline ? 'Online' : 'Offline')
                      : (onlineCount == assignedNodes.length
                          ? 'All Nodes Online'
                          : '$onlineCount/${assignedNodes.length} Online'),
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Metrics overview
            Row(
              children: [
                Expanded(
                  child: SensorMetricTile(
                    label: 'Soil Moisture',
                    value: '${zone.soilMoisturePercent.toStringAsFixed(1)}%',
                    icon: Icons.water_drop,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: SensorMetricTile(
                    label: 'Water Depth',
                    value: '${zone.waterLevelCm.toStringAsFixed(1)} cm',
                    icon: Icons.waves,
                    color: AppColors.accent,
                  ),
                ),
                Expanded(
                  child: SensorMetricTile(
                    label: 'Battery',
                    value: '${zone.batteryPercent}%',
                    icon: Icons.battery_charging_full,
                    color: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Assigned Hardware (${assignedNodes.length})',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (onAssignNode != null || onUnpairNode != null)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (assignedNodes.isNotEmpty && onAssignNode != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.error,
                          ),
                          icon: const Icon(Icons.link_off, size: 16),
                          label: const Text('Deassign'),
                          onPressed: () => onAssignNode!(zone, assignedNodes.firstOrNull),
                        ),
                      if (assignedNodes.isNotEmpty && onUnpairNode != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.error,
                          ),
                          icon: const Icon(Icons.link_off_rounded, size: 16),
                          label: const Text('Unpair Node'),
                          onPressed: () async {
                            final nodeToUnpair = assignedNodes.first;
                            final confirmed = await NodeUnpairConfirmationDialog.show(
                              context,
                              nodeId: nodeToUnpair.id,
                              displayName: nodeToUnpair.displayName,
                              onConfirm: () => onUnpairNode!(nodeToUnpair.id),
                            );
                            if (confirmed == true && context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Node ${nodeToUnpair.displayName.isNotEmpty ? nodeToUnpair.displayName : nodeToUnpair.id} successfully unpaired.',
                                  ),
                                  backgroundColor: AppColors.warning,
                                ),
                              );
                            }
                          },
                        ),
                      if (onAssignNode != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.primary,
                          ),
                          icon: Icon(assignedNodes.isEmpty ? Icons.add_location_alt : Icons.swap_horiz, size: 16),
                          label: Text(assignedNodes.isEmpty ? 'Assign Node' : 'Change Assignment'),
                          onPressed: () => onAssignNode!(zone, assignedNodes.firstOrNull),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceXs),
            if (nodeCount > 0) ...[
              Wrap(
                spacing: AppDimensions.spaceXs,
                runSpacing: AppDimensions.spaceXs,
                children: [
                  ...assignedNodes.map(
                    (node) {
                      final isMaintenance =
                          node.lifecycleState == NodeLifecycleStatus.maintenance;
                      return Chip(
                        avatar: Icon(
                          isMaintenance
                              ? Icons.build
                              : (node.isOnline ? Icons.sensors : Icons.sensors_off),
                          size: 16,
                          color: isMaintenance
                              ? AppColors.alertWarning
                              : (node.isOnline ? AppColors.success : AppColors.error),
                        ),
                        label: Text(
                          isMaintenance
                              ? '${node.displayName} (Maintenance)'
                              : node.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMd),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sensors_off, size: 20, color: AppColors.warning),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Text(
                        'No physical ArvaNode assigned to this position yet.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    if (onAssignNode != null)
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () => onAssignNode!(zone, null),
                        child: const Text('Assign'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
            ],

            // Spatial Coordinates & Transmission Interval
            if (zone.coordinates != null || transmission != null) ...[
              Wrap(
                spacing: AppDimensions.spaceSm,
                runSpacing: AppDimensions.spaceXs,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (zone.coordinates?.hasAnyCoordinates == true)
                    Text(
                      zone.coordinates?.hasLocalCoordinates == true
                          ? 'Local: X ${zone.coordinates!.localX!.toStringAsFixed(1)}m, Y ${zone.coordinates!.localY!.toStringAsFixed(1)}m'
                          : 'GPS: ${zone.coordinates!.latitude!.toStringAsFixed(4)}, ${zone.coordinates!.longitude!.toStringAsFixed(4)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  if (transmission != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          transmission.isAdaptive ? Icons.bolt : Icons.timer,
                          size: 14,
                          color: transmission.isAdaptive
                              ? AppColors.accent
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Interval: ${transmission.intervalSeconds}s ${transmission.isAdaptive ? '(Adaptive)' : '(Fixed)'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: transmission.isAdaptive
                                ? AppColors.accent
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (onConfigureInterval != null &&
                  assignedNodes.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spaceSm),
                AuthorizationGate(
                  requiredRole: UserRole.operator,
                  child: AquaButton(
                    label: 'Configure Transmission Interval',
                    icon: Icons.timer_outlined,
                    variant: AquaButtonVariant.outline,
                    isFullWidth: true,
                    onPressed: () => onConfigureInterval!(assignedNodes.first),
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.spaceSm),
            ],

            // LoRaWAN & Hardware Diagnostics
            Text(
              'Sensor Diagnostics & Network Info',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            AquaCard(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              child: Column(
                children: [
                  _buildDiagnosticRow(
                    context,
                    label: 'Connection State',
                    value: zone.isOnline ? 'ONLINE' : 'OFFLINE',
                    valueColor: zone.isOnline ? AppColors.success : AppColors.error,
                    icon: zone.isOnline ? Icons.sensors : Icons.sensors_off,
                  ),
                  const Divider(height: 12),
                  _buildDiagnosticRow(
                    context,
                    label: 'Signal Strength (RSSI)',
                    value: '${zone.rssiDbm} dBm',
                    icon: Icons.cell_tower,
                  ),
                  const Divider(height: 12),
                  _buildDiagnosticRow(
                    context,
                    label: 'Signal Quality (SNR)',
                    value: '${zone.snrDb} dB',
                    icon: Icons.graphic_eq,
                  ),
                  const Divider(height: 12),
                  _buildDiagnosticRow(
                    context,
                    label: 'Battery Status',
                    value: '${zone.batteryPercent}%',
                    valueColor: zone.batteryPercent < 20 ? AppColors.error : null,
                    icon: zone.batteryPercent < 20 ? Icons.battery_alert : Icons.battery_full,
                  ),
                  const Divider(height: 12),
                  _buildDiagnosticRow(
                    context,
                    label: 'Hardware / Firmware',
                    value: '${zone.hardwareModel} (${zone.firmwareVersion})',
                    icon: Icons.developer_board,
                  ),
                  const Divider(height: 12),
                  _buildDiagnosticRow(
                    context,
                    label: 'Last Telemetry Update',
                    value: _formatFullTime(zone.lastUpdated),
                    icon: Icons.access_time,
                  ),
                  const Divider(height: 12),
                  _buildDiagnosticRow(
                    context,
                    label: 'Telemetry Quality',
                    value: (zone.waterLevelCm < -30.0 || zone.waterLevelCm > 30.0)
                        ? 'Out of Bounds (Invalid)'
                        : (!zone.isOnline ? 'Node Offline' : 'Reliable Telemetry'),
                    valueColor: (zone.waterLevelCm < -30.0 || zone.waterLevelCm > 30.0)
                        ? AppColors.error
                        : (!zone.isOnline ? AppColors.zoneOffline : AppColors.success),
                    icon: Icons.verified_outlined,
                  ),
                  const Divider(height: 12),
                  _buildDiagnosticRow(
                    context,
                    label: 'Telemetry Freshness',
                    value: assignedNodes.isEmpty
                        ? 'No ArvaNode bound'
                        : (DateTime.now().difference(zone.lastUpdated).inMinutes >= 15
                            ? 'Outdated (${DateTime.now().difference(zone.lastUpdated).inMinutes}m ago)'
                            : 'Fresh (${DateTime.now().difference(zone.lastUpdated).inMinutes}m ago)'),
                    valueColor: assignedNodes.isEmpty
                        ? Colors.grey
                        : (DateTime.now().difference(zone.lastUpdated).inMinutes >= 15
                            ? AppColors.warning
                            : AppColors.success),
                    icon: assignedNodes.isEmpty ? Icons.cloud_off : Icons.history,
                  ),
                ],
              ),
            ),
            if (assignedNodes.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spaceSm),
              _buildContextualTroubleshootingCard(context, zone, assignedNodes),
            ],
            // Ultrasonic Water-Level Physical Column Diagram
            if (assignedNodes.isNotEmpty) ...[
              UltrasonicWaterLevelDiagram(
                nodes: assignedNodes,
                zones: [zone],
                initialSelectedNodeId: assignedNodes.first.id,
              ),
              const SizedBox(height: AppDimensions.spaceMd),
            ],

            // Water depth trend chart
            AquaChartContainer(
              title: 'Water Level History (${zone.code})',
              subtitle: 'Recent 5-point sensor telemetry readings (cm)',
              chartWidget: SimulatedTelemetryChart(
                dataPoints: zone.waterLevelHistory,
                labelSuffix: 'cm',
                lineColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            AquaButton(
              label: 'View Detailed Zone Analysis (${zone.code})',
              icon: Icons.analytics_outlined,
              isFullWidth: true,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ZoneAnalysisScreen(
                      zoneCode: zone.code,
                      initialZone: zone,
                    ),
                  ),
                );
              },
            ),
            if (onDeleteZone != null) ...[
              const SizedBox(height: AppDimensions.spaceSm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                  minimumSize: const Size.fromHeight(42),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text('Remove Monitoring Position (${zone.code})'),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Remove Position'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Are you sure you want to remove position ${zone.code} (${zone.name})?'),
                          if (assignedNodes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(AppDimensions.spaceSm),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                '${assignedNodes.length} assigned node(s) (${assignedNodes.map((n) => n.displayName).join(', ')}) will be safely moved to the unassigned pool.',
                                style: const TextStyle(fontSize: 12, color: AppColors.error),
                              ),
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Remove Position'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    navigator.pop();
                    await onDeleteZone!(zone);
                  }
                },
              ),
            ],
            const SizedBox(height: AppDimensions.spaceLg),

            // Read-Only Warning Banner & Centralized Irrigation Note
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: Text(
                          'Read-Only Monitoring Point (${zone.code})',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitoring zones provide telemetry inputs to edge node autonomous irrigation decisions. No individual pump or valve controls exist at the zone level.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppDimensions.spaceSm),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spaceSm),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatFullTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildFreshnessBadge(zone_models.MonitoringZone zone) {
    final ageMinutes = DateTime.now().difference(zone.lastUpdated).inMinutes.clamp(0, 99999);
    final isStale = ageMinutes >= 15;
    final color = isStale ? AppColors.warning : AppColors.success;
    final icon = isStale ? Icons.history : Icons.check_circle_outline;
    final text = isStale ? 'Stale (${ageMinutes}m ago)' : 'Fresh (${ageMinutes}m ago)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReliabilityBadge(zone_models.MonitoringZone zone) {
    final isOutOfBounds = zone.waterLevelCm < -30.0 || zone.waterLevelCm > 30.0;
    final ageMinutes = DateTime.now().difference(zone.lastUpdated).inMinutes;
    final isStale = ageMinutes >= 15;

    final Color color;
    final IconData icon;
    final String label;

    if (isOutOfBounds) {
      color = AppColors.error;
      icon = Icons.cancel_outlined;
      label = 'Out of Range';
    } else if (!zone.isOnline) {
      color = AppColors.zoneOffline;
      icon = Icons.sensors_off;
      label = 'Station Offline';
    } else if (isStale) {
      color = AppColors.warning;
      icon = Icons.warning_amber_outlined;
      label = 'Degraded Telemetry';
    } else {
      color = AppColors.primary;
      icon = Icons.verified_user_outlined;
      label = 'Valid Telemetry';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualTroubleshootingCard(
    BuildContext context,
    zone_models.MonitoringZone zone,
    List<Esp32Node> nodes,
  ) {
    final theme = Theme.of(context);
    final ageMinutes = DateTime.now().difference(zone.lastUpdated).inMinutes;
    final isOutdated = ageMinutes >= 15;
    final primaryNode = nodes.firstOrNull;
    final isOffline = primaryNode != null ? !primaryNode.isOnline : !zone.isOnline;

    if (!isOutdated && !isOffline) {
      return const SizedBox.shrink();
    }

    final String title;
    final String advice;
    final IconData icon;
    final Color color;

    if (isOffline) {
      title = 'ArvaNode Hardware Offline';
      advice =
          'Live measurements are unavailable. Inspect the ESP32 power supply, sensor wiring, network connection, and device logs.';
      icon = Icons.sensors_off;
      color = AppColors.error;
    } else {
      title = 'Outdated Sensor Data (>15m)';
      advice =
          'Showing the last recorded data (${ageMinutes}m ago). Current field conditions have not been confirmed. Check the ESP32 power supply, Wi-Fi or gateway connection, firmware logs, and whether the backend is receiving new telemetry.';
      icon = Icons.warning_amber_rounded;
      color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  advice,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
