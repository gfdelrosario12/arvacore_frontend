import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/telemetry_stream_event.dart';

class TelemetryStreamEventCard extends StatefulWidget {
  final TelemetryStreamEvent event;

  const TelemetryStreamEventCard({
    super.key,
    required this.event,
  });

  @override
  State<TelemetryStreamEventCard> createState() => _TelemetryStreamEventCardState();
}

class _TelemetryStreamEventCardState extends State<TelemetryStreamEventCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final event = widget.event;

    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = _getStatusBorderColor(event.status, isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                // Node ID Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.router, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        event.nodeId,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (event.sequenceNumber != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceLight : AppColors.lightSurfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Seq #${event.sequenceNumber}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
                if (event.zoneCode != null && event.zoneCode!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.awdFlooded.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.awdFlooded.withOpacity(0.3)),
                    ),
                    child: Text(
                      event.zoneCode!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.awdFlooded,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Status Badge
                _buildStatusBadge(event.status, event.rawStatus),
              ],
            ),
          ),

          // Timestamps row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 13,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Received: ${_formatDateTime(event.receivedAt)} (${_relativeTime(event.receivedAt)})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    fontSize: 11,
                  ),
                ),
                if (event.deviceTimestamp != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• Device: ${_formatTimeOnly(event.deviceTimestamp!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Sensor Measurements Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Soil Moisture
                _buildMeasurementChip(
                  context,
                  icon: Icons.water_drop,
                  label: 'Soil Moisture',
                  value: event.soilMoisturePercent != null
                      ? '${event.soilMoisturePercent!.toStringAsFixed(1)}%'
                      : 'Not included',
                  color: AppColors.zoneOptimal,
                ),
                // Water Level (Height from bottom)
                _buildMeasurementChip(
                  context,
                  icon: Icons.waves,
                  label: 'Water Level',
                  value: _formatWaterLevel(event.waterLevelCm, event.waterLevelDistanceCm),
                  color: AppColors.awdSafe,
                ),
                // Ultrasonic Distance
                if (event.waterLevelDistanceCm != null)
                  _buildMeasurementChip(
                    context,
                    icon: Icons.height,
                    label: 'Sensor Distance',
                    value: '${event.waterLevelDistanceCm!.toStringAsFixed(1)} cm',
                    color: AppColors.awdFlooded,
                  ),
                // Battery
                if (event.batteryLevel != null || event.batteryVoltage != null)
                  _buildMeasurementChip(
                    context,
                    icon: Icons.battery_charging_full,
                    label: 'Battery',
                    value: _formatBattery(event.batteryLevel, event.batteryVoltage),
                    color: (event.batteryLevel != null && event.batteryLevel! < 20)
                        ? AppColors.zoneLow
                        : AppColors.deviceBatteryGood,
                  ),
                // Signal
                if (event.rssiDbm != null)
                  _buildMeasurementChip(
                    context,
                    icon: Icons.wifi,
                    label: 'Signal',
                    value: '${event.rssiDbm} dBm${event.snrDb != null ? ' • ${event.snrDb!.toStringAsFixed(1)} dB' : ''}',
                    color: AppColors.deviceLoRaConnected,
                  ),
              ],
            ),
          ),

          // Status message (if present or warning)
          if (event.statusMessage != null && event.statusMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (event.status == TelemetryStreamStatus.failed ||
                          event.status == TelemetryStreamStatus.rejected)
                      ? AppColors.zoneCritical.withOpacity(0.08)
                      : (event.status == TelemetryStreamStatus.partiallyProcessed)
                          ? AppColors.zoneLow.withOpacity(0.08)
                          : AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      event.status == TelemetryStreamStatus.failed ||
                              event.status == TelemetryStreamStatus.rejected
                          ? Icons.error_outline
                          : Icons.info_outline,
                      size: 14,
                      color: (event.status == TelemetryStreamStatus.failed ||
                              event.status == TelemetryStreamStatus.rejected)
                          ? AppColors.zoneCritical
                          : (event.status == TelemetryStreamStatus.partiallyProcessed)
                              ? AppColors.zoneLow
                              : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event.statusMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Expandable Raw Payload Toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isExpanded ? 'Hide Raw Transmission Payload' : 'View Raw Transmission Payload (JSON)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  if (_isExpanded)
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: event.formattedRawPayload));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Raw JSON payload copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Copy JSON',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Expanded Raw Payload Box
          if (_isExpanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF09111E) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: SelectableText(
                event.formattedRawPayload,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TelemetryStreamStatus status, String rawStatus) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case TelemetryStreamStatus.processed:
        color = AppColors.zoneOptimal;
        icon = Icons.check_circle;
        label = 'PROCESSED';
        break;
      case TelemetryStreamStatus.partiallyProcessed:
        color = AppColors.zoneLow;
        icon = Icons.warning_amber_rounded;
        label = 'PARTIAL';
        break;
      case TelemetryStreamStatus.rejected:
        color = AppColors.zoneCritical;
        icon = Icons.cancel;
        label = 'REJECTED';
        break;
      case TelemetryStreamStatus.failed:
        color = AppColors.zoneCritical;
        icon = Icons.error;
        label = 'FAILED';
        break;
      case TelemetryStreamStatus.unknown:
      default:
        color = AppColors.zoneOffline;
        icon = Icons.help_outline;
        label = rawStatus.toUpperCase();
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceLight.withValues(alpha: 0.5) : AppColors.lightSurfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusBorderColor(TelemetryStreamStatus status, bool isDark) {
    switch (status) {
      case TelemetryStreamStatus.failed:
      case TelemetryStreamStatus.rejected:
        return AppColors.zoneCritical.withOpacity(0.4);
      case TelemetryStreamStatus.partiallyProcessed:
        return AppColors.zoneLow.withOpacity(0.4);
      case TelemetryStreamStatus.processed:
      case TelemetryStreamStatus.unknown:
      default:
        return isDark ? AppColors.darkBorder : AppColors.lightBorder;
    }
  }

  String _formatWaterLevel(double? waterLevelCm, double? distanceCm) {
    if (waterLevelCm != null) {
      final inches = waterLevelCm / 2.54;
      return '${waterLevelCm.toStringAsFixed(1)} cm (${inches.toStringAsFixed(1)} in)';
    }
    if (distanceCm != null) {
      // If water height is not explicitly provided, indicate distance measured
      return 'Distance: ${distanceCm.toStringAsFixed(1)} cm';
    }
    return 'Not included';
  }

  String _formatBattery(double? level, double? voltage) {
    if (level != null && voltage != null) {
      return '${level.toStringAsFixed(0)}% • ${voltage.toStringAsFixed(2)}V';
    }
    if (level != null) return '${level.toStringAsFixed(0)}%';
    if (voltage != null) return '${voltage.toStringAsFixed(2)}V';
    return 'Not included';
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatTimeOnly(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 10) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

