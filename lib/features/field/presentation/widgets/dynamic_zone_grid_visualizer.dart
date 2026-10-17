import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../nodes/domain/models/esp32_node.dart';
import '../../../zones/domain/models/monitoring_zone.dart';

/// An adaptive, responsive grid visualizer for arbitrary field monitoring positions and zones.
///
/// Supports dynamic numbers of zones (0, 1, 2, 4, 5, 8, or more) and adjusts
/// column counts dynamically across mobile portrait, tablet, and desktop web layouts.
/// Explicitly distinguishes assigned nodes from available unoccupied positions.
class DynamicZoneGridVisualizer extends StatelessWidget {
  final List<MonitoringZone> zones;
  final List<Esp32Node> nodes;
  final ValueChanged<MonitoringZone>? onZoneSelected;
  final void Function(MonitoringZone zone)? onAssignNodeToZone;
  final VoidCallback? onAddZone;
  final String? selectedZoneCode;
  final String? title;
  final bool isMasterOff;

  const DynamicZoneGridVisualizer({
    super.key,
    required this.zones,
    this.nodes = const [],
    this.onZoneSelected,
    this.onAssignNodeToZone,
    this.onAddZone,
    this.selectedZoneCode,
    this.title,
    this.isMasterOff = false,
  });

  Esp32Node? _getAssignedNode(MonitoringZone zone) {
    return nodes.where((n) =>
        n.assignedZoneId == zone.id ||
        n.assignedZoneId == zone.code ||
        n.assignedZoneId == 'zone-${zone.id}' ||
        n.assignedZoneId == zone.id.replaceAll(RegExp(r'[^0-9]'), '') ||
        zone.assignedNodeIds.contains(n.id) ||
        zone.assignedNodeIds.contains(n.displayName)).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final headerTitle = title ?? 'Field Monitoring Positions (${zones.length} Active)';

    if (zones.isEmpty) {
      return AquaCard(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          children: [
            const Icon(Icons.grid_off, size: 36, color: AppColors.warning),
            const SizedBox(height: AppDimensions.spaceSm),
            Text(
              'No Field Monitoring Positions Configured',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a monitoring zone or field position to begin placing ArvaNodes.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onAddZone != null) ...[
              const SizedBox(height: AppDimensions.spaceMd),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Add Monitoring Position'),
                onPressed: isMasterOff ? null : onAddZone,
              ),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount;
        double childAspectRatio;

        if (width < 380) {
          crossAxisCount = zones.length == 1 ? 1 : 2;
          childAspectRatio = 1.05;
        } else if (width < 600) {
          crossAxisCount = zones.length == 1 ? 1 : 2;
          childAspectRatio = 1.15;
        } else if (width < 900) {
          crossAxisCount = zones.length <= 2 ? zones.length : 3;
          childAspectRatio = 1.25;
        } else {
          crossAxisCount = zones.length <= 3 ? zones.length : 4;
          childAspectRatio = 1.35;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    headerTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onAddZone != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(50, 32),
                    ),
                    onPressed: isMasterOff ? null : onAddZone,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Position', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppDimensions.spaceSm,
                mainAxisSpacing: AppDimensions.spaceSm,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: zones.length,
              itemBuilder: (context, index) {
                final zone = zones[index];
                final isSelected = zone.code == selectedZoneCode;
                final assignedNode = _getAssignedNode(zone);
                return _buildZoneCard(context, zone, assignedNode, isSelected);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildZoneCard(
    BuildContext context,
    MonitoringZone zone,
    Esp32Node? assignedNode,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final hasNode = assignedNode != null;
    final isOnline = hasNode ? (assignedNode.isOnline && !isMasterOff) : zone.isOnline;

    Color borderHighlight = Colors.transparent;
    if (isSelected) {
      borderHighlight = AppColors.primary;
    } else if (zone.status == ZoneStatus.critical) {
      borderHighlight = AppColors.error;
    } else if (zone.status == ZoneStatus.warning) {
      borderHighlight = AppColors.warning;
    }

    Widget card = AquaCard(
      borderColor: borderHighlight != Colors.transparent ? borderHighlight : null,
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      onTap: isMasterOff ? null : () => onZoneSelected?.call(zone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Code + Online indicator + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        zone.code,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: hasNode
                            ? (isOnline ? AppColors.success : Colors.grey)
                            : Colors.orange.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: hasNode
                      ? StatusBadge.zoneStatus(zone.status.name, compact: true)
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'UNOCCUPIED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),

          // Middle: Sensor Telemetry or "Position Available"
          if (hasNode) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Soil Moisture',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                    Text(
                      assignedNode.displayName.isNotEmpty ? assignedNode.displayName : assignedNode.id,
                      style: const TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                Text(
                  assignedNode.soilMoisturePercent != null
                      ? '${assignedNode.soilMoisturePercent!.toStringAsFixed(1)}%'
                      : '${zone.soilMoisturePercent.toStringAsFixed(1)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Water: ${assignedNode.waterLevelCm != null ? assignedNode.waterLevelCm!.toStringAsFixed(1) : zone.waterLevelCm.toStringAsFixed(1)}cm',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getBatteryIcon(assignedNode.batteryPercent ?? zone.batteryPercent),
                      size: 13,
                      color: (assignedNode.batteryPercent ?? zone.batteryPercent) < 20
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${assignedNode.batteryPercent ?? zone.batteryPercent}%',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ] else ...[
            // Empty zone state
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  zone.name,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'No ArvaNode bound',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            if (onAssignNodeToZone != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.primary, width: 1),
                  ),
                  icon: const Icon(Icons.add_link, size: 14),
                  label: const Text('Assign Node', style: TextStyle(fontSize: 10)),
                  onPressed: isMasterOff ? null : () => onAssignNodeToZone?.call(zone),
                ),
              )
            else
              Text(
                'Available Position',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
          ],
        ],
      ),
    );

    if (isMasterOff) {
      return Opacity(
        opacity: 0.45,
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Colors.grey,
            BlendMode.saturation,
          ),
          child: card,
        ),
      );
    }

    return card;
  }

  IconData _getBatteryIcon(int percent) {
    if (percent > 80) return Icons.battery_full;
    if (percent > 50) return Icons.battery_5_bar;
    if (percent > 20) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }
}
