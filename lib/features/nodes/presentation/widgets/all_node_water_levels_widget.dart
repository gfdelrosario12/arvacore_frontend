import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../nodes/domain/models/models.dart';

/// Renders a side-by-side comparative water depth overview for every registered ArvaNode.
///
/// Converts measured ultrasonic distance into water depth in cm using calibrated datum:
/// Water Level = Calibrated Sensor-to-Bottom Distance − Measured Sensor-to-Ball Distance
class AllNodeWaterLevelsWidget extends StatelessWidget {
  final List<Esp32Node> nodes;
  final bool isLoading;

  const AllNodeWaterLevelsWidget({
    super.key,
    required this.nodes,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeNodes = nodes.where((n) =>
        n.lifecycleState != NodeLifecycleStatus.unregistered &&
        n.lifecycleState != NodeLifecycleStatus.decommissioned).toList();

    if (isLoading && activeNodes.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (activeNodes.isEmpty) {
      return AquaCard(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Center(
          child: Text(
            'No ArvaNodes paired or online to monitor water levels.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return AquaCard(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'All-Node Water Levels (Paddy Depth)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Text(
                  '${activeNodes.length} Nodes Reporting',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Comparative water depth calculated from ultrasonic distance via calibrated observation pipe datum (Max measurable: 91.44 cm).',
            style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // Horizontal scrolling or wrap of node depth bars
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: activeNodes.map((node) => _buildNodeLevelColumn(theme, node, isDark)).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNodeLevelColumn(ThemeData theme, Esp32Node node, bool isDark) {
    final zoneCode = node.assignedZoneCode ?? (node.assignedZoneId != null ? 'Zone ${node.assignedZoneId}' : 'Unassigned');
    final isFailed = node.isUltrasonicSensorFailed;
    final depthCm = node.waterLevelCm;
    final distanceCm = node.waterLevelDistanceCm;
    const maxReferenceCm = 20.0; // Typical rice flooding target is ~5-15 cm, full scale 20cm display

    final clampedRatio = depthCm == null || isFailed
        ? 0.0
        : (depthCm / maxReferenceCm).clamp(0.0, 1.0);

    Color barColor = AppColors.primary;
    if (isFailed) {
      barColor = AppColors.alertError;
    } else if (depthCm != null) {
      if (depthCm < 3.0) {
        barColor = AppColors.zoneLow;
      } else if (depthCm > 10.0) {
        barColor = AppColors.irrigationFlooded;
      } else {
        barColor = AppColors.zoneOptimal;
      }
    }

    return Container(
      width: 88,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Depth value label
          Text(
            isFailed
                ? 'FAULT'
                : (depthCm != null ? '${depthCm.toStringAsFixed(1)} cm' : '--'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isFailed ? AppColors.alertError : barColor,
            ),
          ),
          const SizedBox(height: 6),

          // Depth Column Tank
          Container(
            height: 90,
            width: 32,
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Filled Water Level
                FractionallySizedBox(
                  heightFactor: isFailed ? 0.0 : clampedRatio,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.vertical(
                        bottom: const Radius.circular(5),
                        top: Radius.circular(clampedRatio > 0.95 ? 5 : 0),
                      ),
                    ),
                  ),
                ),
                // Indicator mark at 5cm optimal paddy flood
                Positioned(
                  bottom: 90 * (5.0 / maxReferenceCm),
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: Colors.greenAccent.shade700.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Node Identity & Zone
          Text(
            node.id,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            zoneCode,
            style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (distanceCm != null && !isFailed)
            Text(
              'Echo: ${distanceCm.toStringAsFixed(0)}cm',
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
