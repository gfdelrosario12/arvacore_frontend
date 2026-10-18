import 'package:flutter/material.dart';
import '../../../../core/api/api_dtos.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_button.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../control/domain/models/control_enums.dart';
import '../../domain/models/models.dart';

class NodeReplacementDialog extends StatefulWidget {
  final Esp32Node targetNode;
  final List<Esp32Node> availableNodes;
  final ControlUserRole userRole;
  final Future<NodeReplacementResult?> Function(NodeReplacementRequestDto request) onReplace;

  const NodeReplacementDialog({
    super.key,
    required this.targetNode,
    required this.availableNodes,
    required this.userRole,
    required this.onReplace,
  });

  static Future<NodeReplacementResult?> show(
    BuildContext context, {
    required Esp32Node targetNode,
    required List<Esp32Node> availableNodes,
    required ControlUserRole userRole,
    required Future<NodeReplacementResult?> Function(NodeReplacementRequestDto request) onReplace,
  }) {
    return showDialog<NodeReplacementResult?>(
      context: context,
      builder: (context) => NodeReplacementDialog(
        targetNode: targetNode,
        availableNodes: availableNodes,
        userRole: userRole,
        onReplace: onReplace,
      ),
    );
  }

  @override
  State<NodeReplacementDialog> createState() => _NodeReplacementDialogState();
}

class _NodeReplacementDialogState extends State<NodeReplacementDialog> {
  String? _selectedReplacementId;
  final _reasonController = TextEditingController();
  bool _transferCalibration = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default candidate: first available node that isn't the target node itself
    final candidates = _candidates;
    if (candidates.isNotEmpty) {
      _selectedReplacementId = candidates.first.id;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _isAuthorized =>
      widget.userRole == ControlUserRole.admin ||
      widget.userRole == ControlUserRole.operator;

  List<Esp32Node> get _candidates => widget.availableNodes
      .where((n) => n.id != widget.targetNode.id && !n.lifecycleState.isTerminal)
      .toList();

  Future<void> _submit() async {
    if (!_isAuthorized) {
      setState(() {
        _errorMessage = 'Unauthorized: Viewers cannot execute node replacement.';
      });
      return;
    }

    if (_selectedReplacementId == null) {
      setState(() {
        _errorMessage = 'Please select a replacement node.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final request = NodeReplacementRequestDto(
        replacementNodeId: _selectedReplacementId!,
        reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
        transferCalibration: _transferCalibration,
      );
      final result = await widget.onReplace(request);
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (result != null) {
          Navigator.of(context).pop(result);
        } else {
          setState(() {
            _errorMessage = 'Node replacement failed on backend.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = widget.targetNode;
    final candidates = _candidates;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.swap_horizontal_circle_outlined,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replace Sensor Node',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Atomic hardware swap with measurement preservation',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Authorization Warning Banner if viewer
              if (!_isAuthorized)
                Container(
                  margin: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
                  padding: const EdgeInsets.all(AppDimensions.spaceSm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, size: 20, color: AppColors.warning),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: Text(
                          'Viewing as ${widget.userRole.name.toUpperCase()}. Operators or Admins only.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Current Node Info
              AquaCard(
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT ACTIVE NODE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          target.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(target.lifecycleState).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            border: Border.all(color: _statusColor(target.lifecycleState)),
                          ),
                          child: Text(
                            target.lifecycleState.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _statusColor(target.lifecycleState),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MAC: ${target.macAddress} • Point: ${target.assignedPointId ?? 'Unassigned'} • Zone: ${target.assignedZoneId ?? 'Unassigned'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Preservation Guarantee Badge
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Text(
                        'Historical sensor readings & AWD benchmarks on ${target.assignedZoneId ?? 'the zone'} will remain intact.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Replacement Selection
              Text(
                'Select Replacement Hardware',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppDimensions.spaceXs),
              if (candidates.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: const Text('No eligible replacement nodes available.'),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedReplacementId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: candidates.map((node) {
                    return DropdownMenuItem<String>(
                      value: node.id,
                      child: Text(
                        '${node.displayName} (${node.macAddress}) [${node.lifecycleState.label}]',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _isAuthorized && !_isSubmitting
                      ? (val) => setState(() => _selectedReplacementId = val)
                      : null,
                ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Reason field
              Text(
                'Replacement Reason (Audit Log)',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppDimensions.spaceXs),
              TextField(
                controller: _reasonController,
                enabled: _isAuthorized && !_isSubmitting,
                decoration: InputDecoration(
                  hintText: 'e.g. Battery depleted, physical water tube damage',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),

              // Transfer Calibration Checkbox
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Transfer Calibration Offsets'),
                subtitle: const Text('Retains tube depth & sensor datum calibration'),
                value: _transferCalibration,
                onChanged: _isAuthorized && !_isSubmitting
                    ? (val) => setState(() => _transferCalibration = val)
                    : null,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ],

              const SizedBox(height: AppDimensions.spaceLg),

              // Actions
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppDimensions.spaceSm,
                runSpacing: AppDimensions.spaceSm,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  AquaButton(
                    label: _isSubmitting ? 'Swapping...' : 'Execute Replacement',
                    icon: Icons.swap_horiz,
                    isFullWidth: false,
                    isLoading: _isSubmitting,
                    onPressed: _isAuthorized && candidates.isNotEmpty && !_isSubmitting
                        ? _submit
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(NodeLifecycleStatus status) {
    switch (status) {
      case NodeLifecycleStatus.active:
        return AppColors.success;
      case NodeLifecycleStatus.maintenance:
        return AppColors.warning;
      case NodeLifecycleStatus.offline:
      case NodeLifecycleStatus.disabled:
        return AppColors.error;
      case NodeLifecycleStatus.discovered:
      case NodeLifecycleStatus.provisioning:
      case NodeLifecycleStatus.provisioned:
        return AppColors.primary;
      case NodeLifecycleStatus.replaced:
      case NodeLifecycleStatus.decommissioned:
      case NodeLifecycleStatus.unregistered:
        return AppColors.zoneOffline;
    }
  }
}

