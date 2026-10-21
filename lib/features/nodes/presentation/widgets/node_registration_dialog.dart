import 'package:flutter/material.dart';
import '../../../../core/api/api_dtos.dart';
import '../../../../core/api/api_errors.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_button.dart';
import '../../../zones/domain/models/monitoring_zone.dart';
import '../../domain/models/models.dart';

class NodeRegistrationDialog extends StatefulWidget {
  final List<NodeDiscoveryInfo> discoveredNodes;
  final List<MonitoringZone> zones;
  final Future<bool> Function(NodeRegistrationRequestDto request) onRegister;
  final Future<List<NodeDiscoveryInfo>> Function()? onRefresh;

  const NodeRegistrationDialog({
    super.key,
    required this.discoveredNodes,
    this.zones = const [],
    required this.onRegister,
    this.onRefresh,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<NodeDiscoveryInfo> discoveredNodes,
    List<MonitoringZone> zones = const [],
    required Future<bool> Function(NodeRegistrationRequestDto request) onRegister,
    Future<List<NodeDiscoveryInfo>> Function()? onRefresh,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => NodeRegistrationDialog(
        discoveredNodes: discoveredNodes,
        zones: zones,
        onRegister: onRegister,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<NodeRegistrationDialog> createState() => _NodeRegistrationDialogState();
}

class _NodeRegistrationDialogState extends State<NodeRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _localXController;
  late final TextEditingController _localYController;

  int _selectedIndex = 0;
  String _selectedZoneId = 'UNASSIGNED';
  String _selectedFieldId = '1';
  final int _selectedInterval = 3;
  bool _isLoading = false;
  String? _errorMessage;

  late List<NodeDiscoveryInfo> _nodesList;
  bool _isRefreshing = false;

  NodeDiscoveryInfo? get _selectedNode =>
      _nodesList.isNotEmpty && _selectedIndex < _nodesList.length
          ? _nodesList[_selectedIndex]
          : null;

  @override
  void initState() {
    super.initState();
    _nodesList = List.from(widget.discoveredNodes);
    _localXController = TextEditingController(text: '50.0');
    _localYController = TextEditingController(text: '50.0');

    final first = _nodesList.firstOrNull;
    if (first?.existingZoneId != null) {
      _selectedZoneId = '${first!.existingZoneId}';
    } else if (widget.zones.isNotEmpty) {
      _selectedZoneId = widget.zones.first.id;
    } else {
      _selectedZoneId = 'UNASSIGNED';
    }
  }

  @override
  void dispose() {
    _localXController.dispose();
    _localYController.dispose();
    super.dispose();
  }

  Future<void> _refreshNodes() async {
    if (widget.onRefresh == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final updated = await widget.onRefresh!();
      if (mounted) {
        setState(() {
          _nodesList = updated;
          if (_selectedIndex >= _nodesList.length) {
            _selectedIndex = _nodesList.isEmpty ? 0 : _nodesList.length - 1;
          }
          final selected = _selectedNode;
          if (selected?.existingZoneId != null) {
            _selectedZoneId = '${selected!.existingZoneId}';
          }
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _errorMessage = 'Refresh failed: $e';
        });
      }
    }
  }

  void _selectNode(int index) {
    setState(() {
      _selectedIndex = index;
      final node = _nodesList[index];
      if (node.existingZoneId != null) {
        _selectedZoneId = '${node.existingZoneId}';
      } else {
        _selectedZoneId = 'UNASSIGNED';
      }
    });
  }

  Future<void> _submit() async {
    final node = _selectedNode;
    if (node == null) return;
    if (node.isExpired) {
      setState(() {
        _errorMessage = 'Pairing request has expired (>30m limit). Please trigger a new pairing request from the physical ArvaNode.';
      });
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final displayName = node.id.isNotEmpty
        ? node.id
        : (node.macAddress.isNotEmpty
            ? 'ESP32 Node (${node.macAddress.split(':').last})'
            : 'ESP32 Node');

    final request = NodeRegistrationRequestDto(
      macAddress: node.macAddress,
      displayName: displayName,
      fieldId: _selectedFieldId,
      zoneId: _selectedZoneId,
      latitude: 14.1520,
      longitude: 121.2425,
      localX: double.tryParse(_localXController.text.trim()) ?? 50.0,
      localY: double.tryParse(_localYController.text.trim()) ?? 50.0,
      transmissionIntervalSeconds: _selectedInterval,
    );

    try {
      final success = await widget.onRegister(request);
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to pair node. Please verify network connectivity and try again.';
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNodes = _nodesList.isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      title: Row(
        children: [
          const Icon(Icons.sensors, color: AppColors.primary),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Text(
              hasNodes ? 'Approve & Pair Hardware Node' : 'Hardware Node Discovery',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.onRefresh != null)
            _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                    tooltip: 'Refresh Pending Requests',
                    onPressed: _refreshNodes,
                  ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: hasNodes ? _buildPairingForm(theme) : _buildEmptyState(theme),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: Text(hasNodes ? 'Cancel' : 'Close'),
        ),
        if (hasNodes)
          AquaButton(
            label: _isLoading
                ? 'Pairing...'
                : (_selectedNode?.isExpired == true ? 'Pairing Expired' : 'Approve & Pair Node'),
            icon: Icons.check,
            onPressed: (_isLoading || _selectedNode?.isExpired == true) ? null : _submit,
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceLg, horizontal: AppDimensions.spaceSm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sensors_off_outlined,
              size: 44,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          Text(
            'No Nodes Requested to Pair',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Text(
            'Hardware nodes must press their physical pairing button to broadcast a pairing request before they can be discovered and paired with the gateway.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          if (widget.onRefresh != null) ...[
            const SizedBox(height: AppDimensions.spaceMd),
            OutlinedButton.icon(
              onPressed: _isRefreshing ? null : _refreshNodes,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 16),
              label: Text(_isRefreshing ? 'Scanning...' : 'Check for Pending Nodes'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPairingForm(ThemeData theme) {
    final selected = _selectedNode!;
    final displayName = selected.id.isNotEmpty
        ? selected.id
        : (selected.macAddress.isNotEmpty
            ? 'ESP32 Node (${selected.macAddress.split(':').last})'
            : 'ESP32 Node');

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.error),
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

            // Selection list if multiple nodes requested pairing
            if (_nodesList.length > 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nodes Requesting to Pair (${_nodesList.length}):',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Tap to select',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _nodesList.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.spaceSm),
                  itemBuilder: (context, index) {
                    final node = _nodesList[index];
                    final isSelected = index == _selectedIndex;
                    return InkWell(
                      onTap: () => _selectNode(index),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 140,
                        padding: const EdgeInsets.all(AppDimensions.spaceSm),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.borderOf(context),
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
                                Icon(
                                  Icons.sensors,
                                  size: 16,
                                  color: isSelected ? AppColors.primary : Colors.grey,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'PAIR REQ',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              node.id.isNotEmpty ? node.id : node.macAddress,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              node.macAddress,
                              style: const TextStyle(
                                fontSize: 9,
                                fontFamily: 'monospace',
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
            ],

            // Read-Only Selected Hardware Card
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Selected Hardware Device',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (selected.isExpired ? AppColors.error : AppColors.success).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          selected.isExpired ? 'EXPIRED' : selected.pairingStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: selected.isExpired ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selected.isExpired) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.timer_off_outlined, size: 16, color: AppColors.error),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pairing window expired (>30m). Press the activation/pairing button on ArvaNode to generate a fresh request.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Display Name',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayName,
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hardware MAC Address',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selected.macAddress,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Model: ${selected.hardwareModel}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.wifi, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${selected.rssiDbm} dBm',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Target Farm Field Selection
            DropdownButtonFormField<String>(
              value: _selectedFieldId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Target Farm Field',
                prefixIcon: Icon(Icons.landscape, size: 18),
              ),
              items: const [
                DropdownMenuItem(value: '1', child: Text('Main Rice Field (Field 1)')),
                DropdownMenuItem(value: 'field-main', child: Text('Main Field (Canonical)')),
              ],
              onChanged: (v) => setState(() => _selectedFieldId = v ?? '1'),
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Assigned Monitoring Zone
            Builder(
              builder: (context) {
                final List<DropdownMenuItem<String>> zoneItems = [
                  const DropdownMenuItem(
                    value: 'UNASSIGNED',
                    child: Text('Unassigned (Pair Only — Assign Later)'),
                  ),
                ];
                if (widget.zones.isNotEmpty) {
                  for (final z in widget.zones) {
                    if (!zoneItems.any((item) => item.value == z.id)) {
                      zoneItems.add(
                        DropdownMenuItem(
                          value: z.id,
                          child: Text('${z.code} • ${z.name}'),
                        ),
                      );
                    }
                  }
                } else {
                  zoneItems.addAll(const [
                    DropdownMenuItem(value: 'zone-1', child: Text('Zone 1 (Q1)')),
                    DropdownMenuItem(value: 'zone-2', child: Text('Zone 2 (Q2)')),
                    DropdownMenuItem(value: 'zone-3', child: Text('Zone 3 (Q3)')),
                    DropdownMenuItem(value: 'zone-4', child: Text('Zone 4 (Q4)')),
                  ]);
                }
                final currentVal = zoneItems.any((i) => i.value == _selectedZoneId)
                    ? _selectedZoneId
                    : 'UNASSIGNED';
                return DropdownButtonFormField<String>(
                  value: currentVal,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assign to Monitoring Zone',
                    prefixIcon: Icon(Icons.grid_view, size: 18),
                  ),
                  items: zoneItems,
                  onChanged: (v) => setState(() => _selectedZoneId = v ?? 'UNASSIGNED'),
                );
              },
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Local Coordinates
            Text(
              'Field Spatial Coordinates (Meters):',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _localXController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'X Offset (m)',
                      hintText: '0.0 - 100.0',
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: TextFormField(
                    controller: _localYController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Y Offset (m)',
                      hintText: '0.0 - 100.0',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Telemetry Transmission Interval (Standardized 3s Policy)
            Text(
              'Telemetry Transmission Interval:',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_clock, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '3 seconds (Standard ArvaCore Real-time IoT Policy)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
