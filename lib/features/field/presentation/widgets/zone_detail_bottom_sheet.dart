import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../control/domain/models/control_enums.dart';
import '../../../nodes/domain/models/models.dart';
import '../../../zones/domain/models/monitoring_zone.dart'
    as zone_models;
import '../../../zones/presentation/zone_analysis_screen.dart';

class ZoneDetailBottomSheet extends StatelessWidget {
  final zone_models.MonitoringZone zone;
  final List<Esp32Node> assignedNodes;
  final ControlUserRole userRole;
  final Future<void> Function(Esp32Node node)? onConfigureInterval;

  ZoneDetailBottomSheet({
    super.key,
    required this.zone,
    this.assignedNodes = const [],
    this.userRole = ControlUserRole.operator,
    this.onConfigureInterval,
  });

static void show(
    BuildContext context, {
    required zone_models.MonitoringZone zone,
    List<Esp32Node> assignedNodes = const [],
    ControlUserRole userRole = ControlUserRole.operator,
    Future<void> Function(Esp32Node node)? onConfigureInterval,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transmission = zone.transmissionConfig;
    final nodeCount =
        assignedNodes.isNotEmpty ? assignedNodes.length : zone.assignedNodeIds.length;
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
                  zone.isOnline ? 'Online' : 'Offline',
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
                    value: '${zone.waterLevelCm} cm',
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

            if (nodeCount > 0) ...[
              Text(
                'Assigned Nodes ($nodeCount${assignedNodes.isNotEmpty ? ', $onlineCount online' : ''})',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppDimensions.spaceXs),
              Wrap(
                spacing: AppDimensions.spaceXs,
                runSpacing: AppDimensions.spaceXs,
                children: [
                  if (assignedNodes.isNotEmpty)
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
                    )
                  else
                    ...zone.assignedNodeIds.map((id) => Chip(label: Text(id))),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMd),
            ],

            // Spatial Coordinates & Transmission Interval
            if (zone.coordinates != null || transmission != null) ...[
              Row(
                children: [
                  if (zone.coordinates?.hasAnyCoordinates == true) ...[
                    Expanded(
                      child: Text(
                        zone.coordinates?.hasLocalCoordinates == true
                            ? 'Local: X ${zone.coordinates!.localX!.toStringAsFixed(1)}m, Y ${zone.coordinates!.localY!.toStringAsFixed(1)}m'
                            : 'GPS: ${zone.coordinates!.latitude!.toStringAsFixed(4)}, ${zone.coordinates!.longitude!.toStringAsFixed(4)}',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  if (transmission != null) ...[
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            transmission.isAdaptive ? Icons.bolt : Icons.timer,
                            size: 12,
                            color: transmission.isAdaptive
                                ? AppColors.accent
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              'Interval: ${transmission.intervalSeconds}s ${transmission.isAdaptive ? '(Adaptive)' : '(Fixed)'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: transmission.isAdaptive
                                    ? AppColors.accent
                                    : AppColors.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    value: DateTime.now().difference(zone.lastUpdated).inMinutes >= 15
                        ? 'Stale (${DateTime.now().difference(zone.lastUpdated).inMinutes}m ago)'
                        : 'Fresh (${DateTime.now().difference(zone.lastUpdated).inMinutes}m ago)',
                    valueColor: DateTime.now().difference(zone.lastUpdated).inMinutes >= 15
                        ? AppColors.warning
                        : AppColors.success,
                    icon: Icons.history,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),

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
}
