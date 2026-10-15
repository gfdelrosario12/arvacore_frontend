import 'package:flutter/material.dart';
import '../../../../core/api/api_dtos.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_button.dart';
import '../../domain/models/models.dart';

class NodeRegistrationDialog extends StatefulWidget {
  final List<NodeDiscoveryInfo> discoveredNodes;
  final Future<bool> Function(NodeRegistrationRequestDto request) onRegister;

  const NodeRegistrationDialog({
    super.key,
    required this.discoveredNodes,
    required this.onRegister,
  });

  static Future<bool?> show(
    BuildContext context, {
    required List<NodeDiscoveryInfo> discoveredNodes,
    required Future<bool> Function(NodeRegistrationRequestDto request) onRegister,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => NodeRegistrationDialog(
        discoveredNodes: discoveredNodes,
        onRegister: onRegister,
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
  String _selectedZoneId = 'zone-q1';
  final String _selectedFieldId = 'field-main';
  int _selectedInterval = 300;
  bool _isLoading = false;
  String? _errorMessage;

  NodeDiscoveryInfo? get _selectedNode =>
      widget.discoveredNodes.isNotEmpty && _selectedIndex < widget.discoveredNodes.length
          ? widget.discoveredNodes[_selectedIndex]
          : null;

  @override
  void initState() {
    super.initState();
    _localXController = TextEditingController(text: '50.0');
    _localYController = TextEditingController(text: '50.0');

    final first = widget.discoveredNodes.firstOrNull;
    if (first?.existingZoneId != null) {
      _selectedZoneId = 'zone-${first!.existingZoneId}';
    }
  }

  @override
  void dispose() {
    _localXController.dispose();
    _localYController.dispose();
    super.dispose();
  }

  void _selectNode(int index) {
    setState(() {
      _selectedIndex = index;
      final node = widget.discoveredNodes[index];
      if (node.existingZoneId != null) {
        _selectedZoneId = 'zone-${node.existingZoneId}';
      }
    });
  }

  Future<void> _submit() async {
    final node = _selectedNode;
    if (node == null) return;
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

    final success = await widget.onRegister(request);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to pair node. Please verify gateway connectivity and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNodes = widget.discoveredNodes.isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      title: Row(
        children: [
          const Icon(Icons.sensors, color: AppColors.primary),
          const SizedBox(width: AppDimensions.spaceSm),
          Text(
            hasNodes ? 'Approve & Pair Hardware Node' : 'Hardware Node Discovery',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
            label: _isLoading ? 'Pairing...' : 'Approve & Pair Node',
            icon: Icons.check,
            onPressed: _isLoading ? null : _submit,
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
            if (widget.discoveredNodes.length > 1) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nodes Requesting to Pair (${widget.discoveredNodes.length}):',
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
                  itemCount: widget.discoveredNodes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.spaceSm),
                  itemBuilder: (context, index) {
                    final node = widget.discoveredNodes[index];
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
                            color: isSelected ? AppColors.primary : AppColors.border,
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
                border: Border.all(color: AppColors.border),
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
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          selected.pairingStatus,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
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

            // Assigned Monitoring Zone
            DropdownButtonFormField<String>(
              value: _selectedZoneId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Assign to Monitoring Zone',
                prefixIcon: Icon(Icons.grid_view, size: 18),
              ),
              items: const [
                DropdownMenuItem(value: 'zone-q1', child: Text('Zone 1 (Q1)')),
                DropdownMenuItem(value: 'zone-q2', child: Text('Zone 2 (Q2)')),
                DropdownMenuItem(value: 'zone-q3', child: Text('Zone 3 (Q3)')),
                DropdownMenuItem(value: 'zone-q4', child: Text('Zone 4 (Q4)')),
                DropdownMenuItem(value: 'zone-dynamic-east', child: Text('Zone 5 (East)')),
              ],
              onChanged: (v) => setState(() => _selectedZoneId = v ?? 'zone-q1'),
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

            // Base Transmission Interval
            Text(
              'Telemetry Transmission Interval:',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [30, 60, 300, 900].map((interval) {
                return ChoiceChip(
                  label: Text(
                    interval < 60 ? '${interval}s' : '${interval ~/ 60}m',
                  ),
                  selected: _selectedInterval == interval,
                  onSelected: (_) => setState(() => _selectedInterval = interval),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
