import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../nodes/domain/models/esp32_node.dart';
import '../../../nodes/presentation/widgets/node_unpair_dialog.dart';
import '../../../telemetry_stream/presentation/screens/telemetry_stream_screen.dart';
import '../../../zones/domain/models/monitoring_zone.dart';

class ConnectedNodesCard extends StatelessWidget {
  final List<Esp32Node> nodes;
  final List<MonitoringZone> zones;
  final bool isMasterOff;
  final VoidCallback? onManageNodes;
  final Future<bool> Function(String nodeId)? onUnpairNode;

  const ConnectedNodesCard({
    super.key,
    required this.nodes,
    this.zones = const [],
    this.isMasterOff = false,
    this.onManageNodes,
    this.onUnpairNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.sensors, size: 20, color: AppColors.primary),
                  const SizedBox(width: AppDimensions.spaceSm),
                  Expanded(
                    child: Text(
                      '${AppStrings.arvaNodesName} & Field Positions (${nodes.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TelemetryStreamScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.stream, size: 16, color: AppColors.primary),
                  label: const Text('Live Stream'),
                ),
                if (onManageNodes != null)
                  TextButton.icon(
                    onPressed: onManageNodes,
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Manage Nodes'),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceXs),
        Text(
          'Real-time edge telemetry and physical monitoring positions',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        if (nodes.isEmpty)
          AquaCard(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Row(
              children: [
                const Icon(
                  Icons.sensors_off_outlined,
                  color: AppColors.warning,
                  size: 28,
                ),
                const SizedBox(width: AppDimensions.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Connected ${AppStrings.arvaNodesName}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No physical edge nodes are currently streaming telemetry. Press the activation button on ArvaNode hardware to pair.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: nodes.length,
            separatorBuilder: (_, index) => const SizedBox(height: AppDimensions.spaceSm),
            itemBuilder: (context, index) {
              final node = nodes[index];
              return _buildNodeItem(context, node, theme);
            },
          ),
      ],
    );
  }

  Widget _buildNodeItem(BuildContext context, Esp32Node node, ThemeData theme) {
    // Resolve assigned position / zone
    String positionLabel = 'Position not assigned';
    if (node.assignedZoneId != null && node.assignedZoneId!.isNotEmpty) {
      final matchingZone = zones.where(
        (z) =>
            z.id == node.assignedZoneId ||
            z.code == node.assignedZoneId ||
            node.assignedZoneId == 'zone-${z.id}' ||
            node.assignedZoneId == z.id.replaceAll(RegExp(r'[^0-9]'), ''),
      ).firstOrNull;

      if (matchingZone != null) {
        positionLabel = '${matchingZone.code} • ${matchingZone.name}';
      } else {
        positionLabel = 'Zone ${node.assignedZoneId}';
      }
    }

    final moisture = node.soilMoisturePercent;
    final waterLevel = node.waterLevelCm;
    final battery = node.batteryPercent;
    final voltage = node.batteryVoltage;

    final isOnline = node.isOnline && !isMasterOff;

    return AquaCard(
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
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
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOnline ? AppColors.success : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.displayName.isNotEmpty ? node.displayName : node.id,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'ID: ${node.id} • MAC: ${node.macAddress}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isOnline ? AppColors.success : Colors.grey).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(
                    color: (isOnline ? AppColors.success : Colors.grey).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isOnline ? AppColors.success : Colors.grey,
                  ),
                ),
              ),
              if (onUnpairNode != null) ...[
                const SizedBox(width: AppDimensions.spaceSm),
                IconButton(
                  icon: const Icon(Icons.link_off_rounded, size: 18, color: AppColors.error),
                  tooltip: 'Unpair Node ${node.id}',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () async {
                    final confirmed = await NodeUnpairConfirmationDialog.show(
                      context,
                      nodeId: node.id,
                      displayName: node.displayName,
                      onConfirm: () => onUnpairNode!(node.id),
                    );
                    if (confirmed == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Node ${node.id} forcefully unpaired.'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Position Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: node.assignedZoneId != null && node.assignedZoneId!.isNotEmpty
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: node.assignedZoneId != null && node.assignedZoneId!.isNotEmpty
                      ? AppColors.primary
                      : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  positionLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: node.assignedZoneId != null && node.assignedZoneId!.isNotEmpty
                        ? AppColors.primary
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          // Sensor Telemetry Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Soil Moisture', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      moisture != null ? '${moisture.toStringAsFixed(1)}%' : '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: moisture != null ? AppColors.primary : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('Water Depth', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      waterLevel != null ? '${waterLevel.toStringAsFixed(1)} cm' : '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: waterLevel != null ? AppColors.accent : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('Battery / Voltage', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(
                      battery != null
                          ? '$battery%${voltage != null ? ' (${voltage.toStringAsFixed(2)}V)' : ''}'
                          : (voltage != null ? '${voltage.toStringAsFixed(2)}V' : '—'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: (battery != null && battery < 20) ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
