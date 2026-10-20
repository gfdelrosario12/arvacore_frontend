import 'package:flutter/material.dart';

import '../../../../core/api/api_factory.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../nodes/domain/models/models.dart';
import '../../../nodes/presentation/widgets/node_unpair_dialog.dart';
import '../../../zones/domain/models/monitoring_zone.dart';
import '../../domain/models/field.dart';

/// Interactive Farmland Designer and Farm-to-Node Management View.
///
/// Enables farmers and operators to:
/// 1. Configure farmland dimensions, shape, unit, and total area.
/// 2. Visualize the field on an interactive pan/zoom canvas.
/// 3. Divide farmland into quarters, sections, ranges, or custom monitoring zones.
/// 4. Split and merge zones dynamically.
/// 5. Assign and unpair physical ArvaNodes to zones.
/// 6. Inspect readiness diagnostics, prerequisite validation, and historical placement logs.
class FarmlandDesignerView extends StatefulWidget {
  final Field field;
  final List<MonitoringZone> zones;
  final List<Esp32Node> nodes;
  final Future<void> Function() onRefresh;
  final Future<bool> Function(String nodeId, {int? fieldId, int? monitoringZoneId}) onAssignNode;
  final Future<bool> Function(String nodeId)? onUnpairNode;
  final Future<void> Function(Field field)? onDeleteField;

  const FarmlandDesignerView({
    super.key,
    required this.field,
    required this.zones,
    required this.nodes,
    required this.onRefresh,
    required this.onAssignNode,
    this.onUnpairNode,
    this.onDeleteField,
  });

  @override
  State<FarmlandDesignerView> createState() => _FarmlandDesignerViewState();
}

class _FarmlandDesignerViewState extends State<FarmlandDesignerView> {
  late final ApiRepositoryFactory _apiFactory;
  final TransformationController _transformController = TransformationController();

  Field? _currentField;
  List<MonitoringZone> _editableZones = [];
  String? _selectedZoneId;
  final Set<String> _multiSelectedZoneIds = {};
  bool _hasUnsavedLayout = false;
  bool _isSavingLayout = false;

  static const double _canvasBaseWidth = 840.0;
  static const double _canvasBaseHeight = 540.0;

  @override
  void initState() {
    super.initState();
    _apiFactory = ApiRepositoryFactory();
    _currentField = widget.field;
    _initializeZones(widget.zones);
  }

