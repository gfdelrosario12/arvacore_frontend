import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/widgets.dart';
import '../data/repositories/field_dashboard_repository.dart';
import '../domain/models/field_dashboard_summary.dart';
import 'widgets/active_alerts_section.dart';
import 'widgets/central_irrigation_overview_card.dart';
import 'widgets/field_condition_header_card.dart';
import 'widgets/field_recommendations_card.dart';
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

  bool _isLoading = true;
  String? _errorMessage;
  FieldDashboardSummary? _summary;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FieldDashboardRepositoryImpl();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await _repository.fetchDashboardSummary();
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
        message: 'Loading AquaSense Dashboard...',
      );
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: ErrorStateWidget(
              message: _errorMessage!,
              onRetry: () => _loadDashboardData(),
            ),
          ),
        ],
      );
    }

    final summary = _summary;
    if (summary == null || summary.monitoringZones.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: _buildHeader(theme),
          ),
          Expanded(
            child: EmptyStateWidget(
              title: 'No Monitoring Data',
              message: 'No zone sensor data or central irrigation system status recorded.',
              actionLabel: 'Refresh Telemetry',
              onAction: () => _loadDashboardData(),
            ),
          ),
        ],
      );
    }

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
            const SizedBox(height: AppDimensions.spaceMd),
            FieldConditionHeaderCard(summary: summary),
            const SizedBox(height: AppDimensions.spaceLg),
            CentralIrrigationOverviewCard(
              system: summary.centralIrrigation,
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

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AquaSense Dashboard',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Field Water & Irrigation Command Overview',
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
