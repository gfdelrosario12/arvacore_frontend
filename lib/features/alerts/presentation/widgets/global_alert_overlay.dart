import 'package:flutter/material.dart';
import '../../domain/models/models.dart';
import '../providers/alert_provider.dart';

class GlobalAlertOverlay extends StatefulWidget {
  final AlertNotifier notifier;
  final Widget child;

  const GlobalAlertOverlay({
    super.key,
    required this.notifier,
    required this.child,
  });

  @override
  State<GlobalAlertOverlay> createState() => _GlobalAlertOverlayState();
}

class _GlobalAlertOverlayState extends State<GlobalAlertOverlay> {
  final Set<String> _dismissedAlertIds = <String>{};

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_handleAlertsChanged);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_handleAlertsChanged);
    super.dispose();
  }

  void _handleAlertsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Color _severityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return const Color(0xFFDC2626); // Red
      case AlertSeverity.warning:
        return const Color(0xFFD97706); // Amber
      case AlertSeverity.info:
        return const Color(0xFF2563EB); // Blue
    }
  }

  IconData _severityIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Icons.error;
      case AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case AlertSeverity.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = widget.notifier.state.alerts;
    final unreadAlerts = alerts
        .where((a) => !a.isRead && !_dismissedAlertIds.contains(a.id))
        .toList();

    SystemAlert? topAlert = unreadAlerts.isNotEmpty ? unreadAlerts.first : null;

    return Stack(
      children: [
        widget.child,
        if (topAlert != null)
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(10),
              color: _severityColor(topAlert.severity),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      _severityIcon(topAlert.severity),
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                topAlert.severity.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "• ${topAlert.source.displayName}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            topAlert.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            topAlert.description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      tooltip: topAlert.severity == AlertSeverity.critical
                          ? 'Acknowledge Critical Alert'
                          : 'Dismiss Alert',
                      onPressed: () {
                        setState(() {
                          _dismissedAlertIds.add(topAlert!.id);
                        });
                        widget.notifier.markAlertAsRead(topAlert!.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