  @override
  void didUpdateWidget(covariant FarmlandDesignerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.field != widget.field) {
      _currentField = widget.field;
    }
    if (oldWidget.zones != widget.zones) {
      if (!_hasUnsavedLayout || oldWidget.zones.length != widget.zones.length) {
        _hasUnsavedLayout = false;
        _initializeZones(widget.zones);
      }
    }
  }

  void _initializeZones(List<MonitoringZone> inputZones) {
    final active = inputZones.where((z) => !z.isArchived).toList();
    // Verify if zones have valid relative layout; if not, arrange them into an automatic grid
    bool needsAutoLayout = active.any((z) =>
        (z.relativeWidth <= 0 || z.relativeHeight <= 0) ||
        (z.relativeX == 0 && z.relativeY == 0 && active.length > 1));

    if (needsAutoLayout && active.isNotEmpty) {
      final int count = active.length;
      final int cols = count <= 2 ? count : (count <= 4 ? 2 : (count <= 9 ? 3 : 4));
      final int rows = (count / cols).ceil();

      final double cellWidth = 1.0 / cols;
      final double cellHeight = 1.0 / rows;

      _editableZones = List.generate(count, (i) {
        final r = i ~/ cols;
        final c = i % cols;
        final z = active[i];
        return z.copyWith(
          relativeX: c * cellWidth,
          relativeY: r * cellHeight,
          relativeWidth: cellWidth,
          relativeHeight: cellHeight,
        );
      });
    } else {
      _editableZones = List.from(active);
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Field get field => _currentField ?? widget.field;

  void _resetZoom() {
    _transformController.value = _transformController.value.clone()..setIdentity();
  }

  // ---------------------------------------------------------------------------
  // Action Handlers
  // ---------------------------------------------------------------------------

  Future<void> _saveLayout() async {
    setState(() => _isSavingLayout = true);
    try {
      final fieldId = field.id.replaceAll(RegExp(r'[^0-9]'), '');
      final effectiveFieldId = fieldId.isEmpty ? '1' : fieldId;

      final body = {
        'zones': _editableZones.map((z) {
          final zid = int.tryParse(z.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return {
            'zoneId': zid,
            'relativeX': z.relativeX,
            'relativeY': z.relativeY,
            'relativeWidth': z.relativeWidth,
            'relativeHeight': z.relativeHeight,
          };
        }).toList(),
      };

      await _apiFactory.fields.saveFieldLayout(effectiveFieldId, body);

      if (mounted) {
        setState(() {
          _hasUnsavedLayout = false;
          _isSavingLayout = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farmland layout updated successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await widget.onRefresh();
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingLayout = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save layout: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openEditFieldDialog() async {
    final nameCtrl = TextEditingController(text: field.name);
    final lengthCtrl = TextEditingController(text: (field.lengthMeters ?? 100.0).toStringAsFixed(1));
    final widthCtrl = TextEditingController(text: (field.widthMeters ?? 100.0).toStringAsFixed(1));
    final descCtrl = TextEditingController(text: field.description ?? '');
    String unit = field.areaUnit;
    String shape = field.shapeType;
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.edit_road, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Edit Farmland Boundary'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Farmland Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: lengthCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Length (m) *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: widthCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Width (m) *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: unit,
                            decoration: const InputDecoration(
                              labelText: 'Area Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'hectares', child: Text('Hectares (ha)')),
                              DropdownMenuItem(value: 'sqm', child: Text('Square Meters (m²)')),
                              DropdownMenuItem(value: 'acres', child: Text('Acres (ac)')),
                            ],
                            onChanged: (v) => setDlgState(() => unit = v ?? unit),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: shape,
                            decoration: const InputDecoration(
                              labelText: 'Shape Type',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'RECTANGULAR', child: Text('Rectangular')),
                              DropdownMenuItem(value: 'IRREGULAR', child: Text('Irregular')),
                              DropdownMenuItem(value: 'POLYGON', child: Text('Polygonal')),
                            ],
                            onChanged: (v) => setDlgState(() => shape = v ?? shape),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description / Notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Save Farmland'),
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      try {
        final length = double.parse(lengthCtrl.text.trim());
        final width = double.parse(widthCtrl.text.trim());
        double totalArea = length * width;
        if (unit == 'hectares') totalArea = (length * width) / 10000.0;
        if (unit == 'acres') totalArea = (length * width) / 4046.86;

        final fieldId = field.id.replaceAll(RegExp(r'[^0-9]'), '');
        final effectiveFieldId = fieldId.isEmpty ? '1' : fieldId;

        final body = {
          'name': nameCtrl.text.trim(),
          'lengthMeters': length,
          'widthMeters': width,
          'totalArea': totalArea,
          'areaUnit': unit,
          'shapeType': shape,
          'description': descCtrl.text.trim(),
        };

        await _apiFactory.fields.updateField(effectiveFieldId, body);

        if (mounted) {
          setState(() {
            _currentField = field.copyWith(
              name: nameCtrl.text.trim(),
              lengthMeters: length,
              widthMeters: width,
              totalArea: totalArea,
              areaUnit: unit,
              shapeType: shape,
              description: descCtrl.text.trim(),
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Farmland boundary updated.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await widget.onRefresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update farmland: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openReadinessDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic> readinessData = {};
    try {
      final fieldId = field.id.replaceAll(RegExp(r'[^0-9]'), '');
      final effectiveFieldId = fieldId.isEmpty ? '1' : fieldId;
      readinessData = await _apiFactory.fields.getFieldReadiness(effectiveFieldId);
    } catch (e) {
      readinessData = {
        'status': 'UNKNOWN',
        'ready': false,
        'summary': 'Could not query backend readiness: $e',
        'blockingIssues': ['Network or API failure querying readiness diagnostics.'],
        'advisoryWarnings': [],
        'coveragePercentage': 0.0,
      };
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;

    final status = readinessData['status']?.toString() ?? 'INCOMPLETE';
    final ready = readinessData['ready'] == true;
    final summary = readinessData['summary']?.toString() ?? 'Farmland prerequisite evaluation';
    final blocking = (readinessData['blockingIssues'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final advisory = (readinessData['advisoryWarnings'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final coverage = (readinessData['coveragePercentage'] as num?)?.toDouble() ?? 0.0;
    final zonesCount = (readinessData['zonesCount'] as num?)?.toInt() ?? _editableZones.length;
    final assignedCount = (readinessData['assignedNodesCount'] as num?)?.toInt() ?? 0;

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              ready ? Icons.verified : Icons.warning_amber_rounded,
              color: ready ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 8),
            const Text('Farmland Readiness Diagnostics'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (ready ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(
                      color: (ready ? AppColors.success : AppColors.warning).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        ready ? Icons.check_circle : Icons.info,
                        color: ready ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status: $status',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: ready ? AppColors.success : AppColors.warning,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(summary, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        theme,
                        label: 'Monitoring Zones',
                        value: '$zonesCount',
                        icon: Icons.grid_view,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        theme,
                        label: 'Assigned Nodes',
                        value: '$assignedCount',
                        icon: Icons.sensors,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        theme,
                        label: 'Coverage',
                        value: '${coverage.toStringAsFixed(0)}%',
                        icon: Icons.pie_chart_outline,
                      ),
                    ),
                  ],
                ),
                if (blocking.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Blocking Issues (${blocking.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...blocking.map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.cancel, size: 16, color: AppColors.error),
                            const SizedBox(width: 6),
                            Expanded(child: Text(b, style: theme.textTheme.bodySmall)),
                          ],
                        ),
                      )),
                ],
                if (advisory.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Advisory Warnings (${advisory.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...advisory.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                            const SizedBox(width: 6),
                            Expanded(child: Text(w, style: theme.textTheme.bodySmall)),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(ThemeData theme, {required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _openAddAreaDialog() async {
    final codeCtrl = TextEditingController(text: 'Z${_editableZones.length + 1}');
    final nameCtrl = TextEditingController(text: 'Sector ${_editableZones.length + 1}');
    final cropCtrl = TextEditingController(text: 'Rice');
    final areaCtrl = TextEditingController(text: '0.25');
    String areaType = 'QUARTER';
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.add_box, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Add Farmland Area'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: codeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Code *',
                              hintText: 'e.g. Q1, Z5',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Area Name *',
                              hintText: 'e.g. North Inflow Quarter',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: areaType,
                            decoration: const InputDecoration(
                              labelText: 'Area Type',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'QUARTER', child: Text('Quarter')),
                              DropdownMenuItem(value: 'SECTION', child: Text('Section')),
                              DropdownMenuItem(value: 'RANGE', child: Text('Range')),
                              DropdownMenuItem(value: 'ZONE', child: Text('Zone')),
                            ],
                            onChanged: (v) => setDlgState(() => areaType = v ?? areaType),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: cropCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Crop Type *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: areaCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Area Size (${field.areaUnit}) *',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter valid number' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Create Area'),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      try {
        final fieldId = field.id.replaceAll(RegExp(r'[^0-9]'), '');
        final effectiveFieldId = fieldId.isEmpty ? '1' : fieldId;

        final body = {
          'name': nameCtrl.text.trim(),
          'code': codeCtrl.text.trim().toUpperCase(),
          'areaType': areaType,
          'cropType': cropCtrl.text.trim(),
          'areaSize': double.parse(areaCtrl.text.trim()),
          'areaUnit': field.areaUnit,
          'relativeX': 0.0,
          'relativeY': 0.0,
          'relativeWidth': 0.5,
          'relativeHeight': 0.5,
        };

        await _apiFactory.fields.createFieldZone(effectiveFieldId, body);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Area "${nameCtrl.text}" created.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await widget.onRefresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create area: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openSplitDialog(MonitoringZone zone) async {
    String direction = 'VERTICAL';
    double ratio = 0.5;
    final code1Ctrl = TextEditingController(text: '${zone.code}-A');
    final name1Ctrl = TextEditingController(text: '${zone.name} (West)');
    final code2Ctrl = TextEditingController(text: '${zone.code}-B');
    final name2Ctrl = TextEditingController(text: '${zone.name} (East)');
    final formKey = GlobalKey<FormState>();

    final splitConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.call_split, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Split Farmland Area'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Splitting "${zone.name}" (${zone.code}) will produce two distinct monitoring areas.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Split Direction: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        ChoiceChip(
                          label: const Text('Vertical (|)'),
                          selected: direction == 'VERTICAL',
                          onSelected: (_) => setDlgState(() {
                            direction = 'VERTICAL';
                            name1Ctrl.text = '${zone.name} (West)';
                            name2Ctrl.text = '${zone.name} (East)';
                          }),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Horizontal (—)'),
                          selected: direction == 'HORIZONTAL',
                          onSelected: (_) => setDlgState(() {
                            direction = 'HORIZONTAL';
                            name1Ctrl.text = '${zone.name} (North)';
                            name2Ctrl.text = '${zone.name} (South)';
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Split Ratio: ${(ratio * 100).round()}% / ${((1 - ratio) * 100).round()}%'),
                      ],
                    ),
                    Slider(
                      value: ratio,
                      min: 0.1,
                      max: 0.9,
                      divisions: 8,
                      label: '${(ratio * 100).round()}%',
                      onChanged: (v) => setDlgState(() => ratio = v),
                    ),
                    const Divider(height: 24),
                    Text('Sub-Area 1 (${(ratio * 100).round()}%)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: code1Ctrl,
                            decoration: const InputDecoration(labelText: 'Code 1', border: OutlineInputBorder()),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: name1Ctrl,
                            decoration: const InputDecoration(labelText: 'Name 1', border: OutlineInputBorder()),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Sub-Area 2 (${((1 - ratio) * 100).round()}%)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: code2Ctrl,
                            decoration: const InputDecoration(labelText: 'Code 2', border: OutlineInputBorder()),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: name2Ctrl,
                            decoration: const InputDecoration(labelText: 'Name 2', border: OutlineInputBorder()),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Split Area'),
            ),
          ],
        ),
      ),
    );

    if (splitConfirmed == true) {
      try {
        final fieldId = field.id.replaceAll(RegExp(r'[^0-9]'), '');
        final effectiveFieldId = fieldId.isEmpty ? '1' : fieldId;
        final zoneId = zone.id.replaceAll(RegExp(r'[^0-9]'), '');

        final body = {
          'direction': direction,
          'ratio': ratio,
          'newCode1': code1Ctrl.text.trim().toUpperCase(),
          'newName1': name1Ctrl.text.trim(),
          'newCode2': code2Ctrl.text.trim().toUpperCase(),
          'newName2': name2Ctrl.text.trim(),
        };

        await _apiFactory.fields.splitFieldZone(effectiveFieldId, zoneId, body);

        if (mounted) {
          setState(() => _selectedZoneId = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Zone "${zone.name}" split successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await widget.onRefresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to split area: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openMergeDialog() async {
    final available = _editableZones.toList();
    if (available.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 2 zones are required to perform a merge.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final selectedIds = Set<String>.from(_multiSelectedZoneIds);
    if (_selectedZoneId != null) selectedIds.add(_selectedZoneId!);

    final codeCtrl = TextEditingController(text: 'MZ1');
    final nameCtrl = TextEditingController(text: 'Merged Area');
    final cropCtrl = TextEditingController(text: 'Rice');
    final formKey = GlobalKey<FormState>();

    final mergeConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.call_merge, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Merge Farmland Areas'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select two or more areas to combine into a unified monitoring zone.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView(
                        shrinkWrap: true,
                        children: available.map((z) {
                          final isSelected = selectedIds.contains(z.id);
                          return CheckboxListTile(
                            dense: true,
                            value: isSelected,
                            title: Text('${z.code} — ${z.name}'),
                            subtitle: Text('Area: ${z.areaSize ?? 1.0} ${z.areaUnit} • Crop: ${z.cropType}'),
                            onChanged: (val) {
                              setDlgState(() {
                                if (val == true) {
                                  selectedIds.add(z.id);
                                } else {
                                  selectedIds.remove(z.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: codeCtrl,
                            decoration: const InputDecoration(labelText: 'Merged Code *', border: OutlineInputBorder()),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(labelText: 'Merged Name *', border: OutlineInputBorder()),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: cropCtrl,
                      decoration: const InputDecoration(labelText: 'Merged Crop Type *', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedIds.length < 2) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please select at least 2 zones.')),
                  );
                  return;
                }
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Merge Areas'),
            ),
          ],
        ),
      ),
    );

    if (mergeConfirmed == true) {
      try {
        final fieldId = field.id.replaceAll(RegExp(r'[^0-9]'), '');
        final effectiveFieldId = fieldId.isEmpty ? '1' : fieldId;

        final zoneIntIds = selectedIds
            .map((sid) => int.tryParse(sid.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
            .where((id) => id > 0)
            .toList();

        final body = {
          'zoneIds': zoneIntIds,
          'mergedCode': codeCtrl.text.trim().toUpperCase(),
          'mergedName': nameCtrl.text.trim(),
          'cropType': cropCtrl.text.trim(),
        };

        await _apiFactory.fields.mergeFieldZones(effectiveFieldId, body);

        if (mounted) {
          setState(() {
            _selectedZoneId = null;
            _multiSelectedZoneIds.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Zones merged successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await widget.onRefresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to merge areas: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _archiveZone(MonitoringZone zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Monitoring Area?'),
        content: Text(
          'Are you sure you want to archive "${zone.name}" (${zone.code})?\n'
          'Any assigned ArvaNodes will become unassigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final fieldId = field.id.replaceAll(RegExp(r'[^0-9]'), '');
        final effectiveFieldId = fieldId.isEmpty ? '1' : fieldId;
        final zoneId = zone.id.replaceAll(RegExp(r'[^0-9]'), '');

        await _apiFactory.fields.archiveFieldZone(effectiveFieldId, zoneId);

        if (mounted) {
          setState(() {
            _selectedZoneId = null;
            _hasUnsavedLayout = false;
            _editableZones.removeWhere((z) => z.id == zone.id || z.code == zone.code);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Zone "${zone.name}" archived.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await widget.onRefresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to archive zone: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openAssignmentHistoryDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    List<Map<String, dynamic>> historyLogs = [];
    try {
      final fieldId = field.id.replaceAll(RegExp(r'[^0-9]'), '');
      final effectiveFieldId = fieldId.isEmpty ? '1' : fieldId;
      historyLogs = await _apiFactory.fields.getFieldHistory(effectiveFieldId);
    } catch (e) {
      debugPrint('[FarmlandDesigner] Failed to fetch history: $e');
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.history, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Node Assignment History'),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: historyLogs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No past node assignments recorded for this farmland.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: historyLogs.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 12),
                    itemBuilder: (ctx, i) {
                      final item = historyLogs[i];
                      final nodeId = item['edgeNodeId']?.toString() ?? 'Unknown Node';
                      final assignedAt = item['assignedAt']?.toString() ?? '';
                      final unassignedAt = item['unassignedAt']?.toString();
                      final actor = item['assignedBy']?.toString() ?? 'SYSTEM';
                      final reason = item['assignmentReason']?.toString() ?? 'Field deployment';
                      final active = unassignedAt == null || unassignedAt.isEmpty;

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: (active ? AppColors.success : AppColors.textSecondaryOf(context)).withValues(alpha: 0.15),
                          child: Icon(
                            active ? Icons.sensors : Icons.sensors_off,
                            color: active ? AppColors.success : AppColors.textSecondaryOf(context),
                            size: 18,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(nodeId, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (active ? AppColors.success : AppColors.surfaceLightOf(context)).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                active ? 'ACTIVE' : 'RELEASED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: active ? AppColors.success : AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text('Assigned: $assignedAt by $actor'),
                            if (!active) Text('Unassigned: $unassignedAt'),
                            Text('Reason: $reason', style: const TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openNodeAssignmentModal(MonitoringZone zone) async {
    final theme = Theme.of(context);
    final pairedNodes = widget.nodes;

    final selectedNodeId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings_input_antenna, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Assign ArvaNode to ${zone.code}'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select an eligible paired ArvaNode to monitor "${zone.name}".',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (pairedNodes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No ArvaNodes discovered or paired in this network.'),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pairedNodes.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 8),
                    itemBuilder: (ctx, i) {
                      final node = pairedNodes[i];
                      final isCurrentlyAssignedHere = zone.assignedNodeIds.contains(node.id) ||
                          node.assignedZoneId == zone.id ||
                          node.assignedZoneId == zone.code;

                      return ListTile(
                        dense: true,
                        leading: Icon(
                          node.isOnline ? Icons.wifi : Icons.wifi_off,
                          color: node.isOnline ? AppColors.success : AppColors.textSecondaryOf(context),
                        ),
                        title: Text(
                          node.displayName.isNotEmpty ? node.displayName : node.id,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'MAC: ${node.macAddress} • Battery: ${node.batteryPercent ?? 0}% • Moisture: ${node.soilMoisturePercent?.toStringAsFixed(1) ?? '--'}%',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: isCurrentlyAssignedHere
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Chip(
                                    label: Text('Current', style: TextStyle(fontSize: 10)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(color: AppColors.error),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, '__REMOVE__:${node.id}'),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              )
                            : OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, node.id),
                                child: const Text('Assign'),
                              ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedNodeId != null && selectedNodeId.isNotEmpty) {
      if (selectedNodeId.startsWith('__REMOVE__:')) {
        final targetId = selectedNodeId.substring('__REMOVE__:'.length);
        final success = await widget.onAssignNode(targetId, fieldId: null, monitoringZoneId: null);
        if (success) {
          await widget.onRefresh();
        }
        return;
      }
      final zid = int.tryParse(zone.id.replaceAll(RegExp(r'[^0-9]'), ''));
      final fid = int.tryParse(field.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

      final success = await widget.onAssignNode(selectedNodeId, fieldId: fid, monitoringZoneId: zid);
      if (success) {
        await widget.onRefresh();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build Methods
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedZone = _editableZones.where((z) => z.id == _selectedZoneId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFarmlandHeader(theme),
        const SizedBox(height: AppDimensions.spaceSm),
        _buildToolbar(theme, selectedZone),
        if (_hasUnsavedLayout) ...[
          const SizedBox(height: AppDimensions.spaceSm),
          _buildUnsavedChangesBanner(theme),
        ],
        const SizedBox(height: AppDimensions.spaceSm),
        _buildCanvas(theme),
        if (selectedZone != null) ...[
          const SizedBox(height: AppDimensions.spaceMd),
          _buildSelectedZoneInspector(theme, selectedZone),
        ],
      ],
    );
  }

  Widget _buildFarmlandHeader(ThemeData theme) {
    final status = field.operationalStatus.toUpperCase();
    Color statusColor = AppColors.info;
    if (status == 'READY' || status == 'MONITORING') statusColor = AppColors.success;
    if (status == 'INCOMPLETE' || status == 'DEGRADED') statusColor = AppColors.warning;
    if (status == 'INACTIVE' || status == 'DRAFT') statusColor = AppColors.textSecondaryOf(context);

    final length = field.lengthMeters ?? 100.0;
    final width = field.widthMeters ?? 100.0;
    final area = field.totalArea ?? (length * width);
    final unit = field.areaUnit;

    return AquaCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          final headerInfo = Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: const Icon(Icons.landscape, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            field.name,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${length.toStringAsFixed(1)}m × ${width.toStringAsFixed(1)}m • ${area.toStringAsFixed(2)} $unit • Shape: ${field.shapeType}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondaryOf(context)),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actionButtons = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.rule, size: 18),
                label: const Text('Readiness'),
                onPressed: _openReadinessDialog,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('History'),
                onPressed: _openAssignmentHistoryDialog,
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Farmland'),
                onPressed: _openEditFieldDialog,
              ),
              if (widget.onDeleteField != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete Farmland'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Delete Farmland'),
                          ],
                        ),
                        content: Text(
                          'Are you sure you want to permanently remove "${field.name}"?\n'
                          'All monitoring zones and boundaries associated with this farmland will be cleared.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      await widget.onDeleteField!(field);
                    }
                  },
                ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerInfo,
                const SizedBox(height: 12),
                actionButtons,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: headerInfo),
              const SizedBox(width: 12),
              actionButtons,
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme, MonitoringZone? selectedZone) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Area'),
            onPressed: _openAddAreaDialog,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.call_split, size: 18),
            label: const Text('Split Area'),
            onPressed: selectedZone == null ? null : () => _openSplitDialog(selectedZone),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.call_merge, size: 18),
            label: const Text('Merge Areas'),
            onPressed: _openMergeDialog,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.center_focus_strong, size: 18),
            label: const Text('Fit View'),
            onPressed: _resetZoom,
          ),
          const SizedBox(width: 8),
          if (_hasUnsavedLayout)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size(48, 48),
              ),
              icon: _isSavingLayout
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save, size: 18),
              label: const Text('Save Layout'),
              onPressed: _isSavingLayout ? null : _saveLayout,
            ),
        ],
      ),
    );
  }

  Widget _buildUnsavedChangesBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Farmland layout has unsaved division changes. Click "Save Layout" to persist.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _saveLayout,
            child: const Text('Save Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas(ThemeData theme) {
    return Container(
      height: 480,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InteractiveViewer(
            transformationController: _transformController,
            boundaryMargin: const EdgeInsets.all(120),
            minScale: 0.4,
            maxScale: 3.0,
            child: Center(
              child: Container(
                width: _canvasBaseWidth,
                height: _canvasBaseHeight,
                margin: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // Grid background lines
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPatternPainter(
                          lineColor: theme.dividerColor.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                    // Canvas Corner Scale Markers
                    Positioned(
                      top: 4,
                      left: 6,
                      child: Text(
                        '(0,0)',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondaryOf(context).withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 6,
                      child: Text(
                        '(${field.lengthMeters ?? 100}m, ${field.widthMeters ?? 100}m)',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondaryOf(context).withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    // Zones
                    ..._editableZones.map((zone) => _buildZoneCardOnCanvas(theme, zone)),
                  ],
                ),
              ),
            ),
          ),
          // Canvas floating overlay indicator
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pan_tool_alt, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Pinch to Zoom • Drag to Pan',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCardOnCanvas(ThemeData theme, MonitoringZone zone) {
    final isSelected = zone.id == _selectedZoneId;
    final rx = zone.relativeX.clamp(0.0, 0.95);
    final ry = zone.relativeY.clamp(0.0, 0.95);
    final rw = zone.relativeWidth.clamp(0.05, 1.0 - rx);
    final rh = zone.relativeHeight.clamp(0.05, 1.0 - ry);

    final left = rx * _canvasBaseWidth;
    final top = ry * _canvasBaseHeight;
    final width = rw * _canvasBaseWidth;
    final height = rh * _canvasBaseHeight;

    // Node association
    final assignedNode = widget.nodes.where((n) =>
        zone.assignedNodeIds.contains(n.id) ||
        zone.assignedNodeIds.contains(n.displayName) ||
        n.assignedZoneId == zone.id ||
        n.assignedZoneId == zone.code).firstOrNull;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedZoneId = (_selectedZoneId == zone.id) ? null : zone.id;
          });
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : theme.cardColor.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderOf(context),
              width: isSelected ? 2.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Zone Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      zone.code,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      zone.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Crop: ${zone.cropType} • ${zone.areaType}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: AppColors.textSecondaryOf(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Node Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: assignedNode != null
                      ? (assignedNode.isOnline ? AppColors.success : AppColors.textSecondaryOf(context)).withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: assignedNode != null
                        ? (assignedNode.isOnline ? AppColors.success : AppColors.textSecondaryOf(context)).withValues(alpha: 0.3)
                        : AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      assignedNode != null ? Icons.sensors : Icons.warning_amber_rounded,
                      size: 12,
                      color: assignedNode != null
                          ? (assignedNode.isOnline ? AppColors.success : AppColors.textSecondaryOf(context))
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        assignedNode != null
                            ? '${assignedNode.displayName.isNotEmpty ? assignedNode.displayName : assignedNode.id} (${assignedNode.batteryPercent ?? 0}%)'
                            : 'Unmonitored',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: assignedNode != null
                              ? (assignedNode.isOnline ? AppColors.success : AppColors.textSecondaryOf(context))
                              : AppColors.warning,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedZoneInspector(ThemeData theme, MonitoringZone zone) {
    final assignedNode = widget.nodes.where((n) =>
        zone.assignedNodeIds.contains(n.id) ||
        zone.assignedNodeIds.contains(n.displayName) ||
        n.assignedZoneId == zone.id ||
        n.assignedZoneId == zone.code).firstOrNull;

    return AquaCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 950;
          final headerInfo = Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: const Icon(Icons.dashboard_customize, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${zone.name} (${zone.code})',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            zone.areaType,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Crop: ${zone.cropType} • Area: ${zone.areaSize ?? 1.0} ${zone.areaUnit}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );

          final actionButtons = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.sensors, size: 16),
                label: Text(assignedNode != null ? 'Reassign Node' : 'Assign Node'),
                onPressed: () => _openNodeAssignmentModal(zone),
              ),
              if (assignedNode != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.layers_clear_outlined, size: 16),
                  label: const Text('Remove Node'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove Node from Area'),
                        content: Text(
                          'Remove node ${assignedNode.displayName.isNotEmpty ? assignedNode.displayName : assignedNode.id} from ${zone.name}?\n\nThe node remains paired to the network.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      final success = await widget.onAssignNode(assignedNode.id, fieldId: null, monitoringZoneId: null);
                      if (success) {
                        await widget.onRefresh();
                      }
                    }
                  },
                ),
              if (assignedNode != null && widget.onUnpairNode != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.link_off_rounded, size: 16),
                  label: const Text('Unpair Node'),
                  onPressed: () async {
                    final unpairSuccess = await NodeUnpairConfirmationDialog.show(
                      context,
                      nodeId: assignedNode.id,
                      displayName: assignedNode.displayName,
                      onConfirm: () => widget.onUnpairNode!(assignedNode.id),
                    );
                    if (unpairSuccess == true && mounted) {
                      await widget.onRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Node ${assignedNode.displayName.isNotEmpty ? assignedNode.displayName : assignedNode.id} unpaired and revoked.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.call_split, size: 16),
                label: const Text('Split'),
                onPressed: () => _openSplitDialog(zone),
              ),
              IconButton(
                icon: const Icon(Icons.archive_outlined, color: AppColors.error),
                tooltip: 'Archive Area',
                onPressed: () => _archiveZone(zone),
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow) ...[
                headerInfo,
                const SizedBox(height: 12),
                actionButtons,
              ] else ...[
                Row(
                  children: [
                    Expanded(child: headerInfo),
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              if (assignedNode != null) ...[
                Text('Assigned Hardware Telemetry', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        theme,
                        label: 'Soil Moisture',
                        value: '${assignedNode.soilMoisturePercent?.toStringAsFixed(1) ?? '--'}%',
                        icon: Icons.water_drop,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        theme,
                        label: 'Water Level',
                        value: '${assignedNode.waterLevelCm?.toStringAsFixed(1) ?? '--'} cm',
                        icon: Icons.waves,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        theme,
                        label: 'Battery Health',
                        value: '${assignedNode.batteryPercent ?? 0}%',
                        icon: Icons.battery_charging_full,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        theme,
                        label: 'Signal / MAC',
                        value: assignedNode.macAddress.split(':').take(2).join(':'),
                        icon: Icons.wifi,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'This zone currently has no physical ArvaNode assigned. Real-time 3-second irrigation sensor telemetry and automated pump actions cannot be triggered until a node is assigned.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _openNodeAssignmentModal(zone),
                        child: const Text('Assign ArvaNode'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  final Color lineColor;

  const _GridPatternPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    const double step = 30.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
