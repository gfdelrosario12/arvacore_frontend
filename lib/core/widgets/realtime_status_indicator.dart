import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../realtime/realtime_coordinator.dart';

class RealtimeStatusIndicator extends StatelessWidget {
  final RealtimeState state;
  final VoidCallback? onRetry;

  const RealtimeStatusIndicator({
    super.key,
    required this.state,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (state.connection == RealtimeConnectionState.connected && !state.isPollingFallback) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync, size: 14, color: AppColors.success),
            SizedBox(width: 4),
            Text(
              'LIVE REST SYNC',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    final isConnecting = state.connection == RealtimeConnectionState.connecting ||
        state.connection == RealtimeConnectionState.reconnecting;
    final isDegraded = state.isDegraded;

    final color = isConnecting
        ? AppColors.warning
        : (isDegraded ? AppColors.alertWarning : AppColors.error);
    final label = isConnecting
        ? 'Reconnecting...'
        : (state.isPollingFallback
            ? 'Degraded (REST Fallback)'
            : 'Disconnected');

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spaceSm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnecting ? Icons.sync : Icons.cloud_off,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (onRetry != null && !isConnecting) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRetry,
              child: Icon(Icons.refresh, size: 14, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

