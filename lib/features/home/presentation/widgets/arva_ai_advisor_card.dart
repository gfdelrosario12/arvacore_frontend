import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../../core/widgets/aqua_button.dart';

/// Arva AI Advisor Card
/// Visually separates AI-generated decision-support advice from measured
/// sensor telemetry and deterministic irrigation state machine execution.
class ArvaAiAdvisorCard extends StatelessWidget {
  final String summaryText;
  final String? proposalType;
  final String? targetZone;
  final String? rationale;
  final bool requiresConfirmation;
  final VoidCallback? onReviewProposal;
  final VoidCallback? onOpenChatbot;
  final bool isLoading;

  const ArvaAiAdvisorCard({
    super.key,
    required this.summaryText,
    this.proposalType,
    this.targetZone,
    this.rationale,
    this.requiresConfirmation = true,
    this.onReviewProposal,
    this.onOpenChatbot,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasProposal = proposalType != null &&
        proposalType != 'NONE' &&
        proposalType!.isNotEmpty;

    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AI Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Arva',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Agricultural AI • PhilRice & IRRI AWD Protocols',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'ADVISORY ONLY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.waving_hand_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '“Hi, I am Arva, what do you like to plant today?”',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spaceSm),

          // Grounded Summary Text
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceSm),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Text(
              summaryText,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
              ),
            ),
          ),

          // Action Proposal Container (if present)
          if (hasProposal) ...[
            const SizedBox(height: AppDimensions.spaceMd),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.pending_actions,
                        color: AppColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'AWD Action Proposal: ${proposalType?.replaceAll('_', ' ')}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (targetZone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Target: $targetZone',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (rationale != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      rationale!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppDimensions.spaceSm),
                  if (onReviewProposal != null)
                    AquaButton(
                      label: 'Review & Authorize in Control',
                      icon: Icons.check_circle_outline,
                      isFullWidth: true,
                      onPressed: onReviewProposal,
                    ),
                ],
              ),
            ),
          ],

          if (onOpenChatbot != null) ...[
            const SizedBox(height: AppDimensions.spaceSm),
            AquaButton(
              label: 'Chat with Arva',
              icon: Icons.chat_bubble_outline_rounded,
              variant: AquaButtonVariant.secondary,
              isFullWidth: true,
              onPressed: onOpenChatbot,
            ),
          ],

          const SizedBox(height: AppDimensions.spaceSm),
          // Safety Disclaimer
          Text(
            'Notice: Arva AI does not directly control pumps or valves. All physical water operations require human confirmation and satisfy deterministic safety interlocks.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
