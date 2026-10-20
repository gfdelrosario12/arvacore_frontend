import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

class ManualConfirmationResult {
  final bool confirmed;
  final int durationMinutes;
  final String? rationale;

  const ManualConfirmationResult({
    required this.confirmed,
    required this.durationMinutes,
    this.rationale,
  });
}

class ManualControlConfirmationDialog extends StatefulWidget {
  final int initialDurationMinutes;
  final String actionType; // 'start' or 'stop'

  const ManualControlConfirmationDialog({
    super.key,
    this.initialDurationMinutes = 30,
    this.actionType = 'start',
  });

  static Future<ManualConfirmationResult?> show({
    required BuildContext context,
    int initialDurationMinutes = 30,
    String actionType = 'start',
  }) {
    return showDialog<ManualConfirmationResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManualControlConfirmationDialog(
        initialDurationMinutes: initialDurationMinutes,
        actionType: actionType,
      ),
    );
  }

  @override
  State<ManualControlConfirmationDialog> createState() =>
      _ManualControlConfirmationDialogState();
}

class _ManualControlConfirmationDialogState
    extends State<ManualControlConfirmationDialog> {
  late int _selectedDuration;
  final TextEditingController _rationaleController = TextEditingController();
  final TextEditingController _customDurationController = TextEditingController();
  bool _isConfirmed = false;
  bool _isCustom = false;

  final List<int> _durationPresets = [15, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.initialDurationMinutes;
    if (!_durationPresets.contains(_selectedDuration)) {
      _isCustom = true;
      _customDurationController.text = _selectedDuration.toString();
    }
  }

  @override
  void dispose() {
    _rationaleController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStart = widget.actionType == 'start';

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      title: Row(
        children: [
          Icon(
            isStart ? Icons.play_circle_fill : Icons.stop_circle,
            color: isStart ? AppColors.pumpActive : AppColors.alertError,
            size: 28,
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Text(
              isStart ? 'Confirm Manual Pulse' : 'Confirm Manual Stop',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Scope Warning Card
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TARGET SCOPE: ENTIRE FIELD\nThis command directly actuates the central pump and main distribution valves.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            if (isStart) ...[
              Text(
                'Target Duration (Minutes)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._durationPresets.map((dur) {
                    final isSelected = !_isCustom && _selectedDuration == dur;
                    return ChoiceChip(
                      label: Text('${dur}m'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _isCustom = false;
                            _selectedDuration = dur;
                          });
                        }
                      },
                    );
                  }),
                  ChoiceChip(
                    label: const Text('Custom'),
                    selected: _isCustom,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _isCustom = true;
                        });
                      }
                    },
                  ),
                ],
              ),
              if (_isCustom) ...[
                const SizedBox(height: AppDimensions.spaceSm),
                TextField(
                  controller: _customDurationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Custom Duration (1-180 mins)',
                    border: OutlineInputBorder(),
                    suffixText: 'minutes',
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed >= 1 && parsed <= 180) {
                      setState(() {
                        _selectedDuration = parsed;
                      });
                    }
                  },
                ),
              ],
              const SizedBox(height: AppDimensions.spaceMd),
            ],

            Text(
              'Override Rationale (Optional)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            TextField(
              controller: _rationaleController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g., Canal maintenance, emergency flush, manual pulse...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Confirmation Checkbox
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _isConfirmed,
              title: Text(
                'I authorize manual field-wide irrigation and understand automated irrigation rules will be suspended.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _isConfirmed = val ?? false;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: isStart ? AppColors.pumpActive : AppColors.alertError,
          ),
          icon: Icon(isStart ? Icons.play_arrow : Icons.stop),
          label: Text(isStart ? 'Dispatch Start' : 'Dispatch Stop'),
          onPressed: _isConfirmed
              ? () {
                  Navigator.of(context).pop(
                    ManualConfirmationResult(
                      confirmed: true,
                      durationMinutes: _selectedDuration,
                      rationale: _rationaleController.text.trim().isNotEmpty
                          ? _rationaleController.text.trim()
                          : null,
                    ),
                  );
                }
              : null,
        ),
      ],
    );
  }
}
