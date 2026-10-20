import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_button.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../awd/presentation/awd_analytics_screen.dart';
import '../../domain/models/field_dashboard_summary.dart';
import '../../domain/models/field_recommendation.dart';

class FieldRecommendationsCard extends StatelessWidget {
  final FieldDashboardSummary summary;
  final VoidCallback? onNavigateToControl;

  const FieldRecommendationsCard({
    super.key,
    required this.summary,
    this.onNavigateToControl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recommendations = summary.recommendations;

    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Text(
                  'Field Recommendations',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: summary.requiresIrrigation
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  border: Border.all(
                    color: summary.requiresIrrigation
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
                child: Text(
                  summary.requiresIrrigation
                      ? 'IRRIGATION NEEDED'
                      : 'NO IRRIGATION NEEDED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: summary.requiresIrrigation
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceSm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.psychology,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: Text(
                    summary.recommendedActionText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spaceMd),
            ...recommendations.map((rec) => _buildRecommendationItem(context, rec)),
          ],
          const SizedBox(height: AppDimensions.spaceSm),
          AquaButton(
            label: 'View Detailed Irrigation Analytics',
            icon: Icons.analytics_outlined,
            variant: AquaButtonVariant.outline,
            isFullWidth: true,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AwdAnalyticsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(
    BuildContext context,
    FieldRecommendation rec,
  ) {
    final theme = Theme.of(context);
    final urgencyColor = _getUrgencyColor(rec.urgency);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: urgencyColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: urgencyColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  rec.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: urgencyColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: urgencyColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rec.urgency.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            rec.description,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Color _getUrgencyColor(RecommendationUrgency urgency) {
    switch (urgency) {
      case RecommendationUrgency.high:
        return AppColors.warning;
      case RecommendationUrgency.medium:
        return AppColors.primary;
      case RecommendationUrgency.low:
        return AppColors.success;
    }
  }
}

