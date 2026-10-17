import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../zones/domain/models/monitoring_zone.dart';
import '../../domain/models/esp32_node.dart';

class NodeAssignmentDialog extends StatefulWidget {
  final List<Esp32Node> nodes;
  final List<MonitoringZone> zones;
  final Esp32Node? initialNode;
  final MonitoringZone? initialZone;
  final Future<bool> Function(
    String nodeId, {
    int? fieldId,
    int? monitoringZoneId,
  }) onAssign;
  final Future<MonitoringZone?> Function()? onCreateZone;

  const NodeAssignmentDialog({
    super.key,
    required this.nodes,
    required this.zones,
    this.initialNode,
    this.initialZone,
    required this.onAssign,
    this.onCreateZone,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<Esp32Node> nodes,
    required List<MonitoringZone> zones,
    Esp32Node? initialNode,
    MonitoringZone? initialZone,
    required Future<bool> Function(
      String nodeId, {
      int? fieldId,
      int? monitoringZoneId,
    }) onAssign,
    Future<MonitoringZone?> Function()? onCreateZone,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => NodeAssignmentDialog(
        nodes: nodes,
        zones: zones,
        initialNode: initialNode,
        initialZone: initialZone,
        onAssign: onAssign,
        onCreateZone: onCreateZone,
      ),
    );
  }

  @override
  State<NodeAssignmentDialog> createState() => _NodeAssignmentDialogState();
}

class _NodeAssignmentDialogState extends State<NodeAssignmentDialog> {
  late List<MonitoringZone> _zones;
  Esp32Node? _selectedNode;
  MonitoringZone? _selectedZone;
  bool _isUnassignMode = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _zones = List.from(widget.zones);

    // Initial node selection
    if (widget.initialNode != null) {
      _selectedNode = widget.initialNode;
    } else {
      // Prefer selecting an unassigned node first if available
      final unassigned = widget.nodes.where((n) => n.assignedZoneId == null || n.assignedZoneId!.isEmpty).toList();
      _selectedNode = unassigned.isNotEmpty ? unassigned.first : widget.nodes.firstOrNull;
    }

