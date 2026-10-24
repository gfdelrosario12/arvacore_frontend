import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../domain/models/farming_chat_models.dart';

class PlantingTaskChecklistWidget extends StatelessWidget {
  final List<PlantingTaskModel> tasks;
  final int planId;
  final Function(int taskId) onToggleTask;
  final bool isInteractive;

  const PlantingTaskChecklistWidget({
    super.key,
    required this.tasks,
    required this.planId,
    required this.onToggleTask,
    this.isInteractive = true,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // Group tasks by category
    final systemTasks = tasks.where((t) => t.category == 'SYSTEM_AUTOMATED').toList();
    final farmerTasks = tasks.where((t) => t.category == 'FARMER_MANUAL').toList();
    final equipmentTasks = tasks.where((t) => t.category == 'EQUIPMENT_INFO').toList();
    final blockedTasks = tasks.where((t) => t.category == 'SAFETY_BLOCKED' || t.status == 'BLOCKED').toList();

    return Container(
      margin: const EdgeInsets.only(top: AppDimensions.spaceSm),
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rtl_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: AppDimensions.spaceXs),
              Text(
                'Planting Preparation Checklist',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          if (blockedTasks.isNotEmpty) ...[
            _buildCategoryHeader('Safety Blocked Items', Icons.block, AppColors.alertDanger, theme),
            ...blockedTasks.map((t) => _buildTaskTile(t, theme)),
            const SizedBox(height: AppDimensions.spaceSm),
          ],
          if (systemTasks.isNotEmpty) ...[
            _buildCategoryHeader('System Automated (ArvaCore)', Icons.smart_toy_outlined, AppColors.secondary, theme),
            ...systemTasks.map((t) => _buildTaskTile(t, theme)),
            const SizedBox(height: AppDimensions.spaceSm),
          ],
          if (farmerTasks.isNotEmpty) ...[
            _buildCategoryHeader('Farmer Manual Tasks', Icons.pan_tool_outlined, AppColors.primary, theme),
            ...farmerTasks.map((t) => _buildTaskTile(t, theme)),
            const SizedBox(height: AppDimensions.spaceSm),
          ],
          if (equipmentTasks.isNotEmpty) ...[
            _buildCategoryHeader('Equipment & Verification', Icons.handyman_outlined, AppColors.alertWarning, theme),
            ...equipmentTasks.map((t) => _buildTaskTile(t, theme)),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, IconData icon, Color color, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(PlantingTaskModel task, ThemeData theme) {
    final isBlocked = task.isBlocked;
    final isDone = task.isCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: isBlocked
                ? const Icon(Icons.cancel, color: AppColors.alertDanger, size: 18)
                : Checkbox(
                    value: isDone,
                    onChanged: (isInteractive && !task.isAutomated)
                        ? (_) => onToggleTask(task.id)
                        : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: AppColors.primary,
                  ),
          ),
          const SizedBox(width: AppDimensions.spaceXs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isBlocked
                        ? AppColors.alertDanger
                        : (isDone ? theme.textTheme.bodySmall?.color : null),
                  ),
                ),
                if (task.description.isNotEmpty)
                  Text(
                    task.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                    ),
                  ),
                if (task.blockingReason != null && task.blockingReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Blocked: ${task.blockingReason}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: AppColors.alertDanger,
                        fontWeight: FontWeight.w600,
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

