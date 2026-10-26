import 'package:flutter/material.dart';
import '../../../core/api/api_dtos.dart';
import '../../../core/api/api_errors.dart';
import '../../../core/api/api_factory.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/realtime/dashboard_polling.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../irrigation/domain/models/centralized_irrigation.dart';
import '../../irrigation/presentation/widgets/manual_control_confirmation_dialog.dart';
import '../../shell/presentation/app_shell.dart';
import '../data/repositories/field_dashboard_repository.dart';
import '../domain/models/field_dashboard_summary.dart';
import 'widgets/active_alerts_section.dart';
import 'widgets/central_irrigation_overview_card.dart';
import 'widgets/connected_nodes_card.dart';
import 'widgets/field_condition_header_card.dart';
import 'widgets/field_recommendations_card.dart';
import 'widgets/arva_ai_advisor_card.dart';
import 'widgets/ultrasonic_water_level_diagram.dart';
import '../../farming_chat/presentation/farming_chatbot_screen.dart' as com_farming_chat;

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToControl;
  final VoidCallback? onNavigateToField;
  final VoidCallback? onNavigateToAi;
  final FieldDashboardRepository? repository;

  /// Enables the live 5-second telemetry poll.
  ///
  /// `null` (the default) enables the poll in production and disables it inside widget
  /// test harnesses, where a permanently pending timer would keep `pumpAndSettle` busy
  /// forever. Tests that assert the polling behaviour pass `true` explicitly.
  final bool? enableLivePolling;

  const HomeScreen({
    super.key,
    this.onNavigateToControl,
    this.onNavigateToField,
    this.onNavigateToAi,
    this.repository,
    this.enableLivePolling,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final FieldDashboardRepository _repository;
  final ApiRepositoryFactory _apiFactory = ApiRepositoryFactory();

  bool _isLoading = true;
  bool _isOperating = false;
  bool _isStale = false;
  String? _notificationError;
  String? _errorMessage;
  bool _masterEnabled = true;
  FieldDashboardSummary? _summary;
  MockState _currentMockState = MockState.normal;

  late final DashboardPollingService _pollingService;
  late final bool _livePollingEnabled;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FieldDashboardRepositoryImpl();
    _livePollingEnabled = widget.enableLivePolling ??
        !WidgetsBinding.instance.runtimeType.toString().contains('Test');

    // Single centralized polling mechanism for the whole Home Dashboard. It polls the
    // batched latest-telemetry endpoint every 5 seconds while the dashboard is visible
    // and the application is active.
    _pollingService = DashboardPollingService(
      fetchCallback: _refreshTelemetry,
      pollInterval: const Duration(seconds: 5),
    );

    WidgetsBinding.instance.addObserver(this);
    globalNodeSyncNotifier.addListener(_onGlobalNodeSync);
    globalActiveTabNotifier.addListener(_onActiveTabChanged);

    if (_livePollingEnabled) {
      _loadDashboardData().whenComplete(() {
        if (mounted) {
          _pollingService.start();
        }
      });
    } else {
      _loadDashboardData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    globalNodeSyncNotifier.removeListener(_onGlobalNodeSync);
    globalActiveTabNotifier.removeListener(_onActiveTabChanged);
    _pollingService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      _handleAppLifecycle(state);
    }
  }

  void _handleAppLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App became active - resume polling and refresh immediately.
        _pollingService.start();
        _pollingService.forcePoll();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App became inactive - pause polling.
        _pollingService.stop();
        break;
    }
  }

  void _onActiveTabChanged() {
    if (!mounted || !_livePollingEnabled) return;
    if (globalActiveTabNotifier.value == homeTabIndex) {
      // Returning to the dashboard: refresh immediately and resume the normal cadence.
      _pollingService.start();
      _pollingService.forcePoll();
    } else {
      // Dashboard is not visible: stop polling entirely.
      _pollingService.stop();
    }
  }

  void _onGlobalNodeSync() {
    if (!mounted) return;
    // The node topology changed (pairing, assignment, field topology): reload it.
    _loadDashboardData();
  }

  /// Loads the dashboard topology: nodes, monitoring zones and irrigation status.
  Future<void> _loadDashboardData({MockState? overrideState}) async {
    final stateToFetch = overrideState ?? _currentMockState;

    if (_summary == null) {
      setState(() => _isLoading = true);
    }
    setState(() {
      _errorMessage = null;
      _notificationError = null;
      _currentMockState = stateToFetch;
    });

    try {
      final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
      final summaryFuture = _repository.fetchDashboardSummary(mockState: stateToFetch);
      final masterFuture = isTest
          ? Future.value(const MasterStateDto(masterEnabled: true, updatedBy: 'system'))
          : _apiFactory.system.getMasterState().catchError((_) {
              return const MasterStateDto(
                masterEnabled: true,
                updatedBy: 'system',
              );
            });

      final results = await Future.wait([
        summaryFuture,
        masterFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _summary = results[0] as FieldDashboardSummary;
        _masterEnabled = (results[1] as MasterStateDto).masterEnabled;
        _isLoading = false;
        _isStale = false;
        _errorMessage = null;
        _notificationError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.kind == ApiErrorKind.authentication) {
        globalAuthNotifier.handleApiSecurityFailure(e);
        return;
      }
      final String detail = _describeError(e);
      setState(() {
        _isLoading = false;
        _errorMessage = detail;
        if (stateToFetch == MockState.error || _summary == null) {
          _notificationError = 'Telemetry Sync Error: $detail';
        } else {
          // Keep the last received readings and mark them as possibly stale.
          _isStale = true;
          _notificationError =
              'Telemetry Sync Error: $detail - showing last known readings';
        }
      });
    }
  }

  /// Polls the latest telemetry of every known node and refreshes the dashboard.
  ///
  /// The previous values stay on screen while the request is running, so a successful
  /// refresh never produces a loading animation or a flicker.
  Future<void> _refreshTelemetry() async {
    try {
      final summary = await _repository.refreshLatestTelemetry();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
        _isStale = false;
        _errorMessage = null;
        _notificationError = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.kind == ApiErrorKind.authentication) {
        globalAuthNotifier.handleApiSecurityFailure(e);
        return;
      }
      setState(() {
        _isLoading = false;
        if (_summary != null) {
          // Retain the last received reading but flag it as possibly stale.
          _isStale = true;
          _summary = _summary!.copyWith(forceStale: true);
          _notificationError =
              'Telemetry Sync Error: ${_describeError(e)} - showing last known readings';
        } else {
          _errorMessage = _describeError(e);
          _notificationError = 'Telemetry Sync Error: ${_describeError(e)}';
        }
      });
      // Propagate so the polling service can apply its bounded retry backoff.
      rethrow;
    }
  }

  String _describeError(Object error) {
    if (error is ApiException) {
      return error.statusCode != null
          ? 'HTTP ${error.statusCode}: ${error.message}'
          : error.message;
    }
    return error.toString().replaceAll('Exception: ', '');
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
          await _pollingService.forcePoll();
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
          await _pollingService.forcePoll();
        }
      }
    }
  }

  Future<bool> _handleUnpairNode(String nodeId) async {
    try {
      await _apiFactory.nodes.unpairNode(nodeId);
      await _pollingService.forcePoll();
      notifyGlobalNodeStateChanged();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _handleRemoveFromField(String nodeId) async {
    try {
      await _apiFactory.nodes.removeNodeFromField(nodeId);
      await _pollingService.forcePoll();
      notifyGlobalNodeStateChanged();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _handleResetPairing({List<String>? nodeIds, String? reason}) async {
    try {
      await _apiFactory.system.resetPairing(nodeIds: nodeIds, reason: reason);
      await _pollingService.forcePoll();
      notifyGlobalNodeStateChanged();
      return true;
    } catch (e) {
      return false;
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
      forceStale: _isStale,
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
    if (_isLoading && _summary == null) {
      return const LoadingStateWidget(
        message: 'Loading AquaSense Dashboard...',
      );
    }

    if (_currentMockState == MockState.error && _errorMessage != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: _buildHeader(theme),
          ),
          Expanded(
            child: ErrorStateWidget(
              title: 'Telemetry Connection Error',
              message: _errorMessage ?? 'Failed to fetch field telemetry data.',
              onRetry: () => _pollingService.forcePoll(),
            ),
          ),
        ],
      );
    }

    final summary = _summary ?? _getFallbackSummary();
    final width = MediaQuery.sizeOf(context).width;
    final isDesktopOrTablet = width >= AppDimensions.breakpointMobile;

    return RefreshIndicator(
      onRefresh: () => _pollingService.forcePoll(),
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
            if (isDesktopOrTablet) ...[
              // 2-Column Responsive Dashboard Layout for Web / Desktop / Tablet
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CentralIrrigationOverviewCard(
                          system: summary.centralIrrigation,
                          isMasterOff: !_masterEnabled,
                          isOperating: _isOperating,
                          onStartManual: _handleStartManual,
                          onStopManual: _handleStopManual,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceLg),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConnectedNodesCard(
                          nodes: summary.connectedNodes,
                          zones: summary.monitoringZones,
                          isMasterOff: !_masterEnabled,
                          onManageNodes: widget.onNavigateToField,
                          onUnpairNode: _handleUnpairNode,
                          onRemoveFromField: _handleRemoveFromField,
                          onResetPairing: _handleResetPairing,
                        ),
                        const SizedBox(height: AppDimensions.spaceLg),
                        ArvaAiAdvisorCard(
                          summaryText: summary.requiresIrrigation
                              ? 'AWD Threshold Notice: Soil desiccation or water depth in monitoring zones has reached reflood trigger (-15.0 cm). Field replenishment recommended.'
                              : 'Field Terraces Status: All 6 monitoring nodes report water levels and soil moisture within safe AWD drying boundaries.',
                          proposalType: summary.requiresIrrigation ? 'REFLOOD_PROPOSAL' : 'NONE',
                          targetZone: summary.requiresIrrigation ? 'Pitak 6 (Tail Drainage)' : null,
                          rationale: summary.requiresIrrigation
                              ? 'IRRI Alternate Wetting and Drying protocol recommends shallow flooding (+5 cm) once field water table reaches -15 cm.'
                              : 'Safe drying reduces greenhouse gas emissions and conserves irrigation water without yield penalty.',
                          onReviewProposal: widget.onNavigateToControl,
                          onOpenChatbot: widget.onNavigateToAi ?? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const com_farming_chat.FarmingChatbotScreen(),
                              ),
                            );
                          },
                        ),
                        if (summary.activeAlerts.isNotEmpty) ...[
                          const SizedBox(height: AppDimensions.spaceLg),
                          ActiveAlertsSection(alerts: summary.activeAlerts),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Mobile-First Single-Column Linear View
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
                onUnpairNode: _handleUnpairNode,
                onRemoveFromField: _handleRemoveFromField,
                onResetPairing: _handleResetPairing,
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
              ArvaAiAdvisorCard(
                summaryText: summary.requiresIrrigation
                    ? 'AWD Threshold Notice: Soil desiccation or water depth in monitoring zones has reached reflood trigger (-15.0 cm). Field replenishment recommended.'
                    : 'Field Terraces Status: All 6 monitoring nodes report water levels and soil moisture within safe AWD drying boundaries.',
                proposalType: summary.requiresIrrigation ? 'REFLOOD_PROPOSAL' : 'NONE',
                targetZone: summary.requiresIrrigation ? 'Pitak 6 (Tail Drainage)' : null,
                rationale: summary.requiresIrrigation
                    ? 'IRRI Alternate Wetting and Drying protocol recommends shallow flooding (+5 cm) once field water table reaches -15 cm.'
                    : 'Safe drying reduces greenhouse gas emissions and conserves irrigation water without yield penalty.',
                onReviewProposal: widget.onNavigateToControl,
                onOpenChatbot: widget.onNavigateToAi ?? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const com_farming_chat.FarmingChatbotScreen(),
                    ),
                  );
                },
              ),
              if (summary.activeAlerts.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spaceLg),
                ActiveAlertsSection(alerts: summary.activeAlerts),
              ],
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
            onPressed: () => _pollingService.forcePoll(),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const ArvaLogo(
                size: 42,
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${AppStrings.arvaLinkName} Dashboard',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
      ],
    ),
  ),


        PopupMenuButton<MockState>(
          icon: const Icon(Icons.tune, color: AppColors.primary),
          tooltip: 'Simulate UI States',
          onSelected: (MockState state) => _loadDashboardData(overrideState: state),
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: MockState.normal,
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                  SizedBox(width: 8),
                  Text('Normal State'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: MockState.stale,
              child: Row(
                children: [
                  Icon(Icons.history, size: 18, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text('Stale Telemetry'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: MockState.empty,
              child: Row(
                children: [
                  Icon(Icons.inbox, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Empty State'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: MockState.error,
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Error State'),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => _pollingService.forcePoll(),
          icon: Icon(
            Icons.sync,
            color: AppColors.primary,
            semanticLabel: 'Sync Telemetry',
          ),
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
