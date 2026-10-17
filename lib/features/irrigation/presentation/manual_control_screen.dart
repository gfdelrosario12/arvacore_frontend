import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/widgets.dart';
import '../../auth/domain/models/user_role.dart';
import '../../control/presentation/widgets/auto_irrigation_config_dialog.dart';
import '../../control/presentation/widgets/irrigation_audit_log_section.dart';
import '../domain/models/auto_irrigation_status.dart';
import '../domain/models/manual_irrigation_control.dart';
import 'providers/irrigation_notifier.dart';
import 'providers/manual_control_notifier.dart';
import 'widgets/emergency_stop_button.dart';
import 'widgets/manual_control_confirmation_dialog.dart';

class ManualControlScreen extends StatefulWidget {
  final ManualControlNotifier? manualNotifier;
  final IrrigationNotifier? irrigationNotifier;
  final UserRole userRole;
  final String userId;
  final String userName;

  const ManualControlScreen({
    super.key,
    this.manualNotifier,
    this.irrigationNotifier,
    this.userRole = UserRole.operator,
    this.userId = 'usr-op-01',
    this.userName = 'Field Operator',
  });

  @override
  State<ManualControlScreen> createState() => _ManualControlScreenState();
}

class _ManualControlScreenState extends State<ManualControlScreen> {
  late ManualControlNotifier _manualNotifier;
  late IrrigationNotifier _irrigationNotifier;

  @override
  void initState() {
    super.initState();
    _manualNotifier = widget.manualNotifier ?? ManualControlNotifier();
    _manualNotifier.addListener(_onStateChanged);
    _irrigationNotifier = widget.irrigationNotifier ?? IrrigationNotifier();
    _irrigationNotifier.addListener(_onStateChanged);
    _irrigationNotifier.loadAutoIrrigationData();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (widget.manualNotifier == null) {
      _manualNotifier.dispose();
    } else {
      _manualNotifier.removeListener(_onStateChanged);
    }
    if (widget.irrigationNotifier == null) {
      _irrigationNotifier.dispose();
    } else {
      _irrigationNotifier.removeListener(_onStateChanged);
    }
    super.dispose();
  }

