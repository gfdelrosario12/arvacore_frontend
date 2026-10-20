import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api/api_dtos.dart';
import '../../../core/api/api_factory.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/widgets.dart';
import 'widgets/add_reference_measurement_dialog.dart';
import 'widgets/indicator_card.dart';

class SystemEvaluationDashboardScreen extends StatefulWidget {
  final String? initialNodeId;
  final int? initialFieldId;

  const SystemEvaluationDashboardScreen({
    super.key,
    this.initialNodeId,
    this.initialFieldId,
  });

  @override
  State<SystemEvaluationDashboardScreen> createState() => _SystemEvaluationDashboardScreenState();
}

class _SystemEvaluationDashboardScreenState extends State<SystemEvaluationDashboardScreen> {
  final ApiRepositoryFactory _apiFactory = ApiRepositoryFactory();

  bool _isLoading = true;
  String? _errorMessage;
  SystemEvaluationSummaryDto? _summary;
  String? _selectedNodeId;
  int? _selectedFieldId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _selectedNodeId = widget.initialNodeId;
    _selectedFieldId = widget.initialFieldId;
    _loadEvaluationData();
    // Dynamically poll for new live evaluation data every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _loadEvaluationData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEvaluationData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final summary = await _apiFactory.evaluation.getSummary(
        nodeId: _selectedNodeId,
        fieldId: _selectedFieldId,
      );
      if (mounted) {
        setState(() {
          _summary = summary;
          _errorMessage = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _summary = _summary ?? _getDefaultEvaluationSummary();
          _isLoading = false;
        });
      }
    }
  }

  SystemEvaluationSummaryDto _getDefaultEvaluationSummary() {
    return const SystemEvaluationSummaryDto(
      waterLevel: WaterLevelEvalDto(
        capabilityStatus: 'NOT_EVALUATED',
        statusDescription: 'Not yet evaluated (Awaiting reference dipstick measurements)',
        latestReportedCm: null,
        latestReferenceCm: null,
        meanAbsoluteErrorCm: 0.0,
        meanAccuracyPercentage: 0.0,
        sampleCount: 0,
        calculationFormula: 'Accuracy (%) = max(0, 1 - MAE / 91.44) * 100',
        recentComparisons: [],
      ),
      soilMoisture: SoilMoistureEvalDto(
        capabilityStatus: 'NOT_EVALUATED',
        statusDescription: 'Not yet evaluated (Awaiting reference core / gravimetric measurements)',
        latestReportedPercentage: null,
        latestReferencePercentage: null,
        meanAbsoluteError: 0.0,
        meanAccuracyPercentage: 0.0,
        sampleCount: 0,
        calculationFormula: 'Accuracy (%) = max(0, 1 - MAE / 100) * 100',
        calibrationNotes: 'Awaiting independent standard core samples',
        recentComparisons: [],
      ),
      activation: ActivationEvalDto(
        capabilityStatus: 'AWAITING_TEST_DATA',
        statusDescription: 'Awaiting test data (No recorded activation decisions)',
        totalAttempts: 0,
        confirmedSuccesses: 0,
        failedAttempts: 0,
        successRatePercentage: 0.0,
        confirmationSource: 'Edge Node Downlink ACK & Pump Relay Status',
        calculationFormula: 'Activation Accuracy (%) = (Confirmed / Total) * 100',
      ),
      deactivation: DeactivationEvalDto(
        capabilityStatus: 'AWAITING_TEST_DATA',
        statusDescription: 'Awaiting test data (No recorded deactivation decisions)',
        totalAttempts: 0,
        confirmedSuccesses: 0,
        failedAttempts: 0,
        successRatePercentage: 0.0,
        confirmationSource: 'Edge Node ACK & Emergency Stop Feedback',
        calculationFormula: 'Deactivation Accuracy (%) = (Confirmed / Total) * 100',
      ),
      responseTime: ResponseTimeEvalDto(
        capabilityStatus: 'AWAITING_EVENTS',
        statusDescription: 'Awaiting events (No trigger-response pairs recorded)',
        measuredSampleCount: 0,
        avgCommandToAckMs: 0.0,
        minCommandToAckMs: 0.0,
        maxCommandToAckMs: 0.0,
        p95CommandToAckMs: 0.0,
        timeoutCount: 0,
        clockSyncNotes: 'Trigger Timestamp to Edge ACK Reception Delta',
        calculationFormula: 'Response Time = Response Timestamp - Trigger Timestamp',
      ),
      waterConsumption: WaterConsumptionEvalDto(
        capabilityStatus: 'AWAITING_DATA',
        statusDescription: 'Awaiting measurement data (Flow meter or calibrated model required)',
        measurementType: 'UNAVAILABLE',
        currentFlowRateLpm: 0.0,
        cumulativeConsumptionLiters: 0.0,
        hardwareRequirement: 'In-line pulse flow meter (e.g. YF-B5) or verified pump flow model',
        missingComponentExplanation: 'No volumetric flow meter registered. Modeled flow rate integration requires verified flow hardware.',
      ),
    );
  }

  Future<void> _recordGroundTruth(String indicatorType, double? reportedVal) async {
    final success = await AddReferenceMeasurementDialog.show(
      context,
      initialIndicatorType: indicatorType,
      initialNodeId: _selectedNodeId ?? 'NODE-01',
      currentReportedValue: reportedVal,
      onSubmit: (dto) async {
        await _apiFactory.evaluation.createReferenceMeasurement(dto);
      },
    );

    if (success == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reference measurement recorded and accuracy recalibrated.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadEvaluationData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Irrigation Performance Evaluation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
            onPressed: _loadEvaluationData,
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: _isLoading
              ? const LoadingStateWidget(message: 'Auditing system performance indicators...')
              : RefreshIndicator(
                  onRefresh: _loadEvaluationData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppDimensions.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
                            decoration: BoxDecoration(
                              color: AppColors.alertWarning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                              border: Border.all(color: AppColors.alertWarning.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: AppColors.alertWarning),
                                const SizedBox(width: AppDimensions.spaceSm),
                                Expanded(
                                  child: Text(
                                    'Awaiting live server telemetry: ${_errorMessage!}. Displaying research baselines (0-initialized).',
                                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.alertWarning, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.alertWarning),
                                  onPressed: _loadEvaluationData,
                                ),
                              ],
                            ),
                          ),
                        ],
                            _buildCapabilityOverviewHeader(theme),
                            const SizedBox(height: AppDimensions.spaceLg),

                            // 1. Water-Level Monitoring Accuracy
                            _buildWaterLevelCard(theme),
                            const SizedBox(height: AppDimensions.spaceLg),

                            // 2. Soil-Moisture Monitoring Accuracy
                            _buildSoilMoistureCard(theme),
                            const SizedBox(height: AppDimensions.spaceLg),

                            // 3. Irrigation Activation Accuracy
                            _buildActivationCard(theme),
                            const SizedBox(height: AppDimensions.spaceLg),

                            // 4. Irrigation Deactivation Accuracy
                            _buildDeactivationCard(theme),
                            const SizedBox(height: AppDimensions.spaceLg),

                            // 5. Irrigation Response Time
                            _buildResponseTimeCard(theme),
                            const SizedBox(height: AppDimensions.spaceLg),

                            // 6. Water Consumption Monitoring
                            _buildWaterConsumptionCard(theme),
                            const SizedBox(height: AppDimensions.spaceLg),

                            _buildAuditIntegrityNotice(theme),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildCapabilityOverviewHeader(ThemeData theme) {
    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assessment_outlined, color: AppColors.primary, size: 28),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance Measurement & Accuracy Audit',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '6-Indicator Evaluation against Hardware Realities & Ground-Truth Reference',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          Text(
            'In accordance with empirical measurement standards: Sensor readings alone cannot establish accuracy without independent reference data. Command delivery is distinguished from physical operation, and missing flow hardware is explicitly reported.',
            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  // 1. Water Level
  Widget _buildWaterLevelCard(ThemeData theme) {
    final wl = _summary?.waterLevel;
    if (wl == null) return const SizedBox.shrink();

    final reported = wl.latestReportedCm != null ? '${wl.latestReportedCm!.toStringAsFixed(1)} cm' : 'No Data';
    final ref = wl.latestReferenceCm != null ? '${wl.latestReferenceCm!.toStringAsFixed(1)} cm' : 'Pending Ref';
    final absErr = wl.meanAbsoluteErrorCm != null ? '${wl.meanAbsoluteErrorCm!.toStringAsFixed(2)} cm' : '--';
    final acc = wl.meanAccuracyPercentage != null ? '${wl.meanAccuracyPercentage!.toStringAsFixed(1)}%' : 'Pending';

    List<double> historyPoints = [];
    for (final c in wl.recentComparisons) {
      if (c.accuracyPercentage != null) {
        historyPoints.add(c.accuracyPercentage!);
      }
    }

    return IndicatorCard(
      title: '1. Water-Level Monitoring Accuracy',
      subtitle: 'Ultrasonic sensor (JSN-SR04T) perforated-well measurement vs. physical dipstick reference',
      icon: Icons.water,
      capabilityStatus: wl.capabilityStatus,
      statusDescription: wl.statusDescription,
      calculationFormula: wl.calculationFormula,
      onAddReference: () => _recordGroundTruth('WATER_LEVEL', wl.latestReportedCm),
      addReferenceLabel: 'Enter Water-Level Dipstick Reference',
      metrics: [
        _buildMetricItem('Latest Reported', reported, Icons.sensors, AppColors.primary),
        _buildMetricItem('Latest Ground-Truth', ref, Icons.rule, AppColors.secondary),
        _buildMetricItem('Mean Absolute Error', absErr, Icons.error_outline, AppColors.warning),
        _buildMetricItem('Overall Accuracy', acc, Icons.verified_outlined, AppColors.success),
        _buildMetricItem('Evaluated Samples', '${wl.sampleCount}', Icons.tag, AppColors.textSecondaryOf(context)),
      ],
      historicalWidget: wl.recentComparisons.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (historyPoints.length >= 2) ...[
                  SizedBox(
                    height: 100,
                    child: SimulatedTelemetryChart(
                      dataPoints: historyPoints,
                      lineColor: AppColors.success,
                      labelSuffix: '%',
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceSm),
                ],
                _buildComparisonsTable(wl.recentComparisons, 'cm'),
              ],
            )
          : null,
    );
  }

  // 2. Soil Moisture
  Widget _buildSoilMoistureCard(ThemeData theme) {
    final sm = _summary?.soilMoisture;
    if (sm == null) return const SizedBox.shrink();

    final reported = sm.latestReportedPercentage != null ? '${sm.latestReportedPercentage!.toStringAsFixed(1)}%' : 'No Data';
    final ref = sm.latestReferencePercentage != null ? '${sm.latestReferencePercentage!.toStringAsFixed(1)}%' : 'Pending Ref';
    final absErr = sm.meanAbsoluteError != null ? '${sm.meanAbsoluteError!.toStringAsFixed(2)}%' : '--';
    final acc = sm.meanAccuracyPercentage != null ? '${sm.meanAccuracyPercentage!.toStringAsFixed(1)}%' : 'Not Measurable';

    return IndicatorCard(
      title: '2. Soil-Moisture Monitoring Accuracy',
      subtitle: 'Capacitive analog sensor (v1.2) ADC calibrated scale vs. gravimetric / TDR probe reference',
      icon: Icons.grass,
      capabilityStatus: sm.capabilityStatus,
      statusDescription: sm.statusDescription,
      calculationFormula: sm.calculationFormula,
      onAddReference: () => _recordGroundTruth('SOIL_MOISTURE', sm.latestReportedPercentage),
      addReferenceLabel: 'Enter Calibrated Soil Reference',
      metrics: [
        _buildMetricItem('Reported Moisture', reported, Icons.sensors, AppColors.primary),
        _buildMetricItem('Reference Standard', ref, Icons.rule, AppColors.secondary),
        _buildMetricItem('Mean Absolute Error', absErr, Icons.error_outline, AppColors.warning),
        _buildMetricItem('Accuracy Estimate', acc, Icons.verified_outlined, sm.sampleCount > 0 ? AppColors.success : AppColors.error),
        _buildMetricItem('Evaluated Samples', '${sm.sampleCount}', Icons.tag, AppColors.textSecondaryOf(context)),
      ],
      historicalWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sm.calibrationNotes != null && sm.calibrationNotes!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tune, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Calibration: ${sm.calibrationNotes!}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (sm.recentComparisons.isNotEmpty)
            _buildComparisonsTable(sm.recentComparisons, '%'),
        ],
      ),
    );
  }

  // 3. Activation Accuracy
  Widget _buildActivationCard(ThemeData theme) {
    final act = _summary?.activation;
    if (act == null) return const SizedBox.shrink();

    final rate = act.successRatePercentage != null ? '${act.successRatePercentage!.toStringAsFixed(1)}%' : 'No Attempts';

    return IndicatorCard(
      title: '3. Irrigation Activation Accuracy',
      subtitle: 'Command state machine dispatch to edge node radio acknowledgment',
      icon: Icons.play_circle_outline,
      capabilityStatus: act.capabilityStatus,
      statusDescription: act.statusDescription,
      calculationFormula: act.calculationFormula,
      metrics: [
        _buildMetricItem('Total Activation Commands', '${act.totalAttempts}', Icons.input, AppColors.primary),
        _buildMetricItem('Confirmed Node ACKs', '${act.confirmedSuccesses}', Icons.check_circle_outline, AppColors.success),
        _buildMetricItem('Failed / Cancelled', '${act.failedAttempts}', Icons.highlight_off, AppColors.error),
        _buildMetricItem('Activation Success Rate', rate, Icons.percent, AppColors.success),
      ],
      historicalWidget: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceSm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirmation Source: ${act.confirmationSource ?? "Edge Node Downlink ACK"}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Deactivation Accuracy
  Widget _buildDeactivationCard(ThemeData theme) {
    final deact = _summary?.deactivation;
    if (deact == null) return const SizedBox.shrink();

    final rate = deact.successRatePercentage != null ? '${deact.successRatePercentage!.toStringAsFixed(1)}%' : 'No Attempts';

    return IndicatorCard(
      title: '4. Irrigation Deactivation Accuracy',
      subtitle: 'Stop commands and emergency shutoff acknowledgment confirmation',
      icon: Icons.stop_circle_outlined,
      capabilityStatus: deact.capabilityStatus,
      statusDescription: deact.statusDescription,
      calculationFormula: deact.calculationFormula,
      metrics: [
        _buildMetricItem('Total Deactivation Commands', '${deact.totalAttempts}', Icons.input, AppColors.primary),
        _buildMetricItem('Confirmed Node ACKs', '${deact.confirmedSuccesses}', Icons.check_circle_outline, AppColors.success),
        _buildMetricItem('Failed Attempts', '${deact.failedAttempts}', Icons.highlight_off, AppColors.error),
        _buildMetricItem('Deactivation Success Rate', rate, Icons.percent, AppColors.success),
      ],
      historicalWidget: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceSm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirmation Source: ${deact.confirmationSource ?? "Edge Node ACK & Emergency Stop State Machine"}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. Response Time
  Widget _buildResponseTimeCard(ThemeData theme) {
    final rt = _summary?.responseTime;
    if (rt == null) return const SizedBox.shrink();

    final avg = rt.avgCommandToAckMs != null ? '${rt.avgCommandToAckMs!.toStringAsFixed(0)} ms' : '--';
    final min = rt.minCommandToAckMs != null ? '${rt.minCommandToAckMs!.toStringAsFixed(0)} ms' : '--';
    final max = rt.maxCommandToAckMs != null ? '${rt.maxCommandToAckMs!.toStringAsFixed(0)} ms' : '--';
    final p95 = rt.p95CommandToAckMs != null ? '${rt.p95CommandToAckMs!.toStringAsFixed(0)} ms' : '--';

    return IndicatorCard(
      title: '5. Irrigation Response Time',
      subtitle: 'Latency from backend command dispatch (ACCEPTED) to edge radio ACK (EDGE_ACKNOWLEDGED)',
      icon: Icons.timer_outlined,
      capabilityStatus: rt.capabilityStatus,
      statusDescription: rt.statusDescription,
      calculationFormula: rt.calculationFormula,
      metrics: [
        _buildMetricItem('Avg Latency', avg, Icons.speed, AppColors.primary),
        _buildMetricItem('Min Latency', min, Icons.arrow_downward, AppColors.secondary),
        _buildMetricItem('Max Latency', max, Icons.arrow_upward, AppColors.warning),
        _buildMetricItem('95th Percentile (P95)', p95, Icons.stacked_bar_chart, AppColors.accent),
        _buildMetricItem('Completed Events', '${rt.measuredSampleCount}', Icons.check, AppColors.success),
        _buildMetricItem('Timeouts', '${rt.timeoutCount}', Icons.alarm_off, AppColors.error),
      ],
      historicalWidget: rt.clockSyncNotes != null
          ? Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rt.clockSyncNotes!,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // 6. Water Consumption
  Widget _buildWaterConsumptionCard(ThemeData theme) {
    final wc = _summary?.waterConsumption;
    if (wc == null) return const SizedBox.shrink();

    return IndicatorCard(
      title: '6. Water Consumption Monitoring',
      subtitle: 'Volumetric flow rate and cumulative water allocation',
      icon: Icons.opacity,
      capabilityStatus: wc.capabilityStatus,
      statusDescription: wc.statusDescription,
      metrics: [
        _buildMetricItem('Current Flow Rate', '0.0 L/min', Icons.speed, AppColors.error),
        _buildMetricItem('Cumulative Water Volume', '0 L', Icons.water_drop, AppColors.error),
      ],
      historicalWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.build_circle_outlined, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Missing Hardware & Calibration Requirements',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  wc.missingComponentExplanation ??
                      'Current node hardware carries only soil moisture and ultrasonic sensors. Physical volumetric consumption cannot be claimed without a verified flow measurement source.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceSm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.hardware, color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hardware Requirement: ${wc.hardwareRequirement ?? "In-line pulse flow meter (e.g., YF-B5 Hall-effect) or calibrated pump flow-rate model"}',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceSm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.rule, color: AppColors.warning, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Calibration Requirement: Flow meter K-factor pulse calibration or hydraulic pump curve verification against manual collection bucket standard.',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonsTable(List<ReferenceMeasurementDto> comparisons, String unit) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Ground-Truth Comparisons:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 32,
            dataRowMinHeight: 28,
            dataRowMaxHeight: 36,
            columns: const [
              DataColumn(label: Text('Node')),
              DataColumn(label: Text('Reported')),
              DataColumn(label: Text('Reference')),
              DataColumn(label: Text('Abs Error')),
              DataColumn(label: Text('Accuracy')),
              DataColumn(label: Text('Instrument')),
            ],
            rows: comparisons.take(5).map((c) {
              return DataRow(cells: [
                DataCell(Text(c.nodeId, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text('${c.reportedValue.toStringAsFixed(1)} $unit')),
                DataCell(Text('${c.referenceValue.toStringAsFixed(1)} $unit')),
                DataCell(Text('${c.absoluteError.toStringAsFixed(2)} $unit')),
                DataCell(Text(c.accuracyPercentage != null ? '${c.accuracyPercentage!.toStringAsFixed(1)}%' : '--')),
                DataCell(Text(c.instrumentDetails ?? '--', style: const TextStyle(fontSize: 11))),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondaryOf(context)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditIntegrityNotice(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scientific & Statistical Integrity Standard',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'This evaluation module complies with strict empirical validation rules: every metric defines its explicit calculation; ground-truth entries are persisted to the database; zero-denominators are safely clamped; and missing flow sensors are never disguised with estimated numbers.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

