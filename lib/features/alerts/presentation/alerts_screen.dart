import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/models/models.dart';
import 'alert_detail_screen.dart';
import 'providers/alert_provider.dart';

class AlertsScreen extends StatefulWidget {
  final AlertNotifier? notifier;

  const AlertsScreen({super.key, this.notifier});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late AlertNotifier _notifier;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notifier = widget.notifier ?? AlertNotifier();
    _notifier.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.notifier == null) {
      _notifier.dispose();
    } else {
      _notifier.removeListener(_onStateChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _notifier.state;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('System Alerts'),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.alertError,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.unreadCount} NEW',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (state.alerts.any((a) => !a.isRead))
            TextButton.icon(
              onPressed: () => _notifier.markAllAsRead(),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark All Read'),
            ),
        ],
      ),
      body: ResponsiveContainer(
        child: RefreshIndicator(
          onRefresh: () => _notifier.fetchAlerts(),
          child: Column(
            children: [
              // Search & Filters Header
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search alerts, sources, or descriptions...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _notifier.setSearchQuery('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                      onChanged: (val) => _notifier.setSearchQuery(val),
                    ),
                    const SizedBox(height: AppDimensions.spaceSm),

                    // Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: state.severityFilter == null &&
                                state.categoryFilter == null &&
                                !state.unreadOnly,
                            onSelected: (_) {
                              _notifier.setSeverityFilter(null);
                              _notifier.setCategoryFilter(null);
                              _notifier.toggleUnreadFilter(false);
                            },
                          ),
                          const SizedBox(width: 6),
                          FilterChip(
                            label: const Text('Unread Only'),
                            selected: state.unreadOnly,
                            onSelected: (selected) => _notifier.toggleUnreadFilter(selected),
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Critical'),
                            selected: state.severityFilter == AlertSeverity.critical,
                            selectedColor: AppColors.alertError.withValues(alpha: 0.2),
                            onSelected: (selected) {
                              _notifier.setSeverityFilter(selected ? AlertSeverity.critical : null);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Warning'),
                            selected: state.severityFilter == AlertSeverity.warning,
                            selectedColor: AppColors.alertWarning.withValues(alpha: 0.2),
                            onSelected: (selected) {
                              _notifier.setSeverityFilter(selected ? AlertSeverity.warning : null);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Info'),
                            selected: state.severityFilter == AlertSeverity.info,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            onSelected: (selected) {
                              _notifier.setSeverityFilter(selected ? AlertSeverity.info : null);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Hardware'),
                            selected: state.categoryFilter == AlertCategory.hardware,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            onSelected: (selected) {
                              _notifier.setCategoryFilter(selected ? AlertCategory.hardware : null);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Irrigation'),
                            selected: state.categoryFilter == AlertCategory.irrigation,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            onSelected: (selected) {
                              _notifier.setCategoryFilter(selected ? AlertCategory.irrigation : null);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Agronomic'),
                            selected: state.categoryFilter == AlertCategory.agronomic,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            onSelected: (selected) {
                              _notifier.setCategoryFilter(selected ? AlertCategory.agronomic : null);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Connectivity'),
                            selected: state.categoryFilter == AlertCategory.connectivity,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            onSelected: (selected) {
                              _notifier.setCategoryFilter(selected ? AlertCategory.connectivity : null);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Alert List Content
              Expanded(
                child: _buildAlertListContent(state, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertListContent(AlertStateData state, ThemeData theme) {
    if (state.isLoading && state.alerts.isEmpty) {
      return const LoadingStateWidget(message: 'Loading system alerts...');
    }

    if (state.errorMessage != null) {
      return ErrorStateWidget(
        message: state.errorMessage!,
        onRetry: () => _notifier.fetchAlerts(),
      );
    }

    final filtered = state.filteredAlerts;

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
              const SizedBox(height: AppDimensions.spaceMd),
              Text(
                'No System Alerts',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                state.searchQuery.isNotEmpty || state.severityFilter != null || state.unreadOnly
                    ? 'No alerts match your active filter criteria.'
                    : 'All field monitoring zones and centralized irrigation hardware are operating normally.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final alert = filtered[index];
        return _buildAlertCard(alert, theme);
      },
    );
  }

  Widget _buildAlertCard(SystemAlert alert, ThemeData theme) {
    final severityColor = _getSeverityColor(alert.severity);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      child: AquaCard(
        child: InkWell(
          onTap: () async {
            if (!alert.isRead) {
              await _notifier.markAsRead(alert.id);
            }
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AlertDetailScreen(
                    alert: alert,
                    onMarkAsRead: () => _notifier.markAsRead(alert.id),
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unread indicator dot & Severity Icon
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getSeverityIcon(alert.severity),
                    color: severityColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSm),

                // Main Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              alert.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: alert.isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!alert.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.alertError,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.description,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                alert.source.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatRelativeTime(alert.timestamp),
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
