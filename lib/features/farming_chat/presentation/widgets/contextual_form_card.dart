import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_button.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../domain/models/farming_chat_models.dart';

/// Contextual Form Card rendered inline within the Arva AI chat stream.
/// Enables farmers to specify field parameters quickly using structured controls
/// (dropdowns, date pickers, text fields) instead of typing verbose explanations.
class ContextualFormCard extends StatefulWidget {
  final ContextualFormModel form;
  final Function(Map<String, dynamic> data) onSubmit;
  final VoidCallback? onCancel;

  const ContextualFormCard({
    super.key,
    required this.form,
    required this.onSubmit,
    this.onCancel,
  });

  @override
  State<ContextualFormCard> createState() => _ContextualFormCardState();
}

class _ContextualFormCardState extends State<ContextualFormCard> {
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    for (final field in widget.form.fields) {
      if (field.defaultValue != null && field.defaultValue!.isNotEmpty) {
        _values[field.id] = field.defaultValue;
      }
      if (field.type == 'text' || field.type == 'number') {
        _controllers[field.id] = TextEditingController(text: field.defaultValue ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AquaCard(
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.form.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (widget.form.description.isNotEmpty)
                        Text(
                          widget.form.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Dismiss Form',
                    onPressed: widget.onCancel,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const Divider(height: 20),

            // Form Fields
            ...widget.form.fields.map((field) => _buildField(context, field)),

            const SizedBox(height: AppDimensions.spaceSm),

            // Actions
            Row(
              children: [
                if (widget.onCancel != null) ...[
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: widget.onCancel,
                      child: const Text('Skip / Cancel', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                ],
                Expanded(
                  flex: 3,
                  child: AquaButton(
                    label: widget.form.submitButtonLabel,
                    icon: Icons.check,
                    onPressed: _handleSubmit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, ContextualFormFieldModel field) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                field.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (field.required)
                const Text(
                  ' *',
                  style: TextStyle(color: AppColors.alertError, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (field.type == 'select' && field.options.isNotEmpty)
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _values[field.id] as String?,
              items: field.options.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Text(opt, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  _values[field.id] = val;
                });
              },
              validator: field.required
                  ? (val) => (val == null || val.isEmpty) ? 'Please select an option' : null
                  : null,
            )
          else if (field.type == 'date')
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: now.subtract(const Duration(days: 30)),
                  lastDate: now.add(const Duration(days: 180)),
                );
                if (picked != null) {
                  setState(() {
                    _values[field.id] = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                  });
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  suffixIcon: const Icon(Icons.calendar_today, size: 16),
                ),
                child: Text(
                  (_values[field.id] as String?) ?? field.placeholder ?? 'Select Date (YYYY-MM-DD)',
                  style: TextStyle(
                    fontSize: 13,
                    color: _values[field.id] != null
                        ? theme.textTheme.bodyMedium?.color
                        : theme.hintColor,
                  ),
                ),
              ),
            )
          else
            TextFormField(
              controller: _controllers[field.id],
              keyboardType: field.type == 'number' ? TextInputType.number : TextInputType.text,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: field.placeholder,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (val) {
                _values[field.id] = val;
              },
              validator: field.required
                  ? (val) => (val == null || val.trim().isEmpty) ? 'This field is required' : null
                  : null,
            ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? true) {
      final payload = Map<String, dynamic>.from(_values);
      payload['formType'] = widget.form.formType;
      payload['formId'] = widget.form.formId;
      widget.onSubmit(payload);
    }
  }
}
