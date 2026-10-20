import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../irrigation/domain/models/irrigation_execution_audit_log.dart';

class IrrigationAuditLogSection extends StatelessWidget {
  final List<IrrigationExecutionAuditLog> auditLogs;
  final VoidCallback? onRefresh;

  const IrrigationAuditLogSection({
    super.key,
    required this.auditLogs,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.history, color: AppColors.primary, size: 20),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Flexible(
                        child: Text(
                          'Irrigation Audit History',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: onRefresh,
                    tooltip: 'Refresh Audit Trail',
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Immutable record distinguishing autonomous system cycles from manual operator interventions.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            if (auditLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No irrigation events recorded yet.',
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: auditLogs.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final log = auditLogs[index];
                  return _buildAuditLogTile(context, log);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditLogTile(BuildContext context, IrrigationExecutionAuditLog log) {
    final theme = Theme.of(context);

    Color actorColor;
    IconData actorIcon;
    String actorLabel;

    switch (log.actor.type) {
      case IrrigationActorType.system:
        actorColor = Colors.purple.shade600;
        actorIcon = Icons.smart_toy_outlined;
        actorLabel = 'System (Auto-Irrigation)';
        break;
      case IrrigationActorType.user:
        actorColor = Colors.blue.shade700;
        actorIcon = Icons.person_outline;
        actorLabel = 'Operator: ${log.actor.displayName}';
        break;
      case IrrigationActorType.emergencyStop:
        actorColor = AppColors.alertError;
        actorIcon = Icons.warning_amber_rounded;
        actorLabel = 'Emergency Stop';
        break;
    }

    Color outcomeColor;
    switch (log.outcome.toLowerCase()) {
      case 'completed':
        outcomeColor = AppColors.pumpActive;
        break;
      case 'aborted':
        outcomeColor = AppColors.alertWarning;
        break;
      case 'failed':
        outcomeColor = AppColors.alertError;
        break;
      default:
        outcomeColor = AppColors.primary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Actor Chip
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: actorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: actorColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actorIcon, size: 14, color: actorColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        actorLabel,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: actorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Timestamp
            Text(
              _formatTimestamp(log.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Action and Rationale
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: outcomeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.action.toUpperCase(),
                style: TextStyle(
                  color: outcomeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                log.triggerContext,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (log.targetDurationMinutes != null ||
            log.actualDurationMinutes != null ||
            log.triggeringDepthCm != null) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (log.triggeringDepthCm != null)
                _buildMetricChip(
                  theme,
                  Icons.water,
                  'Depth: ${log.triggeringDepthCm!.toStringAsFixed(1)} cm',
                ),
              if (log.telemetryConfidenceScore != null)
                _buildMetricChip(
                  theme,
                  Icons.verified,
                  'Conf: ${(log.telemetryConfidenceScore! * 100).toInt()}%',
                ),
              if (log.targetDurationMinutes != null)
                _buildMetricChip(
                  theme,
                  Icons.timer,
                  'Target: ${log.targetDurationMinutes}m',
                ),
              if (log.actualDurationMinutes != null)
                _buildMetricChip(
                  theme,
                  Icons.schedule,
                  'Duration: ${log.actualDurationMinutes}m',
                ),
              if (log.failureReason != null)
                _buildMetricChip(
                  theme,
                  Icons.error_outline,
                  'Fault: ${log.failureReason}',
                  color: AppColors.alertError,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMetricChip(ThemeData theme, IconData icon, String text, {Color? color}) {
    final chipColor = color ?? theme.hintColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 10, color: chipColor),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
