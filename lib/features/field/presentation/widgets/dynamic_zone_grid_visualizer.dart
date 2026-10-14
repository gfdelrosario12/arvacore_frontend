import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../zones/domain/models/monitoring_zone.dart';

/// An adaptive, responsive grid visualizer for arbitrary field monitoring zones.
///
/// Supports arbitrary numbers of zones (1, 2, 4, 6, 8, or more) and adjusts
/// column counts dynamically across mobile portrait, tablet, and desktop web layouts.
class DynamicZoneGridVisualizer extends StatelessWidget {
  final List<MonitoringZone> zones;
  final ValueChanged<MonitoringZone>? onZoneSelected;
  final String? selectedZoneCode;
  final String? title;
  final bool isMasterOff;

  const DynamicZoneGridVisualizer({
    super.key,
    required this.zones,
    this.onZoneSelected,
    this.selectedZoneCode,
    this.title,
    this.isMasterOff = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (zones.isEmpty) {
      return const SizedBox.shrink();
    }

    final headerTitle = title ??
        (zones.length == 4 && zones.every((z) => z.code.startsWith('Q'))
            ? 'Monitoring Quadrants Matrix (Q1–Q4)'
            : 'Monitoring Zones Matrix (${zones.length} Active)');

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount;
        double childAspectRatio;

        if (width < 380) {
          crossAxisCount = zones.length == 1 ? 1 : 2;
          childAspectRatio = zones.length == 1 ? 2.2 : 1.1;
        } else if (width < 600) {
          crossAxisCount = zones.length == 1 ? 1 : 2;
          childAspectRatio = zones.length == 1 ? 2.4 : 1.18;
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
                const SizedBox(width: 8),
                const Icon(
                  Icons.touch_app,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap zone for details',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
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
                return _buildZoneCard(context, zone, isSelected);
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
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final isOnline = zone.isOnline;

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
                        color: isOnline ? AppColors.success : AppColors.error,
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
                  child: StatusBadge.zoneStatus(zone.status.name, compact: true),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Soil Moisture',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${zone.soilMoisturePercent.toStringAsFixed(1)}%',
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
                  'Water: ${zone.waterLevelCm.toStringAsFixed(1)}cm',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getBatteryIcon(zone.batteryPercent),
                    size: 13,
                    color: zone.batteryPercent < 20 ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${zone.batteryPercent}%',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
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

