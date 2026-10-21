import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/widgets/aqua_card.dart';
import '../../../nodes/domain/models/esp32_node.dart';
import '../../../zones/domain/models/monitoring_zone.dart';

enum WaterLevelUnit { inches, centimeters, feet }

/// A responsive, physical representation of an ultrasonic water-level tube.
///
/// Converts measured sensor-to-ball distance into actual water column height:
/// Water Level = Calibrated Sensor-to-Bottom Distance − Measured Sensor-to-Ball Distance
/// Max measurable level = 3 feet (36 inches = 91.44 cm).
class UltrasonicWaterLevelDiagram extends StatefulWidget {
  final List<Esp32Node> nodes;
  final List<MonitoringZone> zones;
  final String? initialSelectedNodeId;

  const UltrasonicWaterLevelDiagram({
    super.key,
    required this.nodes,
    this.zones = const [],
    this.initialSelectedNodeId,
  });

  @override
  State<UltrasonicWaterLevelDiagram> createState() => _UltrasonicWaterLevelDiagramState();
}

class _UltrasonicWaterLevelDiagramState extends State<UltrasonicWaterLevelDiagram> {
  late String? _selectedNodeId;
  WaterLevelUnit _activeUnit = WaterLevelUnit.inches;
  double _customDatumCm = 101.6; // 40 inches default datum

  static const double maxWaterLevelCm = 91.44; // 36 inches (3 feet)

  @override
  void initState() {
    super.initState();
    _selectedNodeId = widget.initialSelectedNodeId ??
        (widget.nodes.isNotEmpty ? widget.nodes.first.id : null);
    _syncDatumFromNode();
  }

