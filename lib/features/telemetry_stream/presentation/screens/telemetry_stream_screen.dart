import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/realtime/realtime_coordinator.dart';
import '../providers/telemetry_stream_notifier.dart';
import '../widgets/telemetry_stream_event_card.dart';
import '../widgets/telemetry_stream_summary_card.dart';

class TelemetryStreamScreen extends StatefulWidget {
  final RealtimeCoordinator? realtimeCoordinator;

  const TelemetryStreamScreen({
    super.key,
    this.realtimeCoordinator,
  });

  @override
  State<TelemetryStreamScreen> createState() => _TelemetryStreamScreenState();
}

class _TelemetryStreamScreenState extends State<TelemetryStreamScreen> {
  late final TelemetryStreamNotifier _notifier;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notifier = TelemetryStreamNotifier(
      realtimeCoordinator: widget.realtimeCoordinator,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _notifier,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stream, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'ESP32 Telemetry',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              // Pause / Resume Toggle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: _notifier.isPaused
                        ? AppColors.zoneLow.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.12),
                    foregroundColor: _notifier.isPaused ? AppColors.zoneLow : AppColors.primary,
                  ),
                  onPressed: _notifier.togglePause,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _notifier.isPaused ? Icons.play_arrow : Icons.pause,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _notifier.isPaused ? 'Resume' : 'Pause',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      if (_notifier.isPaused && _notifier.pausedCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.zoneLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${_notifier.pausedCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Feed',
                onPressed: _notifier.refresh,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _notifier.refresh,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary Card
                TelemetryStreamSummaryCard(
                  summary: _notifier.summary,
                  isRealtimeConnected: _notifier.isRealtimeConnected,
                  connectionState: _notifier.connectionState,
                ),
                const SizedBox(height: 16),

                // Controls & Filter Bar
                _buildFilterBar(context, isDark),
                const SizedBox(height: 16),

                // Stream Header Title
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Live Ingestion Feed (${_notifier.events.length} shown)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    if (_notifier.isPaused)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.zoneLow.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.zoneLow.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause, size: 12, color: AppColors.zoneLow),
                            const SizedBox(width: 4),
                            Text(
                              'Visual Stream Paused (${_notifier.pausedCount} queued)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.zoneLow,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Feed List
                if (_notifier.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_notifier.events.isEmpty)
                  _buildEmptyState(context, isDark)
                else ...[
                  ..._notifier.events.map((event) => TelemetryStreamEventCard(
                        key: ValueKey(event.eventId),
                        event: event,
                      )),
                  if (_notifier.hasMore) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: _notifier.isLoadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton.icon(
                              onPressed: _notifier.loadMore,
                              icon: const Icon(Icons.arrow_downward, size: 16),
                              label: const Text('Load Older Transmissions'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                    ),
                  ],
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final hasActiveFilter = _notifier.selectedNodeId != null ||
        _notifier.selectedStatus != null ||
        _notifier.searchQuery.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field & Node Filter Row
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 280;
              final searchWidget = TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search node, zone, event...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
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
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                onChanged: (val) => _notifier.setSearchQuery(val),
              );

              final dropdownWidget = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _notifier.selectedNodeId,
                    hint: const Text('All Nodes', style: TextStyle(fontSize: 13)),
                    isDense: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Nodes', style: TextStyle(fontSize: 13)),
                      ),
                      ..._notifier.availableNodeIds.map(
                        (nodeId) => DropdownMenuItem<String?>(
                          value: nodeId,
                          child: Text(nodeId, style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                    onChanged: (val) => _notifier.setNodeFilter(val),
                  ),
                ),
              );

              if (isVeryNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchWidget,
                    const SizedBox(height: 8),
                    dropdownWidget,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchWidget),
                  const SizedBox(width: 8),
                  dropdownWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Status Filter Chips Row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Status: ',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              _buildStatusFilterChip(null, 'ALL'),
              _buildStatusFilterChip('PROCESSED', 'Processed'),
              _buildStatusFilterChip('PARTIALLY_PROCESSED', 'Partial'),
              _buildStatusFilterChip('REJECTED', 'Rejected'),
              _buildStatusFilterChip('FAILED', 'Failed'),
              if (hasActiveFilter)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _notifier.clearFilters();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Clear Filters',
                    style: TextStyle(fontSize: 12, color: AppColors.zoneCritical),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String? statusValue, String label) {
    final isSelected = _notifier.selectedStatus == statusValue;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : null,
        ),
      ),
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      onSelected: (_) => _notifier.setStatusFilter(statusValue),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.sensors_off,
              size: 56,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'No Telemetry Transmissions Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Waiting for ESP32 nodes to transmit telemetry, or no events match current filters.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_notifier.selectedNodeId != null ||
                _notifier.selectedStatus != null ||
                _notifier.searchQuery.isNotEmpty)
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  _notifier.clearFilters();
                },
                child: const Text('Reset Active Filters'),
              ),
          ],
        ),
      ),
    );
  }
}

