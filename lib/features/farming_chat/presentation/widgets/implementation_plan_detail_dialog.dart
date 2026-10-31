import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/models/farming_chat_models.dart';

class ImplementationPlanDetailDialog extends StatefulWidget {
  final PlanDetailModel plan;
  final Function(String targetStatus, String? reason, String? evidence) onUpdateStatus;
  final Function(int taskId) onToggleTask;
  final Function(int taskId, int dependsOnId) onAddDependency;
  final Function(int taskId, int dependsOnId) onRemoveDependency;
  final VoidCallback onResumeInChat;

  const ImplementationPlanDetailDialog({
    super.key,
    required this.plan,
    required this.onUpdateStatus,
    required this.onToggleTask,
    required this.onAddDependency,
    required this.onRemoveDependency,
    required this.onResumeInChat,
  });

  @override
  State<ImplementationPlanDetailDialog> createState() => _ImplementationPlanDetailDialogState();
}

class _ImplementationPlanDetailDialogState extends State<ImplementationPlanDetailDialog> {
  late PlanDetailModel _plan;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _evidenceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return AppColors.alertSuccess;
      case 'IN_PROGRESS':
        return AppColors.primary;
      case 'CONTINUED':
        return AppColors.alertWarning;
      case 'CANCELLED':
        return Colors.grey;
      case 'FAILED':
        return AppColors.alertError;
      default:
        return AppColors.secondary;
    }
  }

  void _showStatusDialog(String targetStatus) {
    _reasonController.clear();
    _evidenceController.clear();

    final isCancelOrFail = targetStatus == 'CANCELLED' || targetStatus == 'FAILED';
    final isComplete = targetStatus == 'COMPLETED';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Transition to $targetStatus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm transition of plan ${_plan.planCode} to status $targetStatus.'),
            if (isCancelOrFail) ...[
              const SizedBox(height: AppDimensions.spaceSm),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Explanation / Reason (Required)',
                  hintText: 'e.g., Heavy monsoon submerged field, pausing tillering',
                ),
              ),
            ],
            if (isComplete) ...[
              const SizedBox(height: AppDimensions.spaceSm),
              TextField(
                controller: _evidenceController,
                decoration: const InputDecoration(
                  labelText: 'Completion Evidence (Sensor / Field Observation)',
                  hintText: 'e.g., Ultrasonic water tube confirms 3.5cm perched ponding across all terraces',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (isCancelOrFail && _reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide an explanation/reason')),
                );
                return;
              }
              Navigator.pop(ctx);
              widget.onUpdateStatus(
                targetStatus,
                _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
                _evidenceController.text.trim().isEmpty ? null : _evidenceController.text.trim(),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(_plan.lifecycleStatus);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _plan.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Code: ${_plan.planCode} • Field #${_plan.fieldId}',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor, width: 1.2),
                    ),
                    child: Text(
                      _plan.lifecycleStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              // Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall Implementation Progress',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_plan.progressPercent}% (${_plan.tasks.where((t) => t.isCompleted).length}/${_plan.tasks.length} tasks)',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _plan.progressPercent / 100.0,
                      backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              if (_plan.statusReason != null && _plan.statusReason!.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spaceSm),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceSm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Note: ${_plan.statusReason}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 24),
              // Task Management & Dependencies List
              Text(
                'Tasks & Prerequisite Dependencies',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  itemCount: _plan.tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final t = _plan.tasks[idx];
                    final isBlocked = t.isBlocked;
                    return Container(
                      padding: const EdgeInsets.all(AppDimensions.spaceSm),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isBlocked
                              ? AppColors.alertError.withValues(alpha: 0.4)
                              : theme.dividerColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: t.isCompleted,
                            onChanged: isBlocked ? null : (_) => widget.onToggleTask(t.id),
                            activeColor: AppColors.primary,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        t.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isBlocked
                                            ? AppColors.alertError.withValues(alpha: 0.1)
                                            : AppColors.secondary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isBlocked ? 'BLOCKED' : t.status,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isBlocked ? AppColors.alertError : AppColors.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (t.description.isNotEmpty)
                                  Text(
                                    t.description,
                                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                  ),
                                if (t.blockingReason != null && t.blockingReason!.isNotEmpty)
                                  Text(
                                    'Blocking reason: ${t.blockingReason}',
                                    style: const TextStyle(fontSize: 10, color: AppColors.alertError),
                                  ),
                                if (t.dependsOnTaskIds.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Wrap(
                                      spacing: 4,
                                      children: [
                                        const Text('Prerequisites:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                        ...t.dependsOnTaskIds.map(
                                          (depId) => Chip(
                                            visualDensity: VisualDensity.compact,
                                            label: Text('Task #$depId', style: const TextStyle(fontSize: 9)),
                                            deleteIcon: const Icon(Icons.close, size: 10),
                                            onDeleted: () => widget.onRemoveDependency(t.id, depId),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 20),
              // Action Controls
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Resume in Chat'),
                    onPressed: widget.onResumeInChat,
                  ),
                  if (_plan.isInProgress)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.pause, size: 16),
                      label: const Text('Pause / Continue'),
                      onPressed: () => _showStatusDialog('CONTINUED'),
                    ),
                  if (_plan.isContinued || _plan.lifecycleStatus == 'NOT_STARTED')
                    OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Start / Resume Plan'),
                      onPressed: () => _showStatusDialog('IN_PROGRESS'),
                    ),
                  if (!_plan.isCompleted)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Complete Plan'),
                      onPressed: () => _showStatusDialog('COMPLETED'),
                    ),
                  if (!_plan.isCancelled && !_plan.isCompleted)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel Plan'),
                      onPressed: () => _showStatusDialog('CANCELLED'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