  Future<void> _handleStartManualPulse() async {
    final result = await ManualControlConfirmationDialog.show(
      context: context,
      initialDurationMinutes: 30,
      actionType: 'start',
    );

    if (result != null && result.confirmed) {
      final ok = await _manualNotifier.startManualIrrigation(
        operatorId: widget.userId,
        operatorName: widget.userName,
        operatorRole: widget.userRole.name,
        durationMinutes: result.durationMinutes,
        rationale: result.rationale,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Manual irrigation pulse dispatched for ${result.durationMinutes}m.'
                : _manualNotifier.state.errorMessage ?? 'Failed to start manual irrigation.'),
            backgroundColor: ok ? AppColors.pumpActive : AppColors.alertError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleStopManualIrrigation() async {
    final result = await ManualControlConfirmationDialog.show(
      context: context,
      actionType: 'stop',
    );

    if (result != null && result.confirmed) {
      final ok = await _manualNotifier.stopManualIrrigation(
        operatorId: widget.userId,
        operatorName: widget.userName,
        operatorRole: widget.userRole.name,
        rationale: result.rationale,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Manual irrigation stopped. System entered cooldown.'
                : _manualNotifier.state.errorMessage ?? 'Failed to stop manual irrigation.'),
            backgroundColor: ok ? AppColors.primary : AppColors.alertError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleEmergencyStop() async {
    final ok = await _manualNotifier.triggerEmergencyStop(
      operatorId: widget.userId,
      operatorName: widget.userName,
      operatorRole: widget.userRole.name,
      rationale: 'High-priority Emergency Stop button engaged',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'EMERGENCY STOP EXECUTED! Pump halted immediately.'
              : _manualNotifier.state.errorMessage ?? 'Emergency stop executed locally.'),
          backgroundColor: AppColors.alertError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleConfigureAutomation() async {
    final updated = await AutoIrrigationConfigDialog.show(
      context,
      _irrigationNotifier.state.config,
    );
    if (updated != null) {
      final ok = await _irrigationNotifier.updateConfig(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Automation configuration updated.'
                : 'Failed to update configuration.'),
            backgroundColor: ok ? AppColors.primary : AppColors.alertError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleClearLockout() async {
    final ok = await _irrigationNotifier.clearFaultLockout(
      clearedBy: widget.userRole.name,
      resolutionNote: 'Cleared by operator via Manual Control Screen',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Fault lockout successfully cleared. Automation restored to standby.'
              : 'Failed to clear fault lockout.'),
          backgroundColor: ok ? AppColors.pumpActive : AppColors.alertError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manualState = _manualNotifier.state;
    final isAuthorized = _manualNotifier.isAuthorizedRole(widget.userRole.name);

    return ResponsiveContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header & Target Scope Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manual Control',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dedicated manual override & central field control interface',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'TARGET: ${ManualIrrigationCommand.fieldWideScope}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Emergency Fallback & Override Notice Banner
            _buildEmergencyFallbackBanner(theme),
            const SizedBox(height: AppDimensions.spaceMd),

            // Emergency Stop Interlock Button
            EmergencyStopButton(
              onPressed: _handleEmergencyStop,
              isLoading: manualState.isLoading && manualState.isEmergencyStopped,
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Automation Supervisor Card
            _buildAutoSupervisorCard(),
            const SizedBox(height: AppDimensions.spaceMd),

            // Role Authorization Warning
            if (!isAuthorized) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                margin: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.alertWarning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: AppColors.alertWarning),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: AppColors.alertWarning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Role "${widget.userRole.name.toUpperCase()}" lacks operator privileges. Manual triggers are disabled.',
                        style: const TextStyle(
                          color: AppColors.alertWarning,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Active State Banner
            _buildManualStateCard(manualState),
            const SizedBox(height: AppDimensions.spaceMd),

            // Manual Control Buttons Card
            AquaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Irrigation Controls',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Direct field-level manual start and stop pump execution',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.pumpActive,
                            padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceSm),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start'),
                          onPressed: (isAuthorized && manualState.canDispatchCommand && !manualState.isPumpRunning)
                              ? _handleStartManualPulse
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.alertError,
                            side: const BorderSide(color: AppColors.alertError),
                            padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceSm),
                          ),
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          onPressed: (isAuthorized && manualState.canDispatchCommand)
                              ? _handleStopManualIrrigation
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Audit Trail Section
            IrrigationAuditLogSection(
              auditLogs: _irrigationNotifier.state.auditLogs,
              onRefresh: () => _irrigationNotifier.loadAutoIrrigationData(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualStateCard(ManualControlState manualState) {
    final theme = Theme.of(context);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (manualState.modeState) {
      case ManualOverrideModeState.idle:
        statusColor = theme.hintColor;
        statusText = 'IDLE';
        statusIcon = Icons.check_circle_outline;
        break;
      case ManualOverrideModeState.pendingConfirmation:
        statusColor = Colors.orange;
        statusText = 'PENDING';
        statusIcon = Icons.help_outline;
        break;
      case ManualOverrideModeState.pendingAck:
        statusColor = Colors.amber.shade800;
        statusText = 'PENDING ACK';
        statusIcon = Icons.hourglass_top;
        break;
      case ManualOverrideModeState.active:
        statusColor = AppColors.pumpActive;
        statusText = 'MANUAL ACTIVE';
        statusIcon = Icons.play_circle_fill;
        break;
      case ManualOverrideModeState.cooldown:
        statusColor = Colors.teal.shade700;
        statusText = 'COOLDOWN';
        statusIcon = Icons.timelapse;
        break;
      case ManualOverrideModeState.emergencyStopped:
        statusColor = AppColors.alertError;
        statusText = 'EMERGENCY STOP';
        statusIcon = Icons.warning;
        break;
      case ManualOverrideModeState.failed:
        statusColor = AppColors.alertError;
        statusText = 'FAILED';
        statusIcon = Icons.error;
        break;
    }

    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Override Supervisor Status',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Flexible(
                child: StatusBadge.deviceStatus(
                  statusText,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (manualState.activeCommand != null) ...[
            const SizedBox(height: 8),
            Text(
              'Operator: ${manualState.activeCommand!.operatorName} • Target: ${manualState.activeCommand!.targetScope} • Duration: ${manualState.targetDurationMinutes ?? manualState.activeCommand!.durationMinutes} mins',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (manualState.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              manualState.errorMessage!,
              style: const TextStyle(color: AppColors.alertError, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAutoSupervisorCard() {
    final theme = Theme.of(context);
    final autoState = _irrigationNotifier.state;
    final status = autoState.status;
    final config = autoState.config;

    Color badgeColor;
    IconData badgeIcon;
    switch (status.state) {
      case AutoIrrigationState.disabled:
        badgeColor = theme.hintColor;
        badgeIcon = Icons.power_settings_new;
        break;
      case AutoIrrigationState.standby:
        badgeColor = AppColors.primary;
        badgeIcon = Icons.check_circle_outline;
        break;
      case AutoIrrigationState.evaluating:
        badgeColor = Colors.orange.shade700;
        badgeIcon = Icons.sync;
        break;
      case AutoIrrigationState.pendingAck:
        badgeColor = Colors.amber.shade800;
        badgeIcon = Icons.hourglass_top;
        break;
      case AutoIrrigationState.irrigating:
        badgeColor = Colors.purple.shade600;
        badgeIcon = Icons.smart_toy;
        break;
      case AutoIrrigationState.cooldown:
        badgeColor = Colors.teal.shade700;
        badgeIcon = Icons.timelapse;
        break;
      case AutoIrrigationState.faultLocked:
        badgeColor = AppColors.alertError;
        badgeIcon = Icons.lock;
        break;
    }

    final remainingCooldown = status.remainingCooldown();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: badgeColor.withValues(alpha: 0.3)),
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
                      Icon(badgeIcon, color: badgeColor, size: 22),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Automation Supervisor',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Centralized field-level autonomous control',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    status.state.label.toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            const Divider(),
            const SizedBox(height: AppDimensions.spaceSm),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppDimensions.spaceSm,
              runSpacing: AppDimensions.spaceSm,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (status.isInCooldown && remainingCooldown != null)
                      Text(
                        'Cooldown Active: ${remainingCooldown.inMinutes}m ${remainingCooldown.inSeconds % 60}s remaining',
                        style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    if (status.isFaultLocked)
                      Text(
                        'Lockout: ${status.lockoutReason ?? "Hardware fault"}',
                        style: const TextStyle(color: AppColors.alertError, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    Text(
                      config.isEnabled
                          ? 'Window: ${config.allowedHoursStart.toString().padLeft(2, "0")}:00 - ${config.allowedHoursEnd.toString().padLeft(2, "0")}:00'
                          : 'Field automation is currently disabled.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppDimensions.spaceSm,
                  runSpacing: AppDimensions.spaceSm,
                  children: [
                    if (status.isFaultLocked) ...[
                      AuthorizationGate(
                        requiredRole: UserRole.operator,
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.alertError.withValues(alpha: 0.15),
                            foregroundColor: AppColors.alertError,
                          ),
                          icon: const Icon(Icons.lock_open, size: 16),
                          label: const Text('Clear Lockout'),
                          onPressed: _handleClearLockout,
                        ),
                      ),
                    ],
                    AuthorizationGate(
                      requiredRole: UserRole.operator,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.tune, size: 16),
                        label: const Text('Configure'),
                        onPressed: _handleConfigureAutomation,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyFallbackBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Text(
              'Emergency Resort & Manual Fallback — Primary irrigation is managed autonomously by the ArvaCore controller based on water-level thresholds. Use centralized controls for emergency intervention or system override.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
