import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/widgets.dart';
import '../../diagnostics/presentation/device_diagnostics_screen.dart';
import '../../irrigation/presentation/manual_control_screen.dart';
import '../../telemetry_stream/presentation/screens/telemetry_stream_screen.dart';
import '../domain/models/models.dart';

class AlertDetailScreen extends StatelessWidget {
  final SystemAlert alert;
  final VoidCallback? onMarkAsRead;

  const AlertDetailScreen({
    super.key,
    required this.alert,
    this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severityColor = _getSeverityColor(alert.severity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Details'),
        actions: [
          if (!alert.isRead && onMarkAsRead != null)
            TextButton.icon(
              onPressed: () {
                onMarkAsRead!();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Mark Read'),
            ),
        ],
      ),
      body: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Severity & Source Scope
              AquaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: severityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            border: Border.all(color: severityColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getSeverityIcon(alert.severity), color: severityColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                alert.severity.name.toUpperCase(),
                                style: TextStyle(
                                  color: severityColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'SCOPE: ${alert.source.targetScope}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                    Text(
                      alert.title,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alert.description,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                    const Divider(),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Source: ${alert.source.name}',
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceSm),
                        Text(
                          _formatTimestamp(alert.timestamp),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),

              // Action Guidance Card
              AquaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tips_and_updates, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Recommended Action',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),
                    Text(
                      alert.recommendedAction,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleActionNavigation(context),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(_getActionLabel()),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
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

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return AppColors.alertError;
      case AlertSeverity.warning:
        return AppColors.alertWarning;
      case AlertSeverity.info:
        return AppColors.primary;
    }
  }

  IconData _getSeverityIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Icons.error;
      case AlertSeverity.warning:
        return Icons.warning_amber;
      case AlertSeverity.info:
        return Icons.info_outline;
    }
  }

  String _getActionLabel() {
    if (alert.category == AlertCategory.irrigation || alert.source.type == AlertSourceType.centralIrrigation) {
      return 'Open Manual Control';
    }
    final eventType = alert.metadata?['eventType']?.toString() ?? '';
    if (eventType.contains('SENSOR') || eventType.contains('TELEMETRY')) {
      return 'Open ESP32 Telemetry Stream';
    }
    if (alert.category == AlertCategory.hardware || alert.category == AlertCategory.connectivity) {
      return 'Open Device Diagnostics';
    }
    return 'View Field Details';
  }

  void _handleActionNavigation(BuildContext context) {
    if (alert.category == AlertCategory.irrigation || alert.source.type == AlertSourceType.centralIrrigation) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const ManualControlScreen()),
      );
      return;
    }
    final eventType = alert.metadata?['eventType']?.toString() ?? '';
    if (eventType.contains('SENSOR') || eventType.contains('TELEMETRY')) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const TelemetryStreamScreen()),
      );
      return;
    }
    if (alert.category == AlertCategory.hardware || alert.category == AlertCategory.connectivity) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const DeviceDiagnosticsScreen()),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  String _formatTimestamp(DateTime dt) {
    final date = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }
}
