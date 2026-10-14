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
  late final TextEditingController _nameController;
  late final TextEditingController _macController;
  late final TextEditingController _devEuiController;
  late final TextEditingController _appKeyController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _localXController;
  late final TextEditingController _localYController;

  bool _isLoRaWANMode = false;
  String _selectedZoneId = 'zone-q1';
  final String _selectedFieldId = 'field-main';
  int _selectedInterval = 300;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final first = widget.discoveredNodes.firstOrNull;
    _macController = TextEditingController(text: first?.macAddress ?? '');
    _devEuiController = TextEditingController(text: '0004A30B001F9876');
    _appKeyController = TextEditingController(text: '2B7E151628AED2A6ABF7158809CF4F3C');
    _nameController = TextEditingController(
      text: first != null
          ? 'ESP32 Node (${first.macAddress.split(':').last})'
          : '',
    );
    _latController = TextEditingController(text: '14.1520');
    _lngController = TextEditingController(text: '121.2425');
    _localXController = TextEditingController(text: '50.0');
    _localYController = TextEditingController(text: '50.0');
  }

  @override
  void dispose() {
    _macController.dispose();
    _devEuiController.dispose();
    _appKeyController.dispose();
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _localXController.dispose();
    _localYController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final macOrDevEui = _isLoRaWANMode ? _devEuiController.text.trim() : _macController.text.trim();

    final request = NodeRegistrationRequestDto(
      macAddress: macOrDevEui,
      displayName: _nameController.text.trim(),
      fieldId: _selectedFieldId,
      zoneId: _selectedZoneId,
      latitude: double.tryParse(_latController.text.trim()),
      longitude: double.tryParse(_lngController.text.trim()),
      localX: double.tryParse(_localXController.text.trim()),
      localY: double.tryParse(_localYController.text.trim()),
      transmissionIntervalSeconds: _selectedInterval,
    );

    final success = await widget.onRegister(request);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Registration failed. Please check parameters.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      title: Row(
        children: [
          const Icon(Icons.sensors, color: AppColors.primary),
          const SizedBox(width: AppDimensions.spaceSm),
          Text(
            _isLoRaWANMode ? 'Register LoRaWAN Sensor Node' : 'Register ESP32 Node',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
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
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                ],

                // Radio Protocol Toggle
                Wrap(
                  spacing: AppDimensions.spaceSm,
                  children: [
                    ChoiceChip(
                      label: const Text('Wi-Fi / Bluetooth'),
                      selected: !_isLoRaWANMode,
                      onSelected: (selected) => setState(() => _isLoRaWANMode = !selected),
                    ),
                    ChoiceChip(
                      label: const Text('LoRaWAN (RFM95W)'),
                      selected: _isLoRaWANMode,
                      onSelected: (selected) => setState(() => _isLoRaWANMode = selected),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceMd),

                // Discovered nodes picker if any
                if (!_isLoRaWANMode && widget.discoveredNodes.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discovered Eligible Nodes (${widget.discoveredNodes.length}):',
                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Select node card to configure',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 125,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.discoveredNodes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.spaceSm),
                      itemBuilder: (context, index) {
                        final disc = widget.discoveredNodes[index];
                        final isSelected = _macController.text == disc.macAddress ||
                            _nameController.text.contains(disc.id);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _macController.text = disc.macAddress;
                              _nameController.text = disc.id.isNotEmpty ? disc.id : 'ESP32 Node (${disc.macAddress.split(':').last})';
                              if (disc.existingZoneId != null) {
                                _selectedZoneId = 'zone-${disc.existingZoneId}';
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 130,
                            padding: const EdgeInsets.all(AppDimensions.spaceSm),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.15)
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
                                      size: 18,
                                      color: isSelected ? AppColors.primary : Colors.grey,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: disc.recognized
                                            ? AppColors.success.withValues(alpha: 0.2)
                                            : AppColors.warning.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        disc.recognized ? 'KNOWN' : 'NEW',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: disc.recognized ? AppColors.success : AppColors.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      disc.id.isNotEmpty ? disc.id : disc.macAddress,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      disc.macAddress,
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.wifi, size: 11, color: Colors.grey),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${disc.rssiDbm} dBm',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
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

                if (_isLoRaWANMode) ...[
                  // 64-bit DevEUI
                  TextFormField(
                    controller: _devEuiController,
                    decoration: const InputDecoration(
                      labelText: '64-bit DevEUI *',
                      hintText: 'e.g. 0004A30B001F9876',
                      prefixIcon: Icon(Icons.developer_board, size: 18),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 16) ? '16-hex DevEUI required' : null,
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  // AppKey
                  TextFormField(
                    controller: _appKeyController,
                    decoration: const InputDecoration(
                      labelText: '128-bit AppKey *',
                      hintText: '32-hex Application AES Key',
                      prefixIcon: Icon(Icons.key, size: 18),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 32) ? '32-hex AppKey required' : null,
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                ] else ...[
                  // Hardware MAC Address
                  TextFormField(
                    controller: _macController,
                    decoration: const InputDecoration(
                      labelText: 'MAC Address *',
                      hintText: 'AA:BB:CC:DD:EE:FF',
                      prefixIcon: Icon(Icons.perm_identity, size: 18),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'MAC Address required' : null,
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                ],

                // Display Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name *',
                    hintText: 'e.g. Zone 1 North Sensor',
                    prefixIcon: Icon(Icons.label_outline, size: 18),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Display name required' : null,
                ),
                const SizedBox(height: AppDimensions.spaceSm),

                // Dynamic Monitoring Zone Assignment
                DropdownButtonFormField<String>(
                  value: _selectedZoneId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Monitoring Zone',
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

                // Local Cartesian Coordinates (X, Y in meters)
                Text(
                  'Local Field Coordinates (Meters):',
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
                  'Base Transmission Interval:',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        AquaButton(
          label: _isLoading ? 'Registering...' : 'Register Node',
          icon: Icons.check,
          onPressed: _isLoading ? null : _submit,
        ),
      ],
    );
  }
}

