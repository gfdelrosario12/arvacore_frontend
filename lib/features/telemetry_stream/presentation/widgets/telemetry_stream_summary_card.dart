import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/realtime/realtime_coordinator.dart';
import '../../domain/models/telemetry_stream_summary.dart';

class TelemetryStreamSummaryCard extends StatelessWidget {
  final TelemetryStreamSummary summary;
  final bool isRealtimeConnected;
  final RealtimeConnectionState connectionState;

  const TelemetryStreamSummaryCard({
    super.key,
    required this.summary,
    required this.isRealtimeConnected,
    required this.connectionState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.stream, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'ESP32 Transmission Stream Summary',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildConnectionBadge(theme),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              if (isCompact) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricPill(
                      context,
                      label: 'Total Transmissions',
                      value: summary.totalTransmissions.toString(),
                      icon: Icons.receipt_long,
                      color: AppColors.primary,
                      width: (constraints.maxWidth - 12) / 2,
                    ),
                    _buildMetricPill(
                      context,
                      label: 'Last 24 Hours',
                      value: summary.recentTransmissionsCount.toString(),
                      icon: Icons.access_time_filled,
                      color: AppColors.awdSafe,
                      width: (constraints.maxWidth - 12) / 2,
                    ),
                    _buildMetricPill(
                      context,
                      label: 'Active Nodes',
                      value: summary.distinctNodesCount.toString(),
                      icon: Icons.memory,
                      color: AppColors.zoneOptimal,
                      width: (constraints.maxWidth - 12) / 2,
                    ),
                    _buildMetricPill(
                      context,
                      label: 'Failed / Rejected',
                      value: summary.failedOrRejectedCount.toString(),
                      icon: Icons.error_outline,
                      color: summary.failedOrRejectedCount > 0
                          ? AppColors.zoneCritical
                          : AppColors.zoneOptimal,
                      width: (constraints.maxWidth - 12) / 2,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildMetricPill(
                      context,
                      label: 'Total Transmissions',
                      value: summary.totalTransmissions.toString(),
                      icon: Icons.receipt_long,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricPill(
                      context,
                      label: 'Last 24 Hours',
                      value: summary.recentTransmissionsCount.toString(),
                      icon: Icons.access_time_filled,
                      color: AppColors.awdSafe,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricPill(
                      context,
                      label: 'Active Nodes',
                      value: summary.distinctNodesCount.toString(),
                      icon: Icons.memory,
                      color: AppColors.zoneOptimal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricPill(
                      context,
                      label: 'Failed / Rejected',
                      value: summary.failedOrRejectedCount.toString(),
                      icon: Icons.error_outline,
                      color: summary.failedOrRejectedCount > 0
                          ? AppColors.zoneCritical
                          : AppColors.zoneOptimal,
                    ),
                  ),
                ],
              );
            },
          ),
          if (summary.lastEventReceivedAt != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.history, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                const SizedBox(width: 4),
                Text(
                  'Last transmission received: ${_formatDateTime(summary.lastEventReceivedAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionBadge(ThemeData theme) {
    Color badgeColor;
    String label;
    IconData icon;

    switch (connectionState) {
      case RealtimeConnectionState.connected:
        badgeColor = AppColors.zoneOptimal;
        label = 'LIVE WEBSOCKET';
        icon = Icons.sensors;
        break;
      case RealtimeConnectionState.connecting:
      case RealtimeConnectionState.reconnecting:
        badgeColor = AppColors.zoneLow;
        label = 'CONNECTING...';
        icon = Icons.sync;
        break;
      case RealtimeConnectionState.degraded:
        badgeColor = AppColors.zoneLow;
        label = 'POLLING BACKUP';
        icon = Icons.refresh;
        break;
      case RealtimeConnectionState.disconnected:
      case RealtimeConnectionState.closed:
        badgeColor = AppColors.zoneOffline;
        label = 'OFFLINE';
        icon = Icons.sensors_off;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 13, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: badgeColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    double? width,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m:$s';
  }
}

