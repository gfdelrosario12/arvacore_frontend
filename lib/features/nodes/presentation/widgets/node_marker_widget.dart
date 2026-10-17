import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/models/models.dart';

class NodeMarkerWidget extends StatelessWidget {
  final Esp32Node node;
  final bool isSelected;
  final VoidCallback? onTap;

  const NodeMarkerWidget({
    super.key,
    required this.node,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMaintenance = node.lifecycleState == NodeLifecycleStatus.maintenance;
    final isRetired = node.isRetired;
    final statusColor = !node.isOnline || isRetired
        ? AppColors.error
        : (isMaintenance || (node.batteryPercent != null && node.batteryPercent! < 20)
            ? AppColors.warning
            : AppColors.success);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Marker Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : theme.colorScheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : statusColor.withValues(alpha: 0.8),
                width: isSelected ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.3),
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMaintenance) ...[
                  const Icon(
                    Icons.build,
                    size: 10,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                ] else ...[
                  // Live status dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        if (node.isOnline)
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // Display Name
                Text(
                  node.displayName.length > 14
                      ? '${node.displayName.substring(0, 12)}..'
                      : node.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isSelected ? Colors.white : null,
                  ),
                ),
                const SizedBox(width: 4),
                // Interval pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: node.transmissionConfig.isAdaptive
                        ? AppColors.accent.withValues(alpha: 0.25)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (node.transmissionConfig.isAdaptive) ...[
                        const Icon(
                          Icons.bolt,
                          size: 10,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 1),
                      ],
                      Text(
                        '${node.transmissionConfig.intervalSeconds}s',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: node.transmissionConfig.isAdaptive
                              ? AppColors.accent
                              : (isSelected ? Colors.white70 : null),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Pin Stem & Anchor Dot
          Container(
            width: 2,
            height: 6,
            color: isSelected ? AppColors.primary : statusColor,
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

