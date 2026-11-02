import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

enum StatusBadgeType {
  monitoring,
  awd,
  irrigation,
  device,
  alert,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeType type;
  final Color? colorOverride;
  final IconData? icon;
  final bool isCompact;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusBadgeType.monitoring,
    this.colorOverride,
    this.icon,
    this.isCompact = false,
  });

  factory StatusBadge.zoneStatus(String statusName, {bool compact = false}) {
    Color bg;
    IconData defaultIcon = Icons.sensors;
    final lower = statusName.toLowerCase();
    if (lower.contains('optimal')) {
      bg = AppColors.zoneOptimal;
    } else if (lower.contains('low') || lower.contains('warning')) {
      bg = AppColors.zoneLow;
    } else if (lower.contains('critical')) {
      bg = AppColors.zoneCritical;
    } else {
      bg = AppColors.zoneOffline;
    }
    return StatusBadge(
      label: statusName.toUpperCase(),
      type: StatusBadgeType.monitoring,
      colorOverride: bg,
      icon: defaultIcon,
      isCompact: compact,
    );
  }

  factory StatusBadge.hydrologyStatus(String statusName, {bool compact = false}) {
    Color bg;
    IconData defaultIcon = Icons.water_damage;
    final lower = statusName.toLowerCase();
    if (lower.contains('safe')) {
      bg = AppColors.irrigationSafe;
    } else if (lower.contains('reflux') || lower.contains('dry')) {
      bg = AppColors.irrigationRefluxNeeded;
    } else {
      bg = AppColors.irrigationFlooded;
    }
    return StatusBadge(
      label: statusName.toUpperCase(),
      type: StatusBadgeType.irrigation,
      colorOverride: bg,
      icon: defaultIcon,
      isCompact: compact,
    );
  }

  factory StatusBadge.awdStatus(String statusName, {bool compact = false}) =>
      StatusBadge.hydrologyStatus(statusName, compact: compact);

  factory StatusBadge.irrigationStatus(bool isActive, {String? customLabel, bool compact = false}) {
    return StatusBadge(
      label: customLabel ?? (isActive ? 'PUMP ACTIVE' : 'PUMP IDLE'),
      type: StatusBadgeType.irrigation,
      colorOverride: isActive ? AppColors.pumpActive : AppColors.pumpIdle,
      icon: isActive ? Icons.water_drop : Icons.pause_circle_outline,
      isCompact: compact,
    );
  }

  factory StatusBadge.deviceStatus(String statusName, {bool compact = false}) {
    Color bg;
    IconData defaultIcon = Icons.cell_tower;
    final lower = statusName.toLowerCase();
    if (lower.contains('battery low')) {
      bg = AppColors.deviceBatteryLow;
      defaultIcon = Icons.battery_alert;
    } else if (lower.contains('battery')) {
      bg = AppColors.deviceBatteryGood;
      defaultIcon = Icons.battery_full;
    } else if (lower.contains('weak')) {
      bg = AppColors.deviceLoRaWeak;
      defaultIcon = Icons.signal_cellular_alt_1_bar;
    } else {
      bg = AppColors.deviceLoRaConnected;
      defaultIcon = Icons.signal_cellular_alt;
    }
    return StatusBadge(
      label: statusName.toUpperCase(),
      type: StatusBadgeType.device,
      colorOverride: bg,
      icon: defaultIcon,
      isCompact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final badgeColor = colorOverride ?? AppColors.primary;
    final paddingHorizontal = isCompact ? 8.0 : 12.0;
    final paddingVertical = isCompact ? 3.0 : 5.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: paddingHorizontal,
        vertical: paddingVertical,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(
          color: badgeColor.withValues(alpha: isDark ? 0.40 : 0.45), 
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: isCompact ? 12 : 14,
              color: badgeColor,
            ),
            const SizedBox(width: 5),
          ] else ...[
            Container(
              width: isCompact ? 6 : 7,
              height: isCompact ? 6 : 7,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 10.5 : 12.0,
                fontWeight: FontWeight.w700,
                color: badgeColor,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
