import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../../core/widgets/aqua_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/models/arvagate_models.dart';
import '../../data/repositories/arvagate_repository.dart';

class ArvaGateSectionWidget extends StatefulWidget {
  final bool isOperator;
  final String deviceId;

  const ArvaGateSectionWidget({
    super.key,
    required this.isOperator,
    this.deviceId = 'ARVAGATE-CTRL-01',
  });

  @override
  State<ArvaGateSectionWidget> createState() => _ArvaGateSectionWidgetState();
}

class _ArvaGateSectionWidgetState extends State<ArvaGateSectionWidget> {
  final ArvaGateRepository _repo = ArvaGateRepository();
  ArvaGateSubsystemStatus? _status;
  bool _isLoading = false;
  String? _pendingGateAction;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    final s = await _repo.fetchStatus(deviceId: widget.deviceId);
    if (mounted) {
      setState(() {
        _status = s;
        _isLoading = false;
      });
    }
  }

  Future<void> _actuateGate(int gateIndex, String action) async {
    setState(() => _pendingGateAction = 'Gate $gateIndex $action');
    final success = await _repo.dispatchCommand(
      deviceId: widget.deviceId,
      targetGates: gateIndex.toString(),
      action: action,
      rationale: 'Manual operator action on Gate $gateIndex',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'ArvaGate: Command $action dispatched for Gate $gateIndex.'
              : 'Failed to dispatch command for Gate $gateIndex.'),
          backgroundColor: success ? AppColors.pumpActive : AppColors.alertError,
        ),
      );
      setState(() => _pendingGateAction = null);
      await _loadStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _status;

    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.fence_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ArvaGate 3-Gate Subsystem', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(s?.displayName ?? 'ArvaGate Central Canal Controller', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (s != null)
                StatusBadge.deviceStatus(
                  s.connectivityStatus,
                  compact: true,
                ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _isLoading ? null : _loadStatus,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          if (_isLoading && s == null)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
          else if (s != null) ...[
            // 3 Independent Gates
            ...s.gates.map((g) => _buildGateTile(g, theme)),
            const SizedBox(height: AppDimensions.spaceSm),

            // Recent Event Log snippet
            if (s.recentEvents.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 4),
              Text('Recent Gate Operations', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...s.recentEvents.take(3).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          e.eventType == 'COMMAND_ACK' ? Icons.check_circle_outline : Icons.outbox_rounded,
                          size: 14,
                          color: e.eventType == 'COMMAND_ACK' ? AppColors.pumpActive : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${e.eventType}${e.gateIndex != null ? ' (Gate ${e.gateIndex})' : ''}: ${e.details ?? ''}',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildGateTile(ArvaGateModel gate, ThemeData theme) {
    final isOpen = gate.isOpen;
    final isActuating = gate.isActuating;
    final confirmed = gate.physicalConfirmed;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(
          color: isActuating
              ? AppColors.alertWarning
              : (isOpen ? AppColors.pumpActive.withValues(alpha: 0.5) : theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (isOpen ? AppColors.pumpActive : AppColors.primary).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${gate.gateIndex}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOpen ? AppColors.pumpActive : AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gate.gateLabel, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Text('State: ${gate.currentState}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        if (confirmed)
                          const Row(
                            children: [
                              Icon(Icons.verified, size: 12, color: AppColors.pumpActive),
                              SizedBox(width: 2),
                              Text('Feedback Confirmed', style: TextStyle(fontSize: 10, color: AppColors.pumpActive)),
                            ],
                          )
                        else
                          const Text('(Feedback unconfirmed)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.isOperator) ...[
                if (isOpen)
                  AquaButton(
                    label: 'Close',
                    icon: Icons.close,
                    variant: AquaButtonVariant.secondary,
                    onPressed: _pendingGateAction != null ? null : () => _actuateGate(gate.gateIndex, 'CLOSE'),
                  )
                else
                  AquaButton(
                    label: 'Open',
                    icon: Icons.lock_open,
                    variant: AquaButtonVariant.primary,
                    onPressed: _pendingGateAction != null ? null : () => _actuateGate(gate.gateIndex, 'OPEN'),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined, color: AppColors.alertError),
                  tooltip: 'Emergency Stop Gate',
                  onPressed: _pendingGateAction != null ? null : () => _actuateGate(gate.gateIndex, 'STOP'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

