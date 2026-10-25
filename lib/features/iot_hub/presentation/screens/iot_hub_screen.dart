import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/realtime/realtime_coordinator.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/domain/models/user_role.dart';
import '../../../telemetry_stream/domain/models/telemetry_stream_event.dart';
import '../../../telemetry_stream/presentation/providers/telemetry_stream_notifier.dart';
import '../../../telemetry_stream/presentation/widgets/telemetry_stream_event_card.dart';
import '../../../telemetry_stream/presentation/widgets/telemetry_stream_summary_card.dart';
import '../../../diagnostics/presentation/providers/diagnostics_provider.dart';
import '../../../diagnostics/presentation/widgets/device_detail_dialog.dart';
import '../../../diagnostics/domain/models/models.dart';

/// Dedicated IoT Hub Screen for ArvaLink.
///
/// Unifies real-time telemetry streaming, device registry management,
/// telemetry exploration, and event diagnostics into one cohesive interface.
///
/// Architecturally equivalent to AWS IoT Core Console (Device Registry + Telemetry Shadow + Message Routing + Rules/Events),
/// but fully powered by ArvaCore's self-hosted Spring Boot & PostgreSQL IoT platform.
class IotHubScreen extends StatefulWidget {
  final RealtimeCoordinator? realtimeCoordinator;
  final DiagnosticsNotifier? diagnosticsNotifier;
  final UserRole userRole;

  const IotHubScreen({
    super.key,
    this.realtimeCoordinator,
    this.diagnosticsNotifier,
    this.userRole = UserRole.operator,
  });

  @override
  State<IotHubScreen> createState() => _IotHubScreenState();
}