  @override
  void didUpdateWidget(covariant UltrasonicWaterLevelDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedNodeId == null && widget.nodes.isNotEmpty) {
      _selectedNodeId = widget.nodes.first.id;
    } else if (_selectedNodeId != null &&
        !widget.nodes.any((n) => n.id == _selectedNodeId) &&
        widget.nodes.isNotEmpty) {
      _selectedNodeId = widget.nodes.first.id;
    }
    _syncDatumFromNode();
  }

  void _syncDatumFromNode() {
    final node = _currentNode;
    if (node != null && node.waterLevelDistanceCm != null) {
      final dist = node.waterLevelDistanceCm!;
      // If physical installation is deeper than 101.6cm, adapt datum
      if (dist > _customDatumCm) {
        _customDatumCm = dist + 5.0;
      }
    }
  }

  Esp32Node? get _currentNode {
    if (widget.nodes.isEmpty) return null;
    return widget.nodes.firstWhere(
      (n) => n.id == _selectedNodeId,
      orElse: () => widget.nodes.first,
    );
  }

  MonitoringZone? get _currentZone {
    final node = _currentNode;
    if (node == null || widget.zones.isEmpty) return null;
    return widget.zones.where(
      (z) =>
          z.id == node.assignedZoneId ||
          z.code == node.assignedZoneId ||
          node.assignedZoneId == 'zone-${z.id}' ||
          node.assignedZoneId == z.id.replaceAll(RegExp(r'[^0-9]'), ''),
    ).firstOrNull;
  }

  double? _calculateWaterLevelCm(double? rawDistanceCm) {
    if (rawDistanceCm == null) return null;
    if (rawDistanceCm == 0.0) return 0.0;
    if (rawDistanceCm < 2.0 || rawDistanceCm > 500.0) return null; // out of range echo
    final rawLevel = _customDatumCm - rawDistanceCm;
    if (rawLevel < 0.0) return 0.0;
    if (rawLevel > maxWaterLevelCm) return maxWaterLevelCm;
    return rawLevel;
  }

  String _formatLevel(double? levelCm) {
    if (levelCm == null) return '—';
    switch (_activeUnit) {
      case WaterLevelUnit.inches:
        final inches = levelCm / 2.54;
        return '${inches.toStringAsFixed(1)} in';
      case WaterLevelUnit.centimeters:
        return '${levelCm.toStringAsFixed(1)} cm';
      case WaterLevelUnit.feet:
        final feet = (levelCm / 2.54) / 12.0;
        return '${feet.toStringAsFixed(2)} ft';
    }
  }

  String _formatDistance(double? distCm) {
    if (distCm == null) return 'No Echo';
    switch (_activeUnit) {
      case WaterLevelUnit.inches:
        final inches = distCm / 2.54;
        return '${inches.toStringAsFixed(1)} in';
      case WaterLevelUnit.centimeters:
        return '${distCm.toStringAsFixed(1)} cm';
      case WaterLevelUnit.feet:
        final feet = (distCm / 2.54) / 12.0;
        return '${feet.toStringAsFixed(2)} ft';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = _currentNode;
    final zone = _currentZone;

    final rawDistance = node?.waterLevelDistanceCm;
    final bool isUltrasonicSensorFailed = node?.isUltrasonicSensorFailed ?? false;
    final waterLevelCm = (isUltrasonicSensorFailed || rawDistance == 0.0)
        ? 0.0
        : (_calculateWaterLevelCm(rawDistance) ??
            (node?.waterLevelCm != null && node!.waterLevelCm! >= 0 ? node.waterLevelCm : null));

    final bool hasValidReading = !isUltrasonicSensorFailed &&
        rawDistance != null &&
        rawDistance >= 2.0 &&
        rawDistance <= 500.0;

    return AquaCard(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Node Selector
          _buildCardHeader(theme, node, zone),
          const SizedBox(height: AppDimensions.spaceMd),

          // Main Visual Section: Diagram + Live Telemetry Details
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 540;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Physical Tube Diagram
                    Expanded(
                      flex: 6,
                      child: _buildDiagramFrame(context, waterLevelCm, rawDistance, hasValidReading),
                    ),
                    const SizedBox(width: AppDimensions.spaceMd),
                    // Telemetry & Control Panel
                    Expanded(
                      flex: 5,
                      child: _buildTelemetrySidebar(theme, node, waterLevelCm, rawDistance, hasValidReading),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildDiagramFrame(context, waterLevelCm, rawDistance, hasValidReading),
                    const SizedBox(height: AppDimensions.spaceMd),
                    _buildTelemetrySidebar(theme, node, waterLevelCm, rawDistance, hasValidReading),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader(ThemeData theme, Esp32Node? node, MonitoringZone? zone) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.waves, size: 20, color: AppColors.primary),
                  const SizedBox(width: AppDimensions.spaceSm),
                  Expanded(
                    child: Text(
                      'Ultrasonic Water-Level Column',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Acoustic echo to internal floating ball • Max measurable height 3 ft',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spaceSm),
        // Unit Selector Chips
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUnitPill('in', WaterLevelUnit.inches),
              _buildUnitPill('cm', WaterLevelUnit.centimeters),
              _buildUnitPill('ft', WaterLevelUnit.feet),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitPill(String label, WaterLevelUnit unit) {
    final isSelected = _activeUnit == unit;
    return InkWell(
      onTap: () => setState(() => _activeUnit = unit),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  Widget _buildDiagramFrame(BuildContext context, double? waterLevelCm, double? rawDistanceCm, bool hasValidReading) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 310,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A131F) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: 0.0,
          end: hasValidReading ? (waterLevelCm ?? 0.0) : 0.0,
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, animatedLevelCm, child) {
          return CustomPaint(
            painter: _TubeWaterPainter(
              waterLevelCm: animatedLevelCm,
              rawDistanceCm: rawDistanceCm,
              datumCm: _customDatumCm,
              maxMeasurableCm: maxWaterLevelCm,
              hasValidReading: hasValidReading,
              unit: _activeUnit,
              isDark: Theme.of(context).brightness == Brightness.dark,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }

  Widget _buildTelemetrySidebar(
    ThemeData theme,
    Esp32Node? node,
    double? waterLevelCm,
    double? rawDistance,
    bool hasValidReading,
  ) {
    // Water Level status badge text and color
    String statusText;
    Color statusColor;

    if (!hasValidReading) {
      final healthReason = node?.ultrasonicSensorHealth;
      statusText = healthReason != null && healthReason.isNotEmpty && healthReason != 'OK'
          ? 'ULTRASONIC SENSOR $healthReason (0.0 CM)'
          : 'NO VALID ECHO / OUT OF RANGE (0.0 CM)';
      statusColor = AppColors.alertWarning;
    } else if (waterLevelCm != null && waterLevelCm <= 5.0) {
      statusText = 'TUBE DRY / BALL AT BASE (0.0 IN)';
      statusColor = AppColors.warning;
    } else if (waterLevelCm != null && waterLevelCm >= maxWaterLevelCm * 0.9) {
      statusText = 'HIGH WATER LEVEL (>90% CAPACITY)';
      statusColor = AppColors.success;
    } else {
      statusText = 'NORMAL HYDROLOGICAL RANGE';
      statusColor = AppColors.primary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Node Selector Dropdown if multiple nodes exist
        if (widget.nodes.length > 1) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedNodeId,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                items: widget.nodes.map((n) {
                  return DropdownMenuItem<String>(
                    value: n.id,
                    child: Text(
                      '${n.displayName} (${n.id})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    setState(() {
                      _selectedNodeId = id;
                      _syncDatumFromNode();
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceSm),
        ],

        // Status Badge Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(
                hasValidReading ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                size: 15,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceMd),

        // Primary Metric Display: Water Column Height
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceSm),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'CALCULATED WATER LEVEL',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_upward, size: 14, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                waterLevelCm != null ? _formatLevel(waterLevelCm) : _formatLevel(0.0),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: hasValidReading ? AppColors.accent : AppColors.alertWarning,
                ),
              ),
              Text(
                hasValidReading
                    ? 'Vertical liquid height above tube base'
                    : 'Sensor fault / timeout fallback (0.0)',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceSm),

        // Secondary Metrics: Raw Distance & Installation Datum
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.arrow_downward, size: 11, color: Colors.orangeAccent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'ECHO DISTANCE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.orangeAccent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rawDistance != null ? _formatDistance(rawDistance) : _formatDistance(0.0),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Sensor → Ball',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spaceSm),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.straighten, size: 11, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'TOTAL DATUM',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDistance(_customDatumCm),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Sensor → Bottom',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceSm),

        // Formula Explainer Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: AppColors.textSecondaryOf(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Water Level = Datum (${(_customDatumCm / 2.54).toStringAsFixed(0)} in) − Echo Distance',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter rendering the physical tube, floating ball, acoustic beam, and graduated ruler.
class _TubeWaterPainter extends CustomPainter {
  final double waterLevelCm;
  final double? rawDistanceCm;
  final double datumCm;
  final double maxMeasurableCm;
  final bool hasValidReading;
  final WaterLevelUnit unit;
  final bool isDark;

  _TubeWaterPainter({
    required this.waterLevelCm,
    required this.rawDistanceCm,
    required this.datumCm,
    required this.maxMeasurableCm,
    required this.hasValidReading,
    required this.unit,
    this.isDark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Theme-adaptive painter colors
    final tickColor = isDark ? Colors.white30 : const Color(0xFF94A3B8);
    final majorTickColor = isDark ? Colors.white70 : const Color(0xFF334155);
    final tickTextColor = isDark ? Colors.white70 : const Color(0xFF334155);
    final zeroTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final baseColor = isDark ? const Color(0xFF2E3D52) : const Color(0xFFCBD5E1);

    // Center the tube slightly left of middle to allocate comfortable margin for ruler ticks on right
    // and dual measurement arrows on the left without edge clipping.
    final double tubeCenterX = size.width * 0.44;
    final double tubeWidth = math.min(52.0, size.width * 0.22);
    final double tubeLeft = tubeCenterX - tubeWidth / 2;
    final double tubeRight = tubeCenterX + tubeWidth / 2;

    final double topMargin = 42.0;
    final double bottomMargin = 28.0;
    final double tubeTopY = topMargin;
    final double tubeBottomY = size.height - bottomMargin;
    final double tubeHeight = tubeBottomY - tubeTopY;

    // 1. Draw Concrete / Soil Stand & Base Plate
    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(tubeLeft - 18, tubeBottomY, tubeRight + 18, tubeBottomY + 12),
        const Radius.circular(3),
      ),
      basePaint,
    );

    // Bottom zero label
    _drawText(
      canvas,
      '0',
      Offset(tubeRight + 8, tubeBottomY - 7),
      TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: zeroTextColor),
    );

    // 2. Draw Graduated Scale / Ruler Ticks on the Right
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.0;
    final majorTickPaint = Paint()
      ..color = majorTickColor
      ..strokeWidth = 1.5;

    // Ruler based on inches, cm, or feet
    if (unit == WaterLevelUnit.centimeters) {
      // 0 to datumCm ticks
      for (double cm = 0; cm <= datumCm; cm += 10) {
        final double ratio = cm / datumCm;
        final double y = tubeBottomY - (ratio * tubeHeight);
        if (y < tubeTopY - 2) continue;
        final isMajor = (cm % 20) == 0;
        final double tickLen = isMajor ? 12 : 6;
        canvas.drawLine(
          Offset(tubeRight + 3, y),
          Offset(tubeRight + 3 + tickLen, y),
          isMajor ? majorTickPaint : tickPaint,
        );
        if (isMajor && cm > 0) {
          _drawText(
            canvas,
            '${cm.toInt()}',
            Offset(tubeRight + tickLen + 5, y - 6),
            TextStyle(fontSize: 9, color: tickTextColor),
          );
        }
      }
    } else if (unit == WaterLevelUnit.feet) {
      // Feet ticks: 0, 1, 2, 3 ft (every 0.5 ft tick, major every 1 ft)
      final double totalFeet = (datumCm / 2.54) / 12.0;
      for (double ft = 0; ft <= totalFeet; ft += 0.5) {
        final double cm = ft * 12.0 * 2.54;
        final double ratio = cm / datumCm;
        final double y = tubeBottomY - (ratio * tubeHeight);
        if (y < tubeTopY - 2) continue;
        final isMajor = (ft % 1.0) == 0;
        final double tickLen = isMajor ? 12 : 6;
        canvas.drawLine(
          Offset(tubeRight + 3, y),
          Offset(tubeRight + 3 + tickLen, y),
          isMajor ? majorTickPaint : tickPaint,
        );
        if (isMajor && ft > 0) {
          _drawText(
            canvas,
            '${ft.toInt()}ft',
            Offset(tubeRight + tickLen + 5, y - 6),
            TextStyle(fontSize: 9, color: tickTextColor),
          );
        }
      }
    } else {
      // Inches ticks: 0 to datumInches (every 2 in, major every 6 in)
      final double totalInches = datumCm / 2.54;
      for (double inch = 0; inch <= totalInches; inch += 2) {
        final double ratio = (inch * 2.54) / datumCm;
        final double y = tubeBottomY - (ratio * tubeHeight);
        if (y < tubeTopY - 2) continue;
        final isMajor = (inch % 6) == 0;
        final double tickLen = isMajor ? 12 : 6;
        canvas.drawLine(
          Offset(tubeRight + 3, y),
          Offset(tubeRight + 3 + tickLen, y),
          isMajor ? majorTickPaint : tickPaint,
        );
        if (isMajor && inch > 0) {
          _drawText(
            canvas,
            '${inch.toInt()}"',
            Offset(tubeRight + tickLen + 5, y - 6),
            TextStyle(fontSize: 9, color: tickTextColor),
          );
        }
      }
    }

    // 3. Draw Max 3-Foot (36-inch / 91.44 cm) Mark
    final double maxRatio = maxMeasurableCm / datumCm;
    final double maxY = tubeBottomY - (maxRatio * tubeHeight);
    if (maxY >= tubeTopY) {
      final dashPaint = Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.8)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      _drawDashedLine(canvas, Offset(tubeLeft - 10, maxY), Offset(tubeRight + 10, maxY), dashPaint);
      _drawText(
        canvas,
        'MAX 3 FT (36")',
        Offset(tubeLeft - 14, maxY - 14),
        const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Color(0xFFEF4444),
          letterSpacing: 0.5,
        ),
      );
    }

    // 4. Draw Tube Acrylic Body
    final tubePaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : const Color(0xFFE2E8F0).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final tubeRect = Rect.fromLTRB(tubeLeft, tubeTopY, tubeRight, tubeBottomY);
    canvas.drawRect(tubeRect, tubePaint);

    final tubeBorderPaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black26
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(tubeRect, tubeBorderPaint);

    // Tube glass highlight reflection line
    final glassHighlight = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(tubeLeft + 5, tubeTopY + 2),
      Offset(tubeLeft + 5, tubeBottomY - 2),
      glassHighlight,
    );

    // 5. Water Column and Floating Ball
    double waterY = tubeBottomY;
    if (hasValidReading) {
      final clampedLevel = math.min(waterLevelCm, maxMeasurableCm);
      final levelRatio = clampedLevel / datumCm;
      waterY = tubeBottomY - (levelRatio * tubeHeight);
      waterY = waterY.clamp(tubeTopY + 14, tubeBottomY);

      // Water body gradient
      final waterRect = Rect.fromLTRB(tubeLeft + 1, waterY, tubeRight - 1, tubeBottomY);
      final waterGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00B4D8).withValues(alpha: 0.75),
          const Color(0xFF0077B6).withValues(alpha: 0.9),
        ],
      );
      final waterPaint = Paint()
        ..shader = waterGradient.createShader(waterRect)
        ..style = PaintingStyle.fill;
      canvas.drawRect(waterRect, waterPaint);

      // Water surface line with wave meniscus
      final surfacePaint = Paint()
        ..color = const Color(0xFF90E0EF)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(tubeLeft + 1, waterY),
        Offset(tubeRight - 1, waterY),
        surfacePaint,
      );

      // Floating Ball: Spherical float positioned at water surface
      final double ballRadius = tubeWidth * 0.32;
      final double ballCenterX = tubeCenterX;
      // Ball floats halfway submerged at surface
      final double ballCenterY = waterY - (ballRadius * 0.35);

      // 3D Spherical Radial Gradient
      final ballPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.85,
          colors: [
            Colors.white,
            const Color(0xFFF59E0B),
            const Color(0xFFD97706),
            const Color(0xFF78350F),
          ],
          stops: const [0.0, 0.45, 0.8, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(ballCenterX, ballCenterY), radius: ballRadius));

      canvas.drawCircle(Offset(ballCenterX, ballCenterY), ballRadius, ballPaint);

      // Ball shadow border
      final ballOutline = Paint()
        ..color = Colors.black45
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(ballCenterX, ballCenterY), ballRadius, ballOutline);

      // Ball surface label indicator
      _drawText(
        canvas,
        'FLOAT',
        Offset(ballCenterX - 11, ballCenterY - 4),
        const TextStyle(
          fontSize: 7,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      );

      // 6. Upward Measurement Indicator (Water Height)
      final arrowPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 1.5;
      final double arrowX = tubeLeft - 16;
      canvas.drawLine(Offset(arrowX, tubeBottomY), Offset(arrowX, waterY), arrowPaint);
      _drawArrowHead(canvas, Offset(arrowX, waterY), arrowPaint, pointingUp: true);
      _drawArrowHead(canvas, Offset(arrowX, tubeBottomY), arrowPaint, pointingUp: false);

      // Upward level label formatted in active unit
      final double levelSpan = (tubeBottomY - waterY).abs();
      final String heightStr = unit == WaterLevelUnit.inches
          ? '${(waterLevelCm / 2.54).toStringAsFixed(1)}"'
          : unit == WaterLevelUnit.feet
              ? '${(waterLevelCm / 30.48).toStringAsFixed(2)}ft'
              : '${waterLevelCm.toStringAsFixed(1)}cm';

      if (levelSpan >= 36) {
        final double midY = (tubeBottomY + waterY) / 2;
        _drawRotatedText(
          canvas,
          'Height: $heightStr',
          Offset(arrowX - 8, midY),
          const TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF10B981),
          ),
        );
      }

      // 7. Downward Measurement Indicator (Acoustic Distance)
      final downArrowPaint = Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 1.5;
      final double downArrowX = tubeLeft - 30;
      final double topBallY = ballCenterY - ballRadius;
      canvas.drawLine(Offset(downArrowX, tubeTopY), Offset(downArrowX, topBallY), downArrowPaint);
      _drawArrowHead(canvas, Offset(downArrowX, topBallY), downArrowPaint, pointingUp: false);
      _drawArrowHead(canvas, Offset(downArrowX, tubeTopY), downArrowPaint, pointingUp: true);

      final double echoSpan = (topBallY - tubeTopY).abs();
      final double echoCm = rawDistanceCm ?? 0.0;
      final String echoStr = unit == WaterLevelUnit.inches
          ? '${(echoCm / 2.54).toStringAsFixed(1)}"'
          : unit == WaterLevelUnit.feet
              ? '${(echoCm / 30.48).toStringAsFixed(2)}ft'
              : '${echoCm.toStringAsFixed(1)}cm';

      if (echoSpan >= 36) {
        final double downMidY = (tubeTopY + topBallY) / 2;
        _drawRotatedText(
          canvas,
          'Echo: $echoStr',
          Offset(downArrowX - 8, downMidY),
          const TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.bold,
            color: Colors.orangeAccent,
          ),
        );
      }
    } else {
      // Invalid or offline reading: Draw ghost ball at bottom
      final ghostPaint = Paint()
        ..color = isDark ? Colors.white12 : Colors.black12
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(tubeCenterX, tubeBottomY - 14), 14, ghostPaint);
      _drawText(
        canvas,
        'OFFLINE',
        Offset(tubeCenterX - 18, tubeBottomY - 18),
        TextStyle(fontSize: 8, color: isDark ? Colors.white30 : Colors.black38, fontWeight: FontWeight.bold),
      );
    }

    // 8. Ultrasonic Sensor Housing at Tube Top
    final sensorHousingPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.fill;
    final sensorHousingRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(tubeLeft - 6, tubeTopY - 26, tubeRight + 6, tubeTopY - 6),
      const Radius.circular(4),
    );
    canvas.drawRRect(sensorHousingRect, sensorHousingPaint);

    final sensorBorderPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(sensorHousingRect, sensorBorderPaint);

    // Dual Ultrasonic Transducer Cylinders (Transmitter T & Receiver R)
    final double transducerRadius = 6.5;
    final double t1X = tubeCenterX - 11;
    final double t2X = tubeCenterX + 11;
    final double tY = tubeTopY - 6;

    final transducerPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(t1X, tY), transducerRadius, transducerPaint);
    canvas.drawCircle(Offset(t2X, tY), transducerRadius, transducerPaint);

    final transducerHolePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(t1X, tY), 3.0, transducerHolePaint);
    canvas.drawCircle(Offset(t2X, tY), 3.0, transducerHolePaint);

    // Ultrasonic acoustic beam pulses pointing downward
    if (hasValidReading) {
      final wavePaint = Paint()
        ..color = const Color(0xFF00B4D8).withValues(alpha: 0.45)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final double maxWaveY = math.min(waterY - 15, tubeTopY + 50);
      for (double waveY = tubeTopY + 4; waveY < maxWaveY; waveY += 10) {
        final double spread = (waveY - tubeTopY) * 0.35;
        canvas.drawArc(
          Rect.fromCenter(center: Offset(tubeCenterX, waveY - 8), width: spread * 2 + 12, height: 16),
          0.3,
          math.pi - 0.6,
          false,
          wavePaint,
        );
      }
    }

    // Top Header Label
    _drawText(
      canvas,
      'ULTRASONIC TRANSDUCER',
      Offset(tubeCenterX - 45, tubeTopY - 37),
      const TextStyle(
        fontSize: 7.5,
        fontWeight: FontWeight.bold,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.5,
      ),
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 4.0;
    const double dashSpace = 3.0;
    double currentX = p1.dx;
    while (currentX < p2.dx) {
      canvas.drawLine(
        Offset(currentX, p1.dy),
        Offset(math.min(currentX + dashWidth, p2.dx), p1.dy),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Paint paint, {required bool pointingUp}) {
    final path = Path();
    const double arrowSize = 4.0;
    if (pointingUp) {
      path.moveTo(tip.dx, tip.dy);
      path.lineTo(tip.dx - arrowSize, tip.dy + arrowSize * 1.5);
      path.lineTo(tip.dx + arrowSize, tip.dy + arrowSize * 1.5);
    } else {
      path.moveTo(tip.dx, tip.dy);
      path.lineTo(tip.dx - arrowSize, tip.dy - arrowSize * 1.5);
      path.lineTo(tip.dx + arrowSize, tip.dy - arrowSize * 1.5);
    }
    path.close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, offset);
  }

  void _drawRotatedText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(-math.pi / 2);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TubeWaterPainter oldDelegate) {
    return oldDelegate.waterLevelCm != waterLevelCm ||
        oldDelegate.rawDistanceCm != rawDistanceCm ||
        oldDelegate.datumCm != datumCm ||
        oldDelegate.hasValidReading != hasValidReading ||
        oldDelegate.unit != unit ||
        oldDelegate.isDark != isDark;
  }
}

