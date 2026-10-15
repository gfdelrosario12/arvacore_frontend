import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/aqua_button.dart';
import '../../../core/widgets/aqua_card.dart';
import '../../../core/widgets/aqua_chart_container.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_state_widget.dart';
import '../../../core/widgets/responsive_container.dart';
import '../../../core/widgets/sensor_metric_tile.dart';
import '../../../core/widgets/simulated_telemetry_chart.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/repositories/awd_repository.dart';
import '../domain/models/awd_analytics_summary.dart';
import '../domain/models/awd_automation_eligibility.dart';
import '../domain/models/awd_confidence.dart';
import '../domain/models/crop_growth_stage.dart';
import '../domain/models/awd_recommendation.dart';
import '../domain/models/awd_threshold_config.dart';

class AwdAnalyticsScreen extends StatefulWidget {
  final AwdRepository? repository;
  final AwdMockState mockState;

  const AwdAnalyticsScreen({
    super.key,
    this.repository,
    this.mockState = AwdMockState.normal,
  });

  @override
  State<AwdAnalyticsScreen> createState() => _AwdAnalyticsScreenState();
}

class _AwdAnalyticsScreenState extends State<AwdAnalyticsScreen> {
  late final AwdRepository _repository;
  AwdAnalyticsSummary? _summary;
  bool _isLoading = true;
  String? _errorMessage;
  AwdMockState _currentMockState = AwdMockState.normal;
  AwdThresholdConfig _activeConfig = const AwdThresholdConfig();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? AwdRepositoryImpl();
    _currentMockState = widget.mockState;
    _loadAnalytics();
  }

  Future<void> _loadAnalytics({AwdMockState? overrideState}) async {
    final stateToFetch = overrideState ?? _currentMockState;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentMockState = stateToFetch;
    });

    try {
      final summary = await _repository.fetchAwdAnalytics(
        config: _activeConfig,
        mockState: stateToFetch,
      );
      if (mounted) {
        setState(() {
          _summary = summary;
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

  void _updateThresholdConfig(AwdThresholdConfig newConfig) {
    setState(() {
      _activeConfig = newConfig;
    });
    _loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveContainer(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ArvaCore AWD Analytics'),
          actions: [
            PopupMenuButton<AwdMockState>(
              icon: const Icon(Icons.tune, color: AppColors.primary),
              tooltip: 'Simulate AWD States',
              onSelected: (AwdMockState state) =>
                  _loadAnalytics(overrideState: state),
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: AwdMockState.normal,
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 18, color: AppColors.success),
                      SizedBox(width: 8),
                      Text('Normal Telemetry'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: AwdMockState.insufficientData,
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber,
                          size: 18, color: AppColors.warning),
                      SizedBox(width: 8),
                      Text('Insufficient Data (<4 Nodes)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: AwdMockState.stale,
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 18, color: AppColors.warning),
                      SizedBox(width: 8),
                      Text('Stale Telemetry'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: AwdMockState.unavailable,
                  child: Row(
                    children: [
                      Icon(Icons.sensors_off, size: 18, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Gateway Offline'),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadAnalytics(),
              tooltip: 'Refresh Analytics',
            ),
          ],
        ),
        body: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const LoadingStateWidget(
        message: 'Aggregating field telemetry & evaluating AWD rules...',
      );
    }

    if (_errorMessage != null) {
      return ErrorStateWidget(
        title: 'AWD Analytics Engine Error',
        message: _errorMessage!,
        onRetry: () => _loadAnalytics(overrideState: AwdMockState.normal),
      );
    }

    if (_summary == null || _summary!.isInsufficientData) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: EmptyStateWidget(
          title: 'Insufficient Telemetry Data',
          message: _summary?.recommendation.rationale ??
              'Active monitoring zone telemetry is required to evaluate field-level AWD recommendations.',
          actionLabel: 'Reset Telemetry Data',
          onAction: () => _loadAnalytics(overrideState: AwdMockState.normal),
        ),
      );
    }

    final summary = _summary!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stale Telemetry Warning Banner
          if (summary.isStaleData) ...[
            _buildStaleBanner(theme),
            const SizedBox(height: AppDimensions.spaceMd),
          ],

          // Disparity / Conflicting Condition Warning Card
          if (summary.hasConflictingConditions) ...[
            _buildDisparityWarningCard(theme, summary),
            const SizedBox(height: AppDimensions.spaceMd),
          ],

          // Outlier Telemetry Notice
          if (summary.flaggedOutlierZoneCodes.isNotEmpty) ...[
            _buildOutlierBanner(theme, summary),
            const SizedBox(height: AppDimensions.spaceMd),
          ],

          // Automated Irrigation Safety Inhibition Warning
          if (summary.autoEligibility != null &&
              !summary.autoEligibility!.isEligibleForAutoIrrigation &&
              summary.autoEligibility!.inhibitionReasons.isNotEmpty) ...[
            _buildAutoInhibitionBanner(theme, summary.autoEligibility!),
            const SizedBox(height: AppDimensions.spaceMd),
          ],

          // Field AWD Status Overview Header
          _buildFieldOverviewCard(theme, summary),
          const SizedBox(height: AppDimensions.spaceMd),

          // Node Autonomous Decision Card
          _buildRecommendationCard(theme, summary),
          const SizedBox(height: AppDimensions.spaceMd),

          // Configurable AWD Threshold Rules Inspector
          _buildThresholdInspectorCard(theme, summary),
          const SizedBox(height: AppDimensions.spaceMd),

          // Quad-Zone Drying & Wetting Rate Comparison
          _buildZoneRatesCard(theme, summary),
          const SizedBox(height: AppDimensions.spaceMd),

          // Field Average Historical Trend Chart
          _buildHistoricalChartSection(theme, summary),
          const SizedBox(height: AppDimensions.spaceLg),
        ],
      ),
    );
  }

  Widget _buildStaleBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: AppColors.warning, size: 20),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Text(
              'Stale Telemetry Notice: Field sensor data was updated over 3 hours ago. Recommendations reflect last known uplink state.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisparityWarningCard(ThemeData theme, AwdAnalyticsSummary summary) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Text(
                  'High Zone Disparity Alert (${summary.waterDepthSpreadCm.toStringAsFixed(1)} cm Spread)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Extreme water depth disparity detected across monitoring zones. Drying zones require water, but other zones remain flooded (+${summary.maxWaterDepthCm.toStringAsFixed(1)} cm). Field inspection is advised before executing centralized pumping to prevent localized over-flooding.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildOutlierBanner(ThemeData theme, AwdAnalyticsSummary summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceSm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_off, color: AppColors.error, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Filtered Outlier Readings: Zones ${summary.flaggedOutlierZoneCodes.join(', ')} reported anomalous readings and were excluded from field averages.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceChip(ThemeData theme, AwdConfidence confidence) {
    Color chipColor;
    switch (confidence.level) {
      case AwdConfidenceLevel.high:
        chipColor = AppColors.success;
        break;
      case AwdConfidenceLevel.medium:
        chipColor = AppColors.warning;
        break;
      case AwdConfidenceLevel.low:
      case AwdConfidenceLevel.insufficient:
        chipColor = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 13, color: chipColor),
          const SizedBox(width: 4),
          Text(
            '${confidence.level.label} (${(confidence.score * 100).toInt()}%)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropStageChip(ThemeData theme, CropGrowthStage stage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grass, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            stage.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoEligibilityChip(
      ThemeData theme, AwdAutomationEligibility eligibility) {
    final isEligible = eligibility.isEligibleForAutoIrrigation;
    final color = isEligible ? AppColors.success : AppColors.alertWarning;
    final icon = isEligible ? Icons.auto_mode : Icons.lock_outline;
    final label = isEligible
        ? 'Auto Eligible (${eligibility.recommendedDurationMinutes}m)'
        : 'Auto Inhibited';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoInhibitionBanner(
      ThemeData theme, AwdAutomationEligibility eligibility) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.alertWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.alertWarning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: AppColors.alertWarning, size: 20),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Text(
                  'Automated Irrigation Inhibited',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.alertWarning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            eligibility.summaryRationale,
            style: theme.textTheme.bodySmall,
          ),
          if (eligibility.inhibitionReasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...eligibility.inhibitionReasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.alertWarning)),
                    Expanded(
                      child: Text(
                        AwdInhibitionReason.toHumanDescription(reason),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.alertWarning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldOverviewCard(ThemeData theme, AwdAnalyticsSummary summary) {
    Color statusColor;
    String statusLabel;

    switch (summary.fieldStatus) {
      case FieldAwdStatus.flooded:
        statusColor = AppColors.awdFlooded;
        statusLabel = 'Flooded (+${summary.averageWaterDepthCm.toStringAsFixed(1)} cm)';
        break;
      case FieldAwdStatus.safeDry:
        statusColor = AppColors.awdSafe;
        statusLabel = 'Safe Drying (${summary.averageWaterDepthCm.toStringAsFixed(1)} cm)';
        break;
      case FieldAwdStatus.refloodNeeded:
        statusColor = AppColors.awdRefluxNeeded;
        statusLabel = 'Reflood Needed (${summary.averageWaterDepthCm.toStringAsFixed(1)} cm)';
        break;
      case FieldAwdStatus.criticalDryness:
        statusColor = AppColors.error;
        statusLabel = 'Critical Dryness (${summary.minWaterDepthCm.toStringAsFixed(1)} cm)';
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
                  'Field-Wide AWD Condition',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceSm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Wrap(
            spacing: AppDimensions.spaceSm,
            runSpacing: 4,
            children: [
              _buildConfidenceChip(theme, summary.confidence),
              _buildCropStageChip(theme, summary.activeThresholdConfig.cropStage),
              if (summary.autoEligibility != null)
                _buildAutoEligibilityChip(theme, summary.autoEligibility!),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${summary.usableReportingZones.length}/${summary.totalNodes} Nodes Usable',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          Row(
            children: [
              Expanded(
                child: SensorMetricTile(
                  label: 'Field Average Depth',
                  value: '${summary.averageWaterDepthCm.toStringAsFixed(1)} cm',
                  icon: Icons.waves,
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Lowest Zone Depth',
                  value: '${summary.minWaterDepthCm.toStringAsFixed(1)} cm',
                  icon: Icons.compress,
                  color: summary.minWaterDepthCm <= summary.activeThresholdConfig.refloodTriggerCm
                      ? AppColors.error
                      : AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Row(
            children: [
              Expanded(
                child: SensorMetricTile(
                  label: 'Highest Zone Depth',
                  value: '${summary.maxWaterDepthCm.toStringAsFixed(1)} cm',
                  icon: Icons.expand,
                  color: AppColors.primaryLight,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Avg Soil Moisture',
                  value: '${summary.averageSoilMoisturePercent.toStringAsFixed(1)}%',
                  icon: Icons.water_drop,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
      ThemeData theme, AwdAnalyticsSummary summary) {
    final rec = summary.recommendation;
    Color actionColor;
    IconData actionIcon;

    switch (rec.action) {
      case IrrigationAction.irrigate:
        actionColor = AppColors.primary;
        actionIcon = Icons.water_drop;
        break;
      case IrrigationAction.doNotIrrigate:
        actionColor = AppColors.success;
        actionIcon = Icons.check_circle_outline;
        break;
      case IrrigationAction.monitor:
        actionColor = AppColors.warning;
        actionIcon = Icons.visibility;
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
                child: Row(
                  children: [
                    Icon(actionIcon, color: actionColor, size: 22),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Text(
                        'Node Autonomous Decision',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge.awdStatus(
                rec.action == IrrigationAction.irrigate
                    ? 'REFLOOD RECOMMENDED'
                    : 'SAFE DRYING ACTIVE',
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            rec.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: actionColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rec.rationale,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Text(
            'Decision Rationale Key Factors:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          ...rec.keyFactors.map(
            (factor) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(factor, style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdInspectorCard(
      ThemeData theme, AwdAnalyticsSummary summary) {
    final cfg = summary.activeThresholdConfig;

    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Configurable AWD Threshold Rules',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Adjust Rules'),
                onPressed: () => _showThresholdEditDialog(theme, cfg),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Thresholds are configurable project parameters provided for field adaptation.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          _buildThresholdRow(
            theme,
            label: 'Crop Growth Stage',
            value: cfg.cropStage.label,
            icon: Icons.grass,
          ),
          const Divider(height: 12),
          _buildThresholdRow(
            theme,
            label: 'Safe Drying Limit',
            value: '${cfg.safeDryThresholdCm.toStringAsFixed(1)} cm',
            icon: Icons.water_drop_outlined,
          ),
          const Divider(height: 12),
          _buildThresholdRow(
            theme,
            label: 'Reflood Trigger Depth',
            value: '${cfg.refloodTriggerCm.toStringAsFixed(1)} cm',
            icon: Icons.play_for_work,
          ),
          const Divider(height: 12),
          _buildThresholdRow(
            theme,
            label: 'Target Post-Irrigation Depth',
            value: '+${cfg.targetFloodDepthCm.toStringAsFixed(1)} cm',
            icon: Icons.waves,
          ),
          const Divider(height: 12),
          _buildThresholdRow(
            theme,
            label: 'Critical Dryness Threshold',
            value: '${cfg.criticalDrynessThresholdCm.toStringAsFixed(1)} cm',
            icon: Icons.warning_amber,
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdRow(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
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
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  void _showThresholdEditDialog(ThemeData theme, AwdThresholdConfig currentConfig) {
    double refloodVal = currentConfig.refloodTriggerCm;
    double targetVal = currentConfig.targetFloodDepthCm;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Configure AWD Thresholds'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reflood Trigger Depth: ${refloodVal.toStringAsFixed(1)} cm',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: refloodVal,
                    min: -25.0,
                    max: -5.0,
                    divisions: 20,
                    label: '${refloodVal.toStringAsFixed(1)} cm',
                    onChanged: (val) {
                      setDialogState(() {
                        refloodVal = val;
                      });
                    },
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                  Text(
                    'Target Post-Irrigation Depth: +${targetVal.toStringAsFixed(1)} cm',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: targetVal,
                    min: 1.0,
                    max: 12.0,
                    divisions: 11,
                    label: '+${targetVal.toStringAsFixed(1)} cm',
                    onChanged: (val) {
                      setDialogState(() {
                        targetVal = val;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                AquaButton(
                  label: 'Save Rules',
                  isFullWidth: false,
                  onPressed: () {
                    Navigator.of(context).pop();
                    _updateThresholdConfig(
                      currentConfig.copyWith(
                        safeDryThresholdCm: refloodVal,
                        refloodTriggerCm: refloodVal,
                        targetFloodDepthCm: targetVal,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildZoneRatesCard(ThemeData theme, AwdAnalyticsSummary summary) {
    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quad-Zone Drying & Wetting Rate Comparison',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated rate of water depth change per 24-hour cycle (cm/day)',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summary.zoneDryingRates.length,
            separatorBuilder: (context, index) => const Divider(height: 12),
            itemBuilder: (context, index) {
              final zr = summary.zoneDryingRates[index];
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            zr.zoneCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spaceSm),
                        Expanded(
                          child: Text(
                            zr.zoneName,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Text(
                        '${zr.currentDepthCm.toStringAsFixed(1)} cm',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${zr.dryingRateCmPerDay >= 0 ? '+' : ''}${zr.dryingRateCmPerDay.toStringAsFixed(1)} cm/d)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: zr.dryingRateCmPerDay < 0 ? AppColors.warning : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalChartSection(
      ThemeData theme, AwdAnalyticsSummary summary) {
    // Generate simulated average water level trend points
    final avgHistory = [3.5, 4.0, 4.2, 4.8, 5.0];

    return AquaChartContainer(
      title: 'Field Average Water Level Trend (AWD)',
      subtitle:
          '5-point field average water level history relative to soil surface (cm)',
      chartWidget: SimulatedTelemetryChart(
        dataPoints: avgHistory,
        labelSuffix: 'cm',
        lineColor: AppColors.primary,
      ),
    );
  }
}
