import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/widgets.dart';

class IndicatorCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String capabilityStatus; // 'MEASURABLE', 'PARTIALLY_MEASURABLE', 'NOT_MEASURABLE'
  final String statusDescription;
  final String? calculationFormula;
  final List<Widget> metrics;
  final Widget? historicalWidget;
  final VoidCallback? onAddReference;
  final String? addReferenceLabel;

  const IndicatorCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.capabilityStatus,
    required this.statusDescription,
    this.calculationFormula,
    required this.metrics,
    this.historicalWidget,
    this.onAddReference,
    this.addReferenceLabel,
  });

  Color _getBadgeColor() {
    switch (capabilityStatus.toUpperCase()) {
      case 'MEASURABLE':
        return AppColors.success;
      case 'PARTIALLY_MEASURABLE':
        return AppColors.warning;
      case 'NOT_MEASURABLE':
      default:
        return AppColors.error;
    }
  }

  String _getBadgeLabel() {
    switch (capabilityStatus.toUpperCase()) {
      case 'MEASURABLE':
        return 'MEASURABLE';
      case 'PARTIALLY_MEASURABLE':
        return 'PARTIALLY MEASURABLE';
      case 'NOT_MEASURABLE':
      default:
        return 'NOT MEASURABLE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppDimensions.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getBadgeColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: _getBadgeColor().withValues(alpha: 0.5)),
                ),
                child: Text(
                  _getBadgeLabel(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getBadgeColor(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // Capability status explanation alert banner
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceSm),
            decoration: BoxDecoration(
              color: _getBadgeColor().withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: _getBadgeColor().withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  capabilityStatus == 'MEASURABLE'
                      ? Icons.check_circle_outline
                      : (capabilityStatus == 'PARTIALLY_MEASURABLE'
                          ? Icons.info_outline
                          : Icons.warning_amber_rounded),
                  color: _getBadgeColor(),
                  size: 16,
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: Text(
                    statusDescription,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // Key metrics row
          if (metrics.isNotEmpty) ...[
            Wrap(
              spacing: AppDimensions.spaceMd,
              runSpacing: AppDimensions.spaceSm,
              children: metrics,
            ),
            const SizedBox(height: AppDimensions.spaceMd),
          ],

          // Formula documentation if present
          if (calculationFormula != null && calculationFormula!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calculate_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Formula: $calculationFormula',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
          ],

          // Historical comparison widget or table
          if (historicalWidget != null) ...[
            historicalWidget!,
            const SizedBox(height: AppDimensions.spaceMd),
          ],

          // Action button if available
          if (onAddReference != null) ...[
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onAddReference,
                icon: const Icon(Icons.add_task, size: 16),
                label: Text(addReferenceLabel ?? 'Enter Ground-Truth Reference'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

