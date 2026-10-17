import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../zones/domain/models/monitoring_zone.dart';
import '../../../zones/presentation/zone_analysis_screen.dart';
import '../../domain/models/field_dashboard_summary.dart';

class ZoneContrastSummaryCard extends StatelessWidget {
  final FieldDashboardSummary summary;
  final VoidCallback? onNavigateToField;

  const ZoneContrastSummaryCard({
    super.key,
    required this.summary,
    this.onNavigateToField,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zones = summary.monitoringZones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Monitoring Zones Breakdown (${zones.length} Zones)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (onNavigateToField != null)
              TextButton(
                onPressed: onNavigateToField,
                child: const Text('Field Details'),
              ),
          ],
        ),
        if (zones.isEmpty) ...[
          const SizedBox(height: AppDimensions.spaceSm),
          AquaCard(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Row(
              children: [
                const Icon(Icons.grid_off, size: 24, color: AppColors.primary),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: Text(
                    'No field monitoring positions or zones currently configured.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ] else if (summary.highestMoistureZoneCode != null || summary.lowestMoistureZoneCode != null) ...[
          const SizedBox(height: AppDimensions.spaceXs),
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
                        const TextSpan(text: 'Moisture Contrast: '),
                        if (summary.highestMoistureZoneCode != null) ...[
                          TextSpan(
                            text: '${summary.highestMoistureZoneCode} (Highest Moisture) ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                        if (summary.lowestMoistureZoneCode != null) ...[
                          const TextSpan(text: '| '),
                          TextSpan(
                            text: '${summary.lowestMoistureZoneCode} (Irrigation Priority)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppDimensions.spaceSm),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            int crossAxisCount;
            double childAspectRatio;

            if (width < 380) {
              crossAxisCount = zones.length == 1 ? 1 : 2;
              childAspectRatio = zones.length == 1 ? 2.2 : 1.12;
            } else if (width < 600) {
              crossAxisCount = zones.length == 1 ? 1 : 2;
              childAspectRatio = zones.length == 1 ? 2.4 : 1.18;
            } else if (width < 900) {
              crossAxisCount = zones.length <= 2 ? zones.length : 3;
              childAspectRatio = 1.30;
            } else {
              crossAxisCount = zones.length <= 3 ? zones.length : 4;
              childAspectRatio = 1.40;
            }

            return GridView.builder(
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
                final isHighestMoisture = zone.code == summary.highestMoistureZoneCode;
                final isIrrigationPriority = zone.code == summary.lowestMoistureZoneCode;
                return _buildZoneItem(context, zone, isHighestMoisture, isIrrigationPriority);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildZoneItem(
    BuildContext context,
    MonitoringZone zone,
    bool isHighestMoisture,
    bool isIrrigationPriority,
  ) {
    final theme = Theme.of(context);

    Color borderHighlight = Colors.transparent;
    if (isHighestMoisture) borderHighlight = AppColors.success;
    if (isIrrigationPriority) borderHighlight = AppColors.warning;

    return AquaCard(
      borderColor: borderHighlight != Colors.transparent ? borderHighlight : null,
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      onTap: () {
        if (onNavigateToField != null) {
          onNavigateToField!();
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ZoneAnalysisScreen(
                zoneCode: zone.code,
                initialZone: zone,
              ),
            ),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                zone.code,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isHighestMoisture)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'HIGHEST MOISTURE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                )
              else if (isIrrigationPriority)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'IRRIGATION PRIORITY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                )
              else
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
              ),
              Text(
                '${zone.soilMoisturePercent.toStringAsFixed(1)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Water: ${zone.waterLevelCm.toStringAsFixed(1)} cm',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.sensors,
                size: 13,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
