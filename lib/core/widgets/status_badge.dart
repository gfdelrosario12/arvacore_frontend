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

  factory StatusBadge.awdStatus(String statusName, {bool compact = false}) {
    Color bg;
    IconData defaultIcon = Icons.water_damage;
    final lower = statusName.toLowerCase();
    if (lower.contains('safe')) {
      bg = AppColors.awdSafe;
    } else if (lower.contains('reflux') || lower.contains('dry')) {
      bg = AppColors.awdRefluxNeeded;
    } else {
      bg = AppColors.awdFlooded;
    }
    return StatusBadge(
      label: statusName.toUpperCase(),
      type: StatusBadgeType.awd,
      colorOverride: bg,
      icon: defaultIcon,
      isCompact: compact,
    );
  }

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
    final badgeColor = colorOverride ?? AppColors.primary;
    final paddingHorizontal = isCompact ? 6.0 : 10.0;
    final paddingVertical = isCompact ? 2.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: paddingHorizontal,
        vertical: paddingVertical,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        border: Border.all(color: badgeColor, width: 1.2),
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
            const SizedBox(width: 4),
          ],
          Container(
            width: isCompact ? 5 : 7,
            height: isCompact ? 5 : 7,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 10 : 11,
                fontWeight: FontWeight.bold,
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
