import 'package:flutter/material.dart';
import '../../../core/api/api_factory.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/widgets.dart';
import '../../awd/presentation/awd_analytics_screen.dart';
import 'system_evaluation_dashboard_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<double> _moistureTrend = [];
  List<double> _waterUsageTrend = [];
  double _avgMoisture = 0.0;
  double _dailyUsageLiters = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final factory = ApiRepositoryFactory();
      final zonesRes = await factory.fields.listQuarters();
      final zones = zonesRes.items;

      List<double> moistureValues = [];
      for (final z in zones) {
        final val = (z.data['soilMoisturePercent'] as num?)?.toDouble() ??
            (z.data['moisture'] as num?)?.toDouble();
        if (val != null) {
          moistureValues.add(val);
        }
      }

      double avgM = 0.0;
      if (moistureValues.isNotEmpty) {
        avgM = moistureValues.reduce((a, b) => a + b) / moistureValues.length;
      }

      if (mounted) {
        setState(() {
          _moistureTrend = moistureValues;
          _avgMoisture = avgM;
          _waterUsageTrend = [];
          _dailyUsageLiters = 0.0;
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: ErrorStateWidget(
          title: 'Analytics Unavailable',
          message: _errorMessage!,
          onRetry: _loadAnalytics,
        ),
      );
    }

    return ResponsiveContainer(
      child: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Field Analytics',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Historical telemetry & irrigation moisture trends',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge.hydrologyStatus(
                    _avgMoisture > 0 ? 'Live Telemetry' : 'No Data',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              AquaButton(
                label: 'View Irrigation Rules Engine & Field Analytics',
                icon: Icons.analytics,
                isFullWidth: true,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AwdAnalyticsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              AquaButton(
                label: '6-Indicator Performance & Accuracy Evaluation',
                icon: Icons.speed,
                variant: AquaButtonVariant.secondary,
                isFullWidth: true,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SystemEvaluationDashboardScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              _buildStatCardsRow(context),
              const SizedBox(height: AppDimensions.spaceLg),
              AquaChartContainer(
                title: 'Live Soil Moisture Across Zones',
                subtitle: 'Volumetric moisture percentage across reporting points',
                trailingHeader: StatusBadge.zoneStatus(
                  _avgMoisture >= 30 ? 'Optimal' : 'Low',
                  compact: true,
                ),
                chartWidget: _moistureTrend.isNotEmpty
                    ? SimulatedTelemetryChart(
                        dataPoints: _moistureTrend,
                        lineColor: AppColors.primary,
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppDimensions.spaceLg),
                          child: Text('No moisture data reported yet.'),
                        ),
                      ),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              AquaChartContainer(
                title: 'Central Field Water Consumption',
                subtitle: 'Daily volume supplied by central irrigation pump',
                chartWidget: _waterUsageTrend.isNotEmpty
                    ? SimulatedTelemetryChart(
                        dataPoints: _waterUsageTrend,
                        lineColor: AppColors.accent,
                        labelSuffix: 'L',
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppDimensions.spaceLg),
                          child: Text('No water consumption logs recorded.'),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCardsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AquaCard(
            padding: const EdgeInsets.all(AppDimensions.spaceSm),
            child: SensorMetricTile(
              label: 'Avg Moisture',
              value: _avgMoisture > 0 ? '${_avgMoisture.toStringAsFixed(1)}%' : '--',
              icon: Icons.water_drop,
              color: AppColors.primary,
              subtitle: 'Target: 30%-40%',
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spaceSm),
        Expanded(
          child: AquaCard(
            padding: const EdgeInsets.all(AppDimensions.spaceSm),
            child: SensorMetricTile(
              label: 'Daily Usage',
              value: _dailyUsageLiters > 0 ? _dailyUsageLiters.toStringAsFixed(0) : '--',
              unit: 'L',
              icon: Icons.opacity,
              color: AppColors.accent,
              subtitle: 'Irrigation Monitored',
            ),
          ),
        ),
      ],
    );
  }
}
