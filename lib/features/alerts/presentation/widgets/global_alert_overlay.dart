import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/models.dart';
import '../alert_detail_screen.dart';
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

class _GlobalAlertOverlayState extends State<GlobalAlertOverlay>
    with SingleTickerProviderStateMixin {
  final Set<String> _seenAlertIds = <String>{};
  final List<SystemAlert> _bannerQueue = <SystemAlert>[];
  SystemAlert? _currentAlert;
  Timer? _dismissTimer;
  bool _initialized = false;

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    widget.notifier.addListener(_handleAlertsChanged);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    widget.notifier.removeListener(_handleAlertsChanged);
    super.dispose();
  }

  void _handleAlertsChanged() {
    final alerts = widget.notifier.state.alerts;

    // On initial mount/fetch, mark existing alerts as seen so old history isn't replayed
    if (!_initialized) {
      if (alerts.isNotEmpty) {
        for (final alert in alerts) {
          _seenAlertIds.add(alert.id);
        }
        _initialized = true;
      }
      return;
    }

    // Inspect newly arrived alerts
    for (final alert in alerts) {
      if (!_seenAlertIds.contains(alert.id)) {
        _seenAlertIds.add(alert.id);
        if (!alert.isRead) {
          _bannerQueue.add(alert);
        }
      }
    }

    if (_currentAlert == null && _bannerQueue.isNotEmpty) {
      _showNextBanner();
    }
  }

  void _showNextBanner() {
    if (!mounted) return;
    if (_bannerQueue.isEmpty) {
      setState(() => _currentAlert = null);
      return;
    }

    final next = _bannerQueue.removeAt(0);
    setState(() {
      _currentAlert = next;
    });

    _animController.forward(from: 0.0);

    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 5), () {
      _dismissCurrentBanner();
    });
  }

  void _dismissCurrentBanner() {
    _dismissTimer?.cancel();
    if (!mounted || _currentAlert == null) return;

    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentAlert = null;
        });
        _showNextBanner();
      }
    });
  }

  Color _severityColor(AlertSeverity severity, String title) {
    if (title.toUpperCase().contains('SUCCESS') ||
        title.toUpperCase().contains('COMPLETED') ||
        title.toUpperCase().contains('ACKNOWLEDGED')) {
      return const Color(0xFF16A34A); // Green / Success
    }
    switch (severity) {
      case AlertSeverity.critical:
        return const Color(0xFFDC2626); // Red / Critical
      case AlertSeverity.warning:
        return const Color(0xFFD97706); // Amber / Warning
      case AlertSeverity.info:
        return const Color(0xFF2563EB); // Blue / Info
    }
  }

  IconData _severityIcon(AlertSeverity severity, String title) {
    if (title.toUpperCase().contains('SUCCESS') ||
        title.toUpperCase().contains('COMPLETED') ||
        title.toUpperCase().contains('ACKNOWLEDGED')) {
      return Icons.check_circle_outline;
    }
    switch (severity) {
      case AlertSeverity.critical:
        return Icons.error_outline;
      case AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case AlertSeverity.info:
        return Icons.info_outline;
    }
  }

  String _severityLabel(AlertSeverity severity, String title) {
    if (title.toUpperCase().contains('SUCCESS') ||
        title.toUpperCase().contains('COMPLETED') ||
        title.toUpperCase().contains('ACKNOWLEDGED')) {
      return 'SUCCESS';
    }
    return severity.name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentAlert != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(10),
                  color: _severityColor(_currentAlert!.severity, _currentAlert!.title),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      final alert = _currentAlert;
                      _dismissCurrentBanner();
                      if (alert != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AlertDetailScreen(
                              alert: alert,
                              onMarkAsRead: () => widget.notifier.markAsRead(alert.id),
                            ),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            _severityIcon(_currentAlert!.severity, _currentAlert!.title),
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
                                      _severityLabel(_currentAlert!.severity, _currentAlert!.title),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        "• ${_currentAlert!.source.name}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentAlert!.title,
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
                                  _currentAlert!.description,
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
                            tooltip: 'Dismiss',
                            onPressed: _dismissCurrentBanner,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
