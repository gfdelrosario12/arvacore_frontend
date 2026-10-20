import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../irrigation/domain/models/auto_irrigation_config.dart';

class AutoIrrigationConfigDialog extends StatefulWidget {
  final AutoIrrigationConfig initialConfig;

  const AutoIrrigationConfigDialog({
    super.key,
    required this.initialConfig,
  });

  static Future<AutoIrrigationConfig?> show(
    BuildContext context,
    AutoIrrigationConfig initialConfig,
  ) {
    return showDialog<AutoIrrigationConfig>(
      context: context,
      builder: (context) => AutoIrrigationConfigDialog(initialConfig: initialConfig),
    );
  }

  @override
  State<AutoIrrigationConfigDialog> createState() =>
      _AutoIrrigationConfigDialogState();
}

class _AutoIrrigationConfigDialogState
    extends State<AutoIrrigationConfigDialog> {
  late bool _isEnabled;
  late int _maxDurationMinutes;
  late int _minCooldownMinutes;
  late int _allowedHoursStart;
  late int _allowedHoursEnd;
  late double _targetFloodDepthCm;
  late bool _rainDelayEnabled;
  late int _rainDelayHours;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.initialConfig.isEnabled;
    _maxDurationMinutes = widget.initialConfig.maxDurationMinutes;
    _minCooldownMinutes = widget.initialConfig.minCooldownMinutes;
    _allowedHoursStart = widget.initialConfig.allowedHoursStart;
    _allowedHoursEnd = widget.initialConfig.allowedHoursEnd;
    _targetFloodDepthCm = widget.initialConfig.targetFloodDepthCm;
    _rainDelayEnabled = widget.initialConfig.rainDelayEnabled;
    _rainDelayHours = widget.initialConfig.rainDelayHours;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.settings_suggest, color: AppColors.primary),
          const SizedBox(width: AppDimensions.spaceSm),
          const Text('Auto-Irrigation Settings'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Automation Mode Toggle
              Card(
                color: _isEnabled
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : theme.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  side: BorderSide(
                    color: _isEnabled
                        ? AppColors.primary
                        : theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: SwitchListTile(
                  value: _isEnabled,
                  activeThumbColor: AppColors.primary,
                  title: const Text(
                    'Enable Field Automation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _isEnabled
                        ? 'System autonomously activates irrigation when moisture/water-level trigger is reached.'
                        : 'Automation disabled. Irrigation requires manual operator activation.',
                    style: theme.textTheme.bodySmall,
                  ),
                  onChanged: (val) => setState(() => _isEnabled = val),
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Safety Duration Ceiling
              Text(
                'Safety Duration Ceiling: $_maxDurationMinutes min',
                style: theme.textTheme.titleSmall,
              ),
              Text(
                'Maximum continuous run time for hardware watchdog timer.',
                style: theme.textTheme.bodySmall,
              ),
              Slider(
                value: _maxDurationMinutes.toDouble(),
                min: 15.0,
                max: 120.0,
                divisions: 21,
                label: '$_maxDurationMinutes min',
                activeColor: AppColors.primary,
                onChanged: (v) =>
                    setState(() => _maxDurationMinutes = v.round()),
              ),
              const Divider(),

              // Minimum Cooldown
              Text(
                'Soil Stabilization Cooldown: $_minCooldownMinutes min',
                style: theme.textTheme.titleSmall,
              ),
              Text(
                'Minimum wait period between cycles for water infiltration (min 60m).',
                style: theme.textTheme.bodySmall,
              ),
              Slider(
                value: _minCooldownMinutes.toDouble(),
                min: 60.0,
                max: 240.0,
                divisions: 12,
                label: '$_minCooldownMinutes min',
                activeColor: AppColors.primary,
                onChanged: (v) =>
                    setState(() => _minCooldownMinutes = v.round()),
              ),
              const Divider(),

              // Allowed Operating Hours
              Text(
                'Allowed Operating Window: ${_formatHour(_allowedHoursStart)} - ${_formatHour(_allowedHoursEnd)}',
                style: theme.textTheme.titleSmall,
              ),
              Text(
                'Permitted time window for automated pump operations.',
                style: theme.textTheme.bodySmall,
              ),
              RangeSlider(
                values: RangeValues(
                  _allowedHoursStart.toDouble(),
                  _allowedHoursEnd.toDouble(),
                ),
                min: 0.0,
                max: 24.0,
                divisions: 24,
                labels: RangeLabels(
                  _formatHour(_allowedHoursStart),
                  _formatHour(_allowedHoursEnd),
                ),
                activeColor: AppColors.primary,
                onChanged: (RangeValues values) {
                  setState(() {
                    _allowedHoursStart = values.start.round();
                    _allowedHoursEnd = values.end.round();
                  });
                },
              ),
              const Divider(),

              // Target Flood Depth
              Text(
                'Target Flood Depth: +${_targetFloodDepthCm.toStringAsFixed(1)} cm',
                style: theme.textTheme.titleSmall,
              ),
              Slider(
                value: _targetFloodDepthCm,
                min: 2.0,
                max: 10.0,
                divisions: 16,
                label: '+${_targetFloodDepthCm.toStringAsFixed(1)} cm',
                activeColor: AppColors.primary,
                onChanged: (v) =>
                    setState(() => _targetFloodDepthCm = v),
              ),
              const Divider(),

              // Rain Delay
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _rainDelayEnabled,
                activeThumbColor: AppColors.primary,
                title: const Text('Rain Delay Interlock'),
                subtitle: Text(
                  'Inhibits automated pumping when rainfall is detected or forecasted for $_rainDelayHours hours.',
                  style: theme.textTheme.bodySmall,
                ),
                onChanged: (val) =>
                    setState(() => _rainDelayEnabled = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Save Configuration'),
          onPressed: () {
            final updated = widget.initialConfig.copyWith(
              isEnabled: _isEnabled,
              maxDurationMinutes: _maxDurationMinutes,
              minCooldownMinutes: _minCooldownMinutes,
              allowedHoursStart: _allowedHoursStart,
              allowedHoursEnd: _allowedHoursEnd,
              targetFloodDepthCm: _targetFloodDepthCm,
              rainDelayEnabled: _rainDelayEnabled,
              rainDelayHours: _rainDelayHours,
            );
            Navigator.of(context).pop(updated);
          },
        ),
      ],
    );
  }

  String _formatHour(int hour) {
    final h = hour % 24;
    return '${h.toString().padLeft(2, '0')}:00';
  }
}

