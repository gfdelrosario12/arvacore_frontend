import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/models/farming_chat_models.dart';

class WorkflowProgressWidget extends StatefulWidget {
  final String lifecycleStatus;
  final List<WorkflowStepModel> steps;

  const WorkflowProgressWidget({
    super.key,
    required this.lifecycleStatus,
    required this.steps,
  });

  @override
  State<WorkflowProgressWidget> createState() => _WorkflowProgressWidgetState();
}

class _WorkflowProgressWidgetState extends State<WorkflowProgressWidget> {
  bool _isExpanded = false;

  Color _getLifecycleColor(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESSFULLY_IMPLEMENTED':
      case 'COMPLETED':
        return AppColors.success;
      case 'IN_PROGRESS':
      case 'PREPARING':
        return AppColors.primary;
      case 'AWAITING_USER_DECISION':
      case 'WAITING':
        return AppColors.warning;
      case 'BLOCKED':
      case 'FAILED':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getStepColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return AppColors.success;
      case 'IN_PROGRESS':
        return AppColors.primary;
      case 'WAITING':
      case 'WAITING_FOR_DECISION':
        return AppColors.warning;
      case 'BLOCKED':
      case 'FAILED':
        return AppColors.error;
      case 'SKIPPED':
        return Colors.blueGrey;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getStepIcon(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Icons.check_circle_rounded;
      case 'IN_PROGRESS':
        return Icons.sync_rounded;
      case 'WAITING':
      case 'WAITING_FOR_DECISION':
        return Icons.hourglass_top_rounded;
      case 'BLOCKED':
        return Icons.block_rounded;
      case 'FAILED':
        return Icons.error_outline_rounded;
      case 'SKIPPED':
        return Icons.redo_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final completedCount = widget.steps.where((s) => s.isCompleted).length;
    final totalCount = widget.steps.length;
    final progressFraction = totalCount > 0 ? completedCount / totalCount : 0.0;
    final lifecycleColor = _getLifecycleColor(widget.lifecycleStatus);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.spaceXs),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: lifecycleColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: lifecycleColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_tree_rounded,
                      size: 16,
                      color: lifecycleColor,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Arva AI Workflow',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: lifecycleColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.lifecycleStatus.replaceAll('_', ' '),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: lifecycleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$completedCount of $totalCount steps completed (${(progressFraction * 100).toInt()}%)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondaryOf(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
            child: LinearProgressIndicator(
              value: progressFraction,
              backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(lifecycleColor),
              minHeight: 3,
            ),
          ),

          // Collapsible Steps Detail View
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '13-STEP CONCRETE WORKFLOW DEPENDENCIES (S01–S13)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  ...widget.steps.map((step) => _buildStepRow(context, step)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(BuildContext context, WorkflowStepModel step) {
    final stepColor = _getStepColor(step.status);
    final icon = _getStepIcon(step.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: stepColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      step.stepCode,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: stepColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        step.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: step.isInProgress ? FontWeight.bold : FontWeight.normal,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    if (step.isRemediation)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'Conditional',
                          style: TextStyle(fontSize: 9, color: AppColors.warning),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      step.status.replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: stepColor,
                      ),
                    ),
                  ],
                ),
                if (step.dependsOn.isNotEmpty)
                  Text(
                    'Depends on: ${step.dependsOn.join(', ')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMutedOf(context),
                    ),
                  ),
                if (step.blockingReason != null && step.blockingReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Blocked: ${step.blockingReason}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (step.skipReason != null && step.skipReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Skipped: ${step.skipReason}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.blueGrey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
