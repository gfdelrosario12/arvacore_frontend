import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/aqua_card.dart';
import '../../../core/widgets/aqua_chart_container.dart';
import '../../../core/widgets/aqua_chip_selector.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_state_widget.dart';
import '../../../core/widgets/responsive_container.dart';
import '../../../core/widgets/sensor_metric_tile.dart';
import '../../../core/widgets/simulated_telemetry_chart.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/datasources/zone_data_source.dart';
import '../data/repositories/zone_repository.dart';
import '../domain/models/monitoring_zone.dart';

enum TimeframeFilter { tf24h, tf7d }

class ZoneAnalysisScreen extends StatefulWidget {
  final String zoneCode;
  final MonitoringZone? initialZone;
  final ZoneRepository? repository;
  final ZoneMockState mockState;

  const ZoneAnalysisScreen({
    super.key,
    required this.zoneCode,
    this.initialZone,
    this.repository,
    this.mockState = ZoneMockState.normal,
  });

  @override
  State<ZoneAnalysisScreen> createState() => _ZoneAnalysisScreenState();
}

class _ZoneAnalysisScreenState extends State<ZoneAnalysisScreen> {
  late final ZoneRepository _repository;
  MonitoringZone? _zone;
  bool _isLoading = true;
  String? _errorMessage;
  TimeframeFilter _selectedTimeframe = TimeframeFilter.tf24h;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ZoneRepositoryImpl();
    if (widget.initialZone != null) {
      _zone = widget.initialZone;
      _isLoading = false;
    } else {
      _loadZoneDetails();
    }
  }

  Future<void> _loadZoneDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final zone = await _repository.fetchZoneDetails(
        widget.zoneCode,
        mockState: widget.mockState,
      );
      if (mounted) {
        setState(() {
          _zone = zone;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.zoneCode} Detailed Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadZoneDetails,
            tooltip: 'Refresh Telemetry',
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const LoadingStateWidget(
        message: 'Fetching quadrant telemetry & history...',
      );
    }

    if (_errorMessage != null) {
      return ErrorStateWidget(
        title: 'Telemetry Gateway Error',
        message: _errorMessage!,
        onRetry: _loadZoneDetails,
      );
    }

    if (_zone == null) {
      return EmptyStateWidget(
        title: 'Quadrant Not Found',
        message: 'No monitoring data available for zone ${widget.zoneCode}.',
        onAction: _loadZoneDetails,
        actionLabel: 'Reload Telemetry',
      );
    }

    final zone = _zone!;
    final history = _selectedTimeframe == TimeframeFilter.tf24h
        ? zone.waterLevelHistory24h
        : zone.waterLevelHistory7d;
    final trend = zone.trendAnalysisFor(history);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zone Overview Header Card
            _buildHeaderCard(theme, zone),
            const SizedBox(height: AppDimensions.spaceMd),

            // Trend Analysis Summary Card
            _buildTrendSummaryCard(theme, trend),
            const SizedBox(height: AppDimensions.spaceMd),

            // Real-Time Sensor Metrics Grid
            _buildMetricsGrid(theme, zone),
            const SizedBox(height: AppDimensions.spaceMd),

            // Historical Telemetry Chart with Timeframe Selector
            _buildHistoricalChartSection(theme, zone, history),
            const SizedBox(height: AppDimensions.spaceMd),

            // LoRaWAN Hardware & Sensor Diagnostic Panel
            _buildDiagnosticPanel(theme, zone),
            const SizedBox(height: AppDimensions.spaceLg),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, MonitoringZone zone) {
    return AquaCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      zone.code,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    StatusBadge.zoneStatus(zone.status.name),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  zone.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildFreshnessBadge(zone),
                    _buildReliabilityBadge(zone),
                  ],
                ),
              ],
            ),
          ),
          StatusBadge.deviceStatus(zone.isOnline ? 'Online' : 'Offline'),
        ],
      ),
    );
  }

  Widget _buildTrendSummaryCard(ThemeData theme, ZoneTrendAnalysis trend) {
    Color badgeColor;
    IconData trendIcon;
    String trendDescription;

    switch (trend.direction) {
      case TrendDirection.rising:
        badgeColor = AppColors.info;
        trendIcon = Icons.trending_up;
        trendDescription =
            'Water depth is rising over the selected time window. Irrigation or inflow is increasing water depth in this zone.';
        break;
      case TrendDirection.falling:
        badgeColor = AppColors.warning;
        trendIcon = Icons.trending_down;
        trendDescription =
            'Water depth is falling over the selected time window. Soil drainage and crop evapotranspiration are depleting available water.';
        break;
      case TrendDirection.stable:
        badgeColor = AppColors.primary;
        trendIcon = Icons.trending_flat;
        trendDescription =
            'Water depth is stable with minimal fluctuation over the selected time window.';
        break;
    }

    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Water Condition Trend Analysis',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceSm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, size: 16, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      trend.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Text(
            trendDescription,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme, MonitoringZone zone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Telemetry Readings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        Row(
          children: [
            Expanded(
              child: SensorMetricTile(
                label: 'Soil Moisture',
                value: '${zone.soilMoisturePercent.toStringAsFixed(1)}%',
                icon: Icons.water_drop,
                color: AppColors.primary,
              ),
            ),
            Expanded(
              child: SensorMetricTile(
                label: 'Water Depth',
                value: '${zone.waterLevelCm} cm',
                icon: Icons.waves,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        Row(
          children: [
            Expanded(
              child: SensorMetricTile(
                label: 'Battery',
                value: '${zone.batteryPercent}%',
                icon: Icons.battery_charging_full,
                color: AppColors.primaryLight,
              ),
            ),
            Expanded(
              child: SensorMetricTile(
                label: 'Signal',
                value: '${zone.rssiDbm} dBm',
                icon: Icons.cell_tower,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHistoricalChartSection(
    ThemeData theme,
    MonitoringZone zone,
    List<double> history,
  ) {
    final timeframeLabel =
        _selectedTimeframe == TimeframeFilter.tf24h ? '24-Hour' : '7-Day';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historical Water Level',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        AquaChipSelector<TimeframeFilter>(
          options: const [
            AquaChipOption(value: TimeframeFilter.tf24h, label: '24h Trend'),
            AquaChipOption(value: TimeframeFilter.tf7d, label: '7d History'),
          ],
          selectedValue: _selectedTimeframe,
          onSelected: (tf) {
            setState(() {
              _selectedTimeframe = tf;
            });
          },
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        AquaChartContainer(
          title: '${zone.code} Water Depth ($timeframeLabel)',
          subtitle:
              'Water depth readings over ${_selectedTimeframe == TimeframeFilter.tf24h ? 'hourly interval' : '7-day daily average'}',
          chartWidget: SimulatedTelemetryChart(
            dataPoints: history,
            labelSuffix: 'cm',
            lineColor: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticPanel(ThemeData theme, MonitoringZone zone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sensor Node Hardware Diagnostics',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        AquaCard(
          padding: const EdgeInsets.all(AppDimensions.spaceSm),
          child: Column(
            children: [
              _buildDiagnosticRow(
                theme,
                label: 'Uplink Status',
                value: zone.isOnline ? 'ONLINE (LoRaWAN)' : 'OFFLINE',
                valueColor: zone.isOnline ? AppColors.success : AppColors.error,
                icon: zone.isOnline ? Icons.sensors : Icons.sensors_off,
              ),
              const Divider(height: 12),
              _buildDiagnosticRow(
                theme,
                label: 'Signal Strength (RSSI)',
                value: '${zone.rssiDbm} dBm',
                icon: Icons.cell_tower,
              ),
              const Divider(height: 12),
              _buildDiagnosticRow(
                theme,
                label: 'Signal-to-Noise Ratio (SNR)',
                value: '${zone.snrDb} dB',
                icon: Icons.graphic_eq,
              ),
              const Divider(height: 12),
              _buildDiagnosticRow(
                theme,
                label: 'Battery Health',
                value: '${zone.batteryPercent}%',
                valueColor: zone.batteryPercent < 20 ? AppColors.error : null,
                icon: zone.batteryPercent < 20
                    ? Icons.battery_alert
                    : Icons.battery_full,
              ),
              const Divider(height: 12),
              _buildDiagnosticRow(
                theme,
                label: 'Hardware Model',
                value: zone.hardwareModel,
                icon: Icons.memory,
              ),
              const Divider(height: 12),
              _buildDiagnosticRow(
                theme,
                label: 'Firmware Version',
                value: zone.firmwareVersion,
                icon: Icons.developer_board,
              ),
              const Divider(height: 12),
              _buildDiagnosticRow(
                theme,
                label: 'Last Sensor Ping',
                value: _formatFullTime(zone.lastUpdated),
                icon: Icons.access_time,
              ),
              const Divider(height: 12),
              _buildDiagnosticRow(
                theme,
                label: 'Telemetry Quality',
                value: (zone.waterLevelCm < -30.0 || zone.waterLevelCm > 30.0)
                    ? 'Out of Bounds (Invalid)'
                    : (!zone.isOnline ? 'Node Offline' : 'Reliable Telemetry'),
                valueColor: (zone.waterLevelCm < -30.0 || zone.waterLevelCm > 30.0)
                    ? AppColors.error
                    : (!zone.isOnline ? AppColors.zoneOffline : AppColors.success),
                icon: Icons.verified_outlined,
              ),
              const Divider(height: 12),
              _buildDiagnosticRow(
                theme,
                label: 'Telemetry Freshness',
                value: DateTime.now().difference(zone.lastUpdated).inMinutes >= 15
                    ? 'Stale (${DateTime.now().difference(zone.lastUpdated).inMinutes}m ago)'
                    : 'Fresh (${DateTime.now().difference(zone.lastUpdated).inMinutes}m ago)',
                valueColor: DateTime.now().difference(zone.lastUpdated).inMinutes >= 15
                    ? AppColors.warning
                    : AppColors.success,
                icon: Icons.history,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticRow(
    ThemeData theme, {
    required String label,
    required String value,
    Color? valueColor,
    required IconData icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppDimensions.spaceSm),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spaceSm),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatFullTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildFreshnessBadge(MonitoringZone zone) {
    final ageMinutes = DateTime.now().difference(zone.lastUpdated).inMinutes.clamp(0, 99999);
    final isStale = ageMinutes >= 15;
    final color = isStale ? AppColors.warning : AppColors.success;
    final icon = isStale ? Icons.history : Icons.check_circle_outline;
    final text = isStale ? 'Stale (${ageMinutes}m ago)' : 'Fresh (${ageMinutes}m ago)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReliabilityBadge(MonitoringZone zone) {
    final isOutOfBounds = zone.waterLevelCm < -30.0 || zone.waterLevelCm > 30.0;
    final ageMinutes = DateTime.now().difference(zone.lastUpdated).inMinutes;
    final isStale = ageMinutes >= 15;

    final Color color;
    final IconData icon;
    final String label;

    if (isOutOfBounds) {
      color = AppColors.error;
      icon = Icons.cancel_outlined;
      label = 'Out of Range';
    } else if (!zone.isOnline) {
      color = AppColors.zoneOffline;
      icon = Icons.sensors_off;
      label = 'Station Offline';
    } else if (isStale) {
      color = AppColors.warning;
      icon = Icons.warning_amber_outlined;
      label = 'Degraded Telemetry';
    } else {
      color = AppColors.primary;
      icon = Icons.verified_user_outlined;
      label = 'Valid Telemetry';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
