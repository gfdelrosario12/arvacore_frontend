import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../zones/domain/models/monitoring_zone.dart';

import '../../../nodes/domain/models/esp32_node.dart';

class FieldHeaderOverviewCard extends StatelessWidget {
  final List<MonitoringZone> zones;
  final List<Esp32Node> nodes;
  final bool isStale;
  final bool masterEnabled;
  final bool isTogglingMaster;
  final ValueChanged<bool>? onToggleMaster;
  final int pendingPairingCount;
  final VoidCallback? onOpenPairingRequests;

  const FieldHeaderOverviewCard({
    super.key,
    required this.zones,
    this.nodes = const [],
    this.isStale = false,
    this.masterEnabled = true,
    this.isTogglingMaster = false,
    this.onToggleMaster,
    this.pendingPairingCount = 0,
    this.onOpenPairingRequests,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final assignedNodeCount = nodes.isNotEmpty
        ? nodes.where((n) => n.assignedZoneId != null && n.assignedZoneId!.isNotEmpty).length
        : zones.where((z) => z.assignedNodeIds.isNotEmpty).length;
    final onlineCount = nodes.isNotEmpty
        ? nodes.where((n) => n.isOnline).length
        : zones.where((z) => z.isOnline).length;
    final totalConfiguredPositions = zones.length;

    MonitoringZone? highestMoistureZone;
    MonitoringZone? lowestMoistureZone;
    final activeZones = zones.where((z) => z.assignedNodeIds.isNotEmpty || z.soilMoisturePercent > 0).toList();
    if (activeZones.isNotEmpty) {
      highestMoistureZone = activeZones.reduce((a, b) => a.soilMoisturePercent > b.soilMoisturePercent ? a : b);
      lowestMoistureZone = activeZones.reduce((a, b) => a.soilMoisturePercent < b.soilMoisturePercent ? a : b);
    }

    return AquaCard(
      gradient: LinearGradient(
        colors: [
          (masterEnabled ? AppColors.primary : Colors.grey)
              .withValues(alpha: isDark ? 0.22 : 0.12),
          theme.cardTheme.color ?? theme.colorScheme.surface,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Master System Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
            decoration: BoxDecoration(
              color: masterEnabled
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(
                color: masterEnabled ? AppColors.primary : Colors.grey,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        masterEnabled ? Icons.power : Icons.power_off,
                        size: 20,
                        color: masterEnabled ? AppColors.primary : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              masterEnabled ? 'ARVACORE MASTER SYSTEM: ON' : 'ARVACORE MASTER SYSTEM: OFF',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: masterEnabled ? AppColors.primary : Colors.grey.shade400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              masterEnabled
                                  ? 'Telemetry Ingestion & Pairing Active'
                                  : 'Telemetry Blocked • Pairing & Controls Suspended',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isTogglingMaster
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: masterEnabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: onToggleMaster,
                      ),
              ],
            ),
          ),
          if (pendingPairingCount > 0) ...[
            InkWell(
              onTap: onOpenPairingRequests,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              child: Container(
                margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: AppColors.secondary),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active, size: 16, color: AppColors.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$pendingPairingCount Incoming Hardware Pairing Request(s)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                        Icon(Icons.chevron_right, size: 16, color: AppColors.secondary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (isStale) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceSm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: AppColors.warning),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 14, color: AppColors.warning),
                  SizedBox(width: 6),
                  Text(
                    'STALE FIELD SENSOR DATA (>15m)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ArvaNode Monitoring Overview',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Field Telemetry Matrix',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge.deviceStatus(
                totalConfiguredPositions == 0
                    ? 'No Positions'
                    : (assignedNodeCount == totalConfiguredPositions
                        ? '$onlineCount/$assignedNodeCount Nodes Online'
                        : '$assignedNodeCount/$totalConfiguredPositions Positions Bound • $onlineCount Online'),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          if (highestMoistureZone != null && lowestMoistureZone != null) ...[
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.compare_arrows,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodySmall,
                        children: [
                          const TextSpan(text: 'Moisture Balance: Highest '),
                          TextSpan(
                            text: '${highestMoistureZone.code} (${highestMoistureZone.soilMoisturePercent.toStringAsFixed(1)}%) ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                          const TextSpan(text: '• Irrigation Priority '),
                          TextSpan(
                            text: '${lowestMoistureZone.code} (${lowestMoistureZone.soilMoisturePercent.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