class _IotHubScreenState extends State<IotHubScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TelemetryStreamNotifier _telemetryNotifier;
  late final DiagnosticsNotifier _diagnosticsNotifier;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedDeviceFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _telemetryNotifier = TelemetryStreamNotifier(
      realtimeCoordinator: widget.realtimeCoordinator,
    );
    _diagnosticsNotifier = widget.diagnosticsNotifier ?? DiagnosticsNotifier();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _telemetryNotifier.dispose();
    if (widget.diagnosticsNotifier == null) {
      _diagnosticsNotifier.dispose();
    }
    super.dispose();
  }

  bool get _canManageDevices =>
      widget.userRole == UserRole.operator || widget.userRole == UserRole.admin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_telemetryNotifier, _diagnosticsNotifier]),
      builder: (context, _) {
        final diagState = _diagnosticsNotifier.state;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hub_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'IoT Hub',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              // Pause / Resume Stream Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: _telemetryNotifier.isPaused
                        ? AppColors.zoneLow.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.12),
                    foregroundColor: _telemetryNotifier.isPaused ? AppColors.zoneLow : AppColors.primary,
                  ),
                  onPressed: _telemetryNotifier.togglePause,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _telemetryNotifier.isPaused ? Icons.play_arrow : Icons.pause,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _telemetryNotifier.isPaused ? 'Resume' : 'Pause',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Manual Refresh
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Pipeline',
                onPressed: () {
                  _telemetryNotifier.refresh();
                  _diagnosticsNotifier.fetchDiagnostics();
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
                Tab(icon: Icon(Icons.devices_other_outlined, size: 18), text: 'Registry'),
                Tab(icon: Icon(Icons.insights_outlined, size: 18), text: 'Telemetry'),
                Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Events & Logs'),
              ],
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(theme, diagState),
                _buildRegistryTab(theme, diagState),
                _buildTelemetryExplorerTab(theme),
                _buildEventsAndDiagnosticsTab(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // Tab 1: Operational Overview
  // =========================================================================
  Widget _buildOverviewTab(ThemeData theme, DiagnosticsStateData diagState) {
    final summary = _telemetryNotifier.summary;
    final devices = diagState.devices;

    final onlineCount = devices.where((d) => d.isOnline).length;
    final staleCount = devices.where((d) => d.healthStatus == DeviceHealthStatus.stale).length;
    final offlineCount = devices.where((d) => !d.isOnline).length;
    final totalCount = devices.length;

    return RefreshIndicator(
      onRefresh: () async {
        _telemetryNotifier.refresh();
        await _diagnosticsNotifier.fetchDiagnostics();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ArvaCore IoT Pipeline',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Ingestion, telemetry validation, and device state management',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'PIPELINE HEALTHY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceMd),

            // Ingestion Summary Card
            TelemetryStreamSummaryCard(
              summary: summary,
              isRealtimeConnected: true,
              connectionState: RealtimeConnectionState.connected,
            ),

            const SizedBox(height: AppDimensions.spaceMd),

            // Device Fleet Health Metrics
            Text(
              'ArvaNode Fleet Connectivity',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppDimensions.spaceSm),

            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Total Nodes',
                    value: '$totalCount',
                    icon: Icons.devices,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Online',
                    value: '$onlineCount',
                    icon: Icons.wifi,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Stale / Delayed',
                    value: '$staleCount',
                    icon: Icons.timelapse,
                    color: AppColors.alertWarning,
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Offline',
                    value: '$offlineCount',
                    icon: Icons.wifi_off,
                    color: AppColors.alertError,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.spaceLg),

            // Quick Navigation shortcuts to Registry & Stream
            AquaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational Actions',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Explore Telemetry Stream'),
                        onPressed: () => _tabController.animateTo(2),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.devices_other, size: 16),
                        label: const Text('Manage Device Registry'),
                        onPressed: () => _tabController.animateTo(1),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('Audit Event Logs'),
                        onPressed: () => _tabController.animateTo(3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Tab 2: Device Registry
  // =========================================================================
  Widget _buildRegistryTab(ThemeData theme, DiagnosticsStateData diagState) {
    var devices = diagState.devices;

    if (_searchQuery.isNotEmpty) {
      devices = devices.where((d) {
        return d.id.toLowerCase().contains(_searchQuery) ||
            d.name.toLowerCase().contains(_searchQuery) ||
            d.targetScope.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    return Column(
      children: [
        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Node ID, Zone (e.g. ARVANODE-001, Q1)...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
          ),
        ),

        // Node List View
        Expanded(
          child: diagState.isLoading && devices.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.devices_other, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: AppDimensions.spaceSm),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No nodes matching "$_searchQuery"'
                                : 'No registered ArvaNodes found in registry.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final node = devices[index];
                        return _buildDeviceRegistryCard(theme, node);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDeviceRegistryCard(ThemeData theme, DeviceDiagnostic node) {
    final isOnline = node.isOnline;
    final isStale = node.healthStatus == DeviceHealthStatus.stale;

    Color badgeColor = AppColors.success;
    String badgeText = isOnline ? 'ONLINE' : 'OFFLINE';
    if (isStale) {
      badgeColor = AppColors.alertWarning;
      badgeText = 'STALE';
    } else if (!isOnline) {
      badgeColor = AppColors.alertError;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      child: AquaCard(
        child: InkWell(
          onTap: () => DeviceDetailDialog.show(context, node),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.router_outlined,
                        color: badgeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            node.id,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Scope: ${node.targetScope} • Category: ${node.category.name}',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge.deviceStatus(badgeText, compact: true),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                const Divider(height: 1),
                const SizedBox(height: AppDimensions.spaceSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Last Seen: ${node.lastSeen.toLocal().toString().split('.').first}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    if (_canManageDevices)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.settings, size: 14),
                        label: const Text('Manage', style: TextStyle(fontSize: 12)),
                        onPressed: () => DeviceDetailDialog.show(context, node),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Tab 3: Telemetry Explorer
  // =========================================================================
  Widget _buildTelemetryExplorerTab(ThemeData theme) {
    List<TelemetryStreamEvent> events = _telemetryNotifier.events;

    if (_selectedDeviceFilter != null && _selectedDeviceFilter!.isNotEmpty) {
      events = events.where((e) => e.nodeId == _selectedDeviceFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      events = events.where((e) {
        return e.nodeId.toLowerCase().contains(_searchQuery) ||
            e.eventType.toLowerCase().contains(_searchQuery) ||
            (e.zoneCode ?? '').toLowerCase().contains(_searchQuery);
      }).toList();
    }

    return Column(
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd, vertical: AppDimensions.spaceSm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Live Ingestion Stream (${events.length} captured)',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              // Device Filter Chip
              if (_selectedDeviceFilter != null) ...[
                InputChip(
                  label: Text('Node: $_selectedDeviceFilter'),
                  onDeleted: () {
                    setState(() => _selectedDeviceFilter = null);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),

        // Event Stream Feed
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stream_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: AppDimensions.spaceSm),
                      Text(
                        'No telemetry messages in stream cache.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Telemetry events appear in real-time as ArvaNodes transmit over MQTT / LoRaWAN.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return TelemetryStreamEventCard(
                      event: event,
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // Tab 4: Event & Diagnostics Log View
  // =========================================================================
  Widget _buildEventsAndDiagnosticsTab(ThemeData theme) {
    final events = _telemetryNotifier.events;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IoT Diagnostics & Connection Log',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Audit log of device connections, telemetry validation, and transport health.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // Diagnostic Health Summary Card
          AquaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MQTT & Backend Ingestion Status', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    StatusBadge.deviceStatus('ACTIVE', compact: true),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  '• Transport Ingestion: MQTT Port 1883 / 8883 (QoS 1 Ack)\n'
                  '• Database Persistence: PostgreSQL (telemetry_readings & telemetry_stream_events)\n'
                  '• Replay & Deduplication: Enabled (MessageId & Sequence cache)\n'
                  '• Actuator Isolation: Enforced (Telemetry tools are strictly read-only)',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.spaceMd),

          Text(
            'Recent Ingestion Events',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppDimensions.spaceSm),

          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No recent events recorded.')),
            )
          else
            ...events.take(15).map((e) => _buildDiagnosticEventRow(theme, e)),
        ],
      ),
    );
  }

  Widget _buildDiagnosticEventRow(ThemeData theme, TelemetryStreamEvent event) {
    final isProcessed = event.status == TelemetryStreamStatus.processed;
    final statusColor = isProcessed ? AppColors.success : AppColors.alertError;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isProcessed ? Icons.check_circle_outline : Icons.error_outline,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.nodeId} • ${event.eventType}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  'Soil: ${event.soilMoisturePercent?.toStringAsFixed(1) ?? "--"}% | Depth: ${event.waterLevelCm?.toStringAsFixed(1) ?? "--"} cm',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${event.receivedAt.hour.toString().padLeft(2, '0')}:${event.receivedAt.minute.toString().padLeft(2, '0')}:${event.receivedAt.second.toString().padLeft(2, '0')}',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

