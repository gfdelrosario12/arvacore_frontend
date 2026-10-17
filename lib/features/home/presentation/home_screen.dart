import 'package:flutter/material.dart';
import '../../../core/api/api_dtos.dart';
import '../../../core/api/api_errors.dart';
import '../../../core/api/api_factory.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../irrigation/domain/models/centralized_irrigation.dart';
import '../../irrigation/presentation/widgets/manual_control_confirmation_dialog.dart';
import '../data/repositories/field_dashboard_repository.dart';
import '../domain/models/field_dashboard_summary.dart';
import 'widgets/active_alerts_section.dart';
import 'widgets/central_irrigation_overview_card.dart';
import 'widgets/connected_nodes_card.dart';
import 'widgets/field_condition_header_card.dart';
import 'widgets/field_recommendations_card.dart';
import 'widgets/ultrasonic_water_level_diagram.dart';
import 'widgets/zone_contrast_summary_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToControl;
  final VoidCallback? onNavigateToField;
  final FieldDashboardRepository? repository;

  const HomeScreen({
    super.key,
    this.onNavigateToControl,
    this.onNavigateToField,
    this.repository,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FieldDashboardRepository _repository;
  final ApiRepositoryFactory _apiFactory = ApiRepositoryFactory();

  bool _isLoading = true;
  bool _isOperating = false;
  String? _notificationError;
  bool _masterEnabled = true;
  FieldDashboardSummary? _summary;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FieldDashboardRepositoryImpl();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = _summary == null; // only show initial loader if no data yet
      _notificationError = null;
    });

    try {
      final summaryFuture = _repository.fetchDashboardSummary();
      final masterFuture = _apiFactory.system.getMasterState().catchError((_) {
        return const MasterStateDto(
          masterEnabled: true,
          updatedBy: 'system',
        );
      });

      final results = await Future.wait([
        summaryFuture,
        masterFuture,
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as FieldDashboardSummary;
          _masterEnabled = (results[1] as MasterStateDto).masterEnabled;
          _isLoading = false;
          _notificationError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e is ApiException && e.kind == ApiErrorKind.authentication) {
          globalAuthNotifier.handleApiSecurityFailure(e);
          return;
        }
        setState(() {
          _notificationError = e is ApiException
              ? (e.statusCode != null ? 'Telemetry Sync Error (HTTP ${e.statusCode}): ${e.message}' : 'Telemetry Sync Error: ${e.message}')
              : 'Telemetry Sync Error: ${e.toString().replaceAll('Exception: ', '')}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleStartManual() async {
    final result = await ManualControlConfirmationDialog.show(
      context: context,
      initialDurationMinutes: 30,
      actionType: 'start',
    );

    if (result != null && result.confirmed) {
      setState(() => _isOperating = true);
      try {
        await _apiFactory.irrigation.startManual(
          operatorId: globalAuthNotifier.value.session?.username ?? 'operator',
          durationMinutes: result.durationMinutes,
          rationale: result.rationale ?? 'Manual irrigation pulse initiated from Home dashboard',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Manual irrigation started for ${result.durationMinutes}m.'),
              backgroundColor: AppColors.pumpActive,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start manual irrigation: $e'),
              backgroundColor: AppColors.alertError,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isOperating = false);
          _loadDashboardData();
        }
      }
    }
  }

  Future<void> _handleStopManual() async {
    final result = await ManualControlConfirmationDialog.show(
      context: context,
      actionType: 'stop',
    );

    if (result != null && result.confirmed) {
      setState(() => _isOperating = true);
      try {
        await _apiFactory.irrigation.stopManual(
          operatorId: globalAuthNotifier.value.session?.username ?? 'operator',
          rationale: result.rationale ?? 'Manual stop commanded from Home dashboard',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Irrigation halted successfully.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to stop irrigation: $e'),
              backgroundColor: AppColors.alertError,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isOperating = false);
          _loadDashboardData();
        }
      }
    }
  }

  FieldDashboardSummary _getFallbackSummary() {
    return FieldDashboardSummary(
      overallCondition: FieldConditionStatus.optimal,
      overallConditionLabel: 'Standby / Awaiting Telemetry',
      awdStatusLabel: 'Moisture Sufficient',
      requiresIrrigation: false,
      isIrrigationRunning: false,
      recommendedActionText: 'Observe field sensor telemetry readings.',
      lastUpdated: DateTime.now(),
      centralIrrigation: CentralizedIrrigation(
        id: 'central-system-01',
        systemName: 'Main Field Irrigation Hub',
        mainPumpState: PumpState.idle,
        distributionValveState: ValveState.closed,
        flowRateLitersPerMin: 0.0,
        pressureBar: 0.0,
        mode: SystemMode.manual,
        activeDurationMinutes: 0,
        lastStateChange: DateTime.now(),
      ),
      monitoringZones: const [],
      connectedNodes: const [],
      activeAlerts: const [],
      recommendations: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const LoadingStateWidget(
        message: 'Loading ArvaLink Dashboard...',
      );
    }

    final summary = _summary ?? _getFallbackSummary();

    return RefreshIndicator(
      onRefresh: () => _loadDashboardData(),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            if (_notificationError != null) ...[
              const SizedBox(height: AppDimensions.spaceSm),
              _buildCompactNotificationBanner(theme),
            ],
            const SizedBox(height: AppDimensions.spaceMd),
            FieldConditionHeaderCard(summary: summary),
            const SizedBox(height: AppDimensions.spaceLg),
            CentralIrrigationOverviewCard(
              system: summary.centralIrrigation,
              isMasterOff: !_masterEnabled,
              isOperating: _isOperating,
              onStartManual: _handleStartManual,
              onStopManual: _handleStopManual,
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            ConnectedNodesCard(
              nodes: summary.connectedNodes,
              zones: summary.monitoringZones,
              isMasterOff: !_masterEnabled,
              onManageNodes: widget.onNavigateToField,
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            UltrasonicWaterLevelDiagram(
              nodes: summary.connectedNodes,
              zones: summary.monitoringZones,
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            FieldRecommendationsCard(
              summary: summary,
              onNavigateToControl: widget.onNavigateToControl,
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            ZoneContrastSummaryCard(
              summary: summary,
              onNavigateToField: widget.onNavigateToField,
            ),
            if (summary.activeAlerts.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spaceLg),
              ActiveAlertsSection(alerts: summary.activeAlerts),
            ],
            const SizedBox(height: AppDimensions.spaceLg),
            _buildNoticeBanner(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactNotificationBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.alertWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.alertWarning.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.alertWarning),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Text(
              _notificationError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.alertWarning,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSm),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.refresh, size: 18, color: AppColors.alertWarning),
            tooltip: 'Retry Telemetry Retrieval',
            onPressed: () => _loadDashboardData(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '${AppStrings.arvaLinkName}: ${AppStrings.arvaLinkTitle}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (_masterEnabled ? AppColors.success : Colors.grey).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_masterEnabled ? AppColors.success : Colors.grey).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _masterEnabled ? AppColors.success : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _masterEnabled ? 'OPERATIONAL' : 'STANDBY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _masterEnabled ? AppColors.success : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.arvaLinkDescription,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        IconButton(
          onPressed: () => _loadDashboardData(),
          icon: const Icon(Icons.sync, color: AppColors.primary),
          tooltip: 'Sync Field Telemetry',
        ),
      ],
    );
  }

  Widget _buildNoticeBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Text(
              AppStrings.zoneNotice,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

