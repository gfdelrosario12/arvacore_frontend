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
  final Future<bool> Function(String nodeId)? onRemoveFromField;
  final Future<bool> Function({List<String>? nodeIds, String? reason})? onResetPairing;

  const ConnectedNodesCard({
    super.key,
    required this.nodes,
    this.zones = const [],
    this.isMasterOff = false,
    this.onManageNodes,
    this.onUnpairNode,
    this.onRemoveFromField,
    this.onResetPairing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;
            final titleWidget = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sensors, size: 20, color: AppColors.primary),
                const SizedBox(width: AppDimensions.spaceSm),
                Flexible(
                  child: Text(
                    '${AppStrings.arvaNodesName} & Field Positions (${nodes.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );

            final actionsWidget = Wrap(
              spacing: AppDimensions.spaceXs,
              runSpacing: AppDimensions.spaceXs,
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
                if (onResetPairing != null && nodes.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showResetPairingDialog(context),
                    icon: const Icon(Icons.restart_alt, size: 16, color: AppColors.warning),
                    label: const Text('Reset Pairings', style: TextStyle(color: AppColors.warning)),
                  ),
              ],
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  const SizedBox(height: AppDimensions.spaceXs),
                  actionsWidget,
                ],
              );
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: titleWidget),
                actionsWidget,
              ],
            );
          },
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
    String positionLabel = 'Unassigned — Not Assigned to Monitoring Zone';
    final bool isAssigned = node.isAssigned;
    if (isAssigned) {
      if (node.assignedZoneCode != null &&
          node.assignedZoneCode!.isNotEmpty &&
          node.assignedZoneName != null &&
          node.assignedZoneName!.isNotEmpty) {
        positionLabel = '${node.assignedZoneCode} • ${node.assignedZoneName}';
      } else {
        final matchingZone = zones.where(
          (z) =>
              z.id == node.assignedZoneId ||
              z.code == node.assignedZoneId ||
              z.code == node.assignedZoneCode ||
              node.assignedZoneId == 'zone-${z.id}' ||
              node.assignedZoneId == z.id.replaceAll(RegExp(r'[^0-9]'), ''),
        ).firstOrNull;

        if (matchingZone != null) {
          positionLabel = '${matchingZone.code} • ${matchingZone.name}';
        } else if (node.assignedZoneCode != null && node.assignedZoneCode!.isNotEmpty) {
          positionLabel = 'Zone ${node.assignedZoneCode}';
        } else if (node.assignedZoneId != null && node.assignedZoneId!.isNotEmpty) {
          positionLabel = 'Zone ${node.assignedZoneId}';
        } else {
          positionLabel = 'Assigned to Field';
        }
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
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: AppColors.textMutedOf(context),
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
                  color: (isOnline ? AppColors.success : AppColors.textSecondaryOf(context)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(
                    color: (isOnline ? AppColors.success : AppColors.textSecondaryOf(context)).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isOnline ? AppColors.success : AppColors.textSecondaryOf(context),
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
                          content: Text('Node ${node.displayName.isNotEmpty ? node.displayName : node.id} has been successfully unpaired.'),
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
          // Position Badge & Field Detachment
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppDimensions.spaceSm,
            runSpacing: AppDimensions.spaceXs,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAssigned
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
                      color: isAssigned ? AppColors.primary : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        positionLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isAssigned ? AppColors.primary : AppColors.warning,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAssigned && onRemoveFromField != null)
                InkWell(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove from Field'),
                        content: Text(
                          'Remove node ${node.displayName.isNotEmpty ? node.displayName : node.id} from its assigned field position?\n\nThe node remains paired to the network.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      final success = await onRemoveFromField!(node.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Node removed from field.' : 'Failed to remove node from field.'),
                            backgroundColor: success ? AppColors.success : AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_clear_outlined, size: 14, color: AppColors.textSecondaryOf(context)),
                        const SizedBox(width: 4),
                        Text(
                          'Remove from Field',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryOf(context),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 16),
          // Sensor Telemetry Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('Soil Moisture', style: TextStyle(fontSize: 10, color: AppColors.textMutedOf(context))),
                    const SizedBox(height: 2),
                    Text(
                      moisture != null ? '${moisture.toStringAsFixed(1)}%' : '0.0%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: node.isSoilSensorFailed
                            ? AppColors.error
                            : (moisture != null ? AppColors.primary : AppColors.textMutedOf(context)),
                      ),
                    ),
                    if (node.soilSensorHealth != null)
                      Text(
                        'SOIL: ${node.soilSensorHealth}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: node.isSoilSensorFailed ? AppColors.error : AppColors.success,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Water Depth', style: TextStyle(fontSize: 10, color: AppColors.textMutedOf(context))),
                    const SizedBox(height: 2),
                    Text(
                      waterLevel != null ? '${waterLevel.toStringAsFixed(1)} cm' : '0.0 cm',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: node.isUltrasonicSensorFailed
                            ? AppColors.error
                            : (waterLevel != null ? AppColors.accent : AppColors.textMutedOf(context)),
                      ),
                    ),
                    if (node.ultrasonicSensorHealth != null)
                      Text(
                        'ULTRA: ${node.ultrasonicSensorHealth}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: node.isUltrasonicSensorFailed ? AppColors.error : AppColors.success,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Battery / Voltage', style: TextStyle(fontSize: 10, color: AppColors.textMutedOf(context))),
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
                    if (node.telemetryStatus != null)
                      Text(
                        node.telemetryStatus!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: node.hasSensorFailure ? AppColors.warning : AppColors.success,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (onUnpairNode != null) ...[
            const SizedBox(height: AppDimensions.spaceSm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: ValueKey('unpair_button_${node.id}'),
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
                        content: Text('Node ${node.displayName.isNotEmpty ? node.displayName : node.id} has been successfully unpaired.'),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceSm, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.link_off_rounded, size: 16),
                label: const Text('Unpair Node'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showResetPairingDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restart_alt, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Reset All Pairings'),
          ],
        ),
        content: const Text(
          'Are you sure you want to reset all node pairings? All pairing authorizations will be revoked, and edge nodes will return to UNREGISTERED until re-paired. Field assignments will also be detached.\n\nCalibration, hardware configs, and historical telemetry will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Pairings'),
          ),
        ],
      ),
    );

    if (confirmed == true && onResetPairing != null && context.mounted) {
      final success = await onResetPairing!();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'All node pairings have been reset.' : 'Failed to reset node pairings.'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }
}