    // Initial zone selection
    if (widget.initialZone != null) {
      _selectedZone = widget.initialZone;
    } else if (_selectedNode != null && _selectedNode!.assignedZoneId != null) {
      _selectedZone = _resolveZoneForNode(_selectedNode!);
    } else {
      // Find first empty zone if any
      final emptyZone = _zones.where((z) {
        return !widget.nodes.any((n) =>
            n.assignedZoneId == z.id ||
            n.assignedZoneId == z.code ||
            n.assignedZoneId == 'zone-${z.id}' ||
            n.assignedZoneId == z.id.replaceAll(RegExp(r'[^0-9]'), ''));
      }).firstOrNull;
      _selectedZone = emptyZone ?? _zones.firstOrNull;
    }
  }

  MonitoringZone? _resolveZoneForNode(Esp32Node node) {
    if (node.assignedZoneId == null || node.assignedZoneId!.isEmpty) return null;
    return _zones.where((z) =>
        z.id == node.assignedZoneId ||
        z.code == node.assignedZoneId ||
        node.assignedZoneId == 'zone-${z.id}' ||
        node.assignedZoneId == z.id.replaceAll(RegExp(r'[^0-9]'), '')).firstOrNull;
  }

  Esp32Node? _getOccupantOfZone(MonitoringZone zone) {
    return widget.nodes.where((n) =>
        n.id != _selectedNode?.id &&
        (n.assignedZoneId == zone.id ||
            n.assignedZoneId == zone.code ||
            n.assignedZoneId == 'zone-${zone.id}' ||
            n.assignedZoneId == zone.id.replaceAll(RegExp(r'[^0-9]'), ''))).firstOrNull;
  }

  Future<void> _handleConfirm() async {
    if (_selectedNode == null) {
      setState(() => _errorMessage = 'Please select an ArvaNode.');
      return;
    }

    if (!_isUnassignMode && _selectedZone == null) {
      setState(() => _errorMessage = 'Please select a destination monitoring zone.');
      return;
    }

    final currentZone = _resolveZoneForNode(_selectedNode!);
    final targetZone = _selectedZone;

    // Safety: If reassigning an already assigned node to a different position
    if (!_isUnassignMode && currentZone != null && targetZone != null && currentZone.id != targetZone.id) {
      final confirmed = await _showReassignmentConfirmation(
        node: _selectedNode!,
        currentZone: currentZone,
        newZone: targetZone,
      );
      if (confirmed != true) return;
    }

    // Safety: If unassigning
    if (_isUnassignMode && currentZone != null) {
      final confirmed = await _showUnassignConfirmation(
        node: _selectedNode!,
        currentZone: currentZone,
      );
      if (confirmed != true) return;
    }

    // Parse target zone numeric ID
    int? zoneNumericId;
    if (!_isUnassignMode && targetZone != null) {
      zoneNumericId = int.tryParse(targetZone.id.replaceAll(RegExp(r'[^0-9]'), ''));
      if (zoneNumericId == null) {
        // Fallback: look at index in zones list
        final idx = _zones.indexOf(targetZone);
        zoneNumericId = idx >= 0 ? idx + 1 : 1;
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onAssign(
        _selectedNode!.id,
        fieldId: 1,
        monitoringZoneId: _isUnassignMode ? null : zoneNumericId,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _isSaving = false;
            _errorMessage = 'Backend failed to save node assignment. Please retry.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Error saving assignment: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  Future<bool?> _showReassignmentConfirmation({
    required Esp32Node node,
    required MonitoringZone currentZone,
    required MonitoringZone newZone,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Confirm Reassignment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Node ${node.displayName.isNotEmpty ? node.displayName : node.id} is currently assigned to ${currentZone.code} (${currentZone.name}).',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_forward, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Move from ${currentZone.code} ➔ ${newZone.code} (${newZone.name})?',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Telemetry received from this node will now be routed to the new zone in real-time.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Reassign'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showUnassignConfirmation({
    required Esp32Node node,
    required MonitoringZone currentZone,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.link_off, color: AppColors.alertWarning),
            SizedBox(width: 8),
            Text('Unassign ArvaNode'),
          ],
        ),
        content: Text(
          'Remove ${node.displayName.isNotEmpty ? node.displayName : node.id} from position ${currentZone.code}? The node will return to the unassigned pool.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alertWarning),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unassign Node'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unassignedNodes = widget.nodes.where((n) => n.assignedZoneId == null || n.assignedZoneId!.isEmpty).toList();
    final assignedNodes = widget.nodes.where((n) => n.assignedZoneId != null && n.assignedZoneId!.isNotEmpty).toList();

    final currentAssignedZone = _selectedNode != null ? _resolveZoneForNode(_selectedNode!) : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: const Icon(Icons.pin_drop, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign ArvaNode Position',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Map physical hardware node to field monitoring zone',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceSm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
              ],

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Choose Node
                      Text(
                        '1. Select ArvaNode Hardware',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedNode?.id,
                            hint: const Text('Choose a node to position'),
                            items: [
                              if (unassignedNodes.isNotEmpty) ...[
                                const DropdownMenuItem<String>(
                                  enabled: false,
                                  value: '__header_unassigned__',
                                  child: Text(
                                    '--- UNASSIGNED NODES (Ready for placement) ---',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                                  ),
                                ),
                                ...unassignedNodes.map((n) {
                                  return DropdownMenuItem<String>(
                                    value: n.id,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: n.isOnline ? AppColors.success : Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${n.displayName.isNotEmpty ? n.displayName : n.id} [${n.macAddress}]',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const StatusBadge(
                                          label: 'UNASSIGNED',
                                          isCompact: true,
                                          colorOverride: AppColors.warning,
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                              if (assignedNodes.isNotEmpty) ...[
                                const DropdownMenuItem<String>(
                                  enabled: false,
                                  value: '__header_assigned__',
                                  child: Text(
                                    '--- CURRENTLY ASSIGNED NODES (Reassignment) ---',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                                  ),
                                ),
                                ...assignedNodes.map((n) {
                                  final z = _resolveZoneForNode(n);
                                  return DropdownMenuItem<String>(
                                    value: n.id,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: n.isOnline ? AppColors.success : Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${n.displayName.isNotEmpty ? n.displayName : n.id} (In ${z?.code ?? n.assignedZoneId})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        StatusBadge(
                                          label: z?.code ?? 'ASSIGNED',
                                          isCompact: true,
                                          colorOverride: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                            onChanged: (val) {
                              if (val == null || val.startsWith('__header_')) return;
                              final node = widget.nodes.firstWhere((n) => n.id == val);
                              setState(() {
                                _selectedNode = node;
                                final z = _resolveZoneForNode(node);
                                if (z != null) {
                                  _selectedZone = z;
                                }
                              });
                            },
                          ),
                        ),
                      ),

                      if (_selectedNode != null) ...[
                        const SizedBox(height: 8),
                        // Node Diagnostic Pill
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.spaceSm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('Signal (RSSI)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    _selectedNode!.rssiDbm != null ? '${_selectedNode!.rssiDbm} dBm' : '—',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('Battery', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    _selectedNode!.batteryPercent != null ? '${_selectedNode!.batteryPercent}%' : '—',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: (_selectedNode!.batteryPercent ?? 100) < 20 ? AppColors.error : AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('Soil Moisture', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    _selectedNode!.soilMoisturePercent != null
                                        ? '${_selectedNode!.soilMoisturePercent!.toStringAsFixed(1)}%'
                                        : 'Awaiting',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('Water Depth', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    _selectedNode!.waterLevelCm != null
                                        ? '${_selectedNode!.waterLevelCm!.toStringAsFixed(1)} cm'
                                        : 'Awaiting',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.accent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppDimensions.spaceMd),

                      // Section 2: Choose Destination Zone / Position
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '2. Target Monitoring Position',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (widget.onCreateZone != null)
                            TextButton.icon(
                              onPressed: () async {
                                final newZone = await widget.onCreateZone!();
                                if (newZone != null && mounted) {
                                  setState(() {
                                    _zones.add(newZone);
                                    _selectedZone = newZone;
                                  });
                                }
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Position', style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (_selectedNode != null && currentAssignedZone != null) ...[
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Unassign this node (return to unassigned hardware pool)', style: TextStyle(fontSize: 13)),
                          value: _isUnassignMode,
                          activeColor: AppColors.alertWarning,
                          onChanged: (val) {
                            setState(() => _isUnassignMode = val ?? false);
                          },
                        ),
                      ],

                      if (!_isUnassignMode) ...[
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.1,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: _zones.length,
                          itemBuilder: (context, index) {
                            final zone = _zones[index];
                            final isSelected = zone.id == _selectedZone?.id;
                            final occupant = _getOccupantOfZone(zone);
                            final isCurrentOfSelected = currentAssignedZone?.id == zone.id;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedZone = zone;
                                  _isUnassignMode = false;
                                });
                              },
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.12)
                                      : theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : Colors.grey.withValues(alpha: 0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          zone.code,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? AppColors.primary : null,
                                          ),
                                        ),
                                        if (isCurrentOfSelected)
                                          const Text(
                                            'CURRENT',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          )
                                        else if (occupant != null)
                                          Text(
                                            'Occupied',
                                            style: TextStyle(fontSize: 9, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                                          )
                                        else
                                          const Text(
                                            'Available',
                                            style: TextStyle(fontSize: 9, color: AppColors.success, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      zone.name,
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (occupant != null && !isCurrentOfSelected)
                                      Text(
                                        'Has: ${occupant.displayName.isNotEmpty ? occupant.displayName : occupant.id}',
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    else
                                      Text(
                                        '${zone.soilMoisturePercent.toStringAsFixed(1)}% moisture',
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      // Reassignment Warning Callout
                      if (!_isUnassignMode &&
                          currentAssignedZone != null &&
                          _selectedZone != null &&
                          currentAssignedZone.id != _selectedZone!.id) ...[
                        const SizedBox(height: AppDimensions.spaceMd),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.spaceSm),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Relocating ${_selectedNode?.displayName ?? _selectedNode?.id} from ${currentAssignedZone.code} to ${_selectedZone?.code}. Field telemetry routing will update immediately.',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 24),
              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _isUnassignMode ? AppColors.alertWarning : AppColors.primary,
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(_isUnassignMode ? Icons.link_off : Icons.check),
                    label: Text(_isUnassignMode ? 'Unassign Node' : 'Confirm Assignment'),
                    onPressed: _isSaving ? null : _handleConfirm,
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

