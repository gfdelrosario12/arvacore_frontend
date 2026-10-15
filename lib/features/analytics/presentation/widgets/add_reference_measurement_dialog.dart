import 'package:flutter/material.dart';
import '../../../../core/api/api_dtos.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

class AddReferenceMeasurementDialog extends StatefulWidget {
  final String initialIndicatorType; // 'WATER_LEVEL' or 'SOIL_MOISTURE'
  final String? initialNodeId;
  final double? currentReportedValue;
  final Future<void> Function(ReferenceMeasurementDto) onSubmit;

  const AddReferenceMeasurementDialog({
    super.key,
    required this.initialIndicatorType,
    this.initialNodeId,
    this.currentReportedValue,
    required this.onSubmit,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String initialIndicatorType,
    String? initialNodeId,
    double? currentReportedValue,
    required Future<void> Function(ReferenceMeasurementDto) onSubmit,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AddReferenceMeasurementDialog(
        initialIndicatorType: initialIndicatorType,
        initialNodeId: initialNodeId,
        currentReportedValue: currentReportedValue,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<AddReferenceMeasurementDialog> createState() => _AddReferenceMeasurementDialogState();
}

class _AddReferenceMeasurementDialogState extends State<AddReferenceMeasurementDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _indicatorType;
  late final TextEditingController _nodeIdController;
  late final TextEditingController _reportedController;
  late final TextEditingController _referenceController;
  late final TextEditingController _instrumentController;
  late final TextEditingController _notesController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _indicatorType = widget.initialIndicatorType;
    _nodeIdController = TextEditingController(text: widget.initialNodeId ?? 'NODE-01');
    _reportedController = TextEditingController(
      text: widget.currentReportedValue != null ? widget.currentReportedValue!.toStringAsFixed(2) : '',
    );
    _referenceController = TextEditingController();
    _instrumentController = TextEditingController(
      text: widget.initialIndicatorType == 'WATER_LEVEL'
          ? 'Manual Perforated-Well Dipstick / Ruler'
          : 'Calibrated Soil Moisture Probe / Gravimetric',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nodeIdController.dispose();
    _reportedController.dispose();
    _referenceController.dispose();
    _instrumentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final reported = double.tryParse(_reportedController.text.trim());
    final ref = double.tryParse(_referenceController.text.trim());

    if (reported == null || ref == null) return;

    final absError = (reported - ref).abs();
    double? pctError;
    double? accuracy;
    if (ref.abs() > 0.0001) {
      pctError = (absError / ref.abs()) * 100.0;
      accuracy = (100.0 - pctError).clamp(0.0, 100.0);
    }

    final unit = _indicatorType == 'WATER_LEVEL' ? 'cm' : '%';

    final dto = ReferenceMeasurementDto(
      indicatorType: _indicatorType,
      nodeId: _nodeIdController.text.trim(),
      reportedValue: reported,
      referenceValue: ref,
      absoluteError: absError,
      percentageError: pctError,
      accuracyPercentage: accuracy,
      measurementUnit: unit,
      instrumentDetails: _instrumentController.text.trim().isEmpty ? null : _instrumentController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      measuredAt: DateTime.now().toIso8601String(),
    );

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(dto);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit ground-truth: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _indicatorType == 'WATER_LEVEL' ? Icons.straighten : Icons.eco,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Text(
              _indicatorType == 'WATER_LEVEL'
                  ? 'Record Water-Level Ground-Truth'
                  : 'Record Soil-Moisture Ground-Truth',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter an independent trusted physical measurement to evaluate sensor accuracy and calibrate field monitoring.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              DropdownButtonFormField<String>(
                initialValue: _indicatorType,
                decoration: const InputDecoration(
                  labelText: 'Measurement Indicator',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'WATER_LEVEL', child: Text('Water Level (cm)')),
                  DropdownMenuItem(value: 'SOIL_MOISTURE', child: Text('Soil Moisture (%)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _indicatorType = val;
                      _instrumentController.text = val == 'WATER_LEVEL'
                          ? 'Manual Perforated-Well Dipstick / Ruler'
                          : 'Calibrated Soil Moisture Probe / Gravimetric';
                    });
                  }
                },
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              TextFormField(
                controller: _nodeIdController,
                decoration: const InputDecoration(
                  labelText: 'Node Identifier',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.router),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Node ID is required' : null,
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              TextFormField(
                controller: _reportedController,
                decoration: InputDecoration(
                  labelText: 'Reported System Measurement (${_indicatorType == 'WATER_LEVEL' ? 'cm' : '%'})',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.sensors),
                  helperText: 'Sensor value reported by IoT node',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Reported value is required';
                  if (double.tryParse(val.trim()) == null) return 'Must be a valid number';
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              TextFormField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: 'Reference Ground-Truth Value (${_indicatorType == 'WATER_LEVEL' ? 'cm' : '%'})',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.rule),
                  helperText: 'Measured independently (e.g. ruler, test kit)',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Reference value is required';
                  if (double.tryParse(val.trim()) == null) return 'Must be a valid number';
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              TextFormField(
                controller: _instrumentController,
                decoration: const InputDecoration(
                  labelText: 'Reference Instrument / Calibration Tool',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.handyman_outlined),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Observations / Field Notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: const Text('Save Reference'),
        ),
      ],
    );
  }
}
