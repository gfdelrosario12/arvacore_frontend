import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api/api_dtos.dart';
import '../../../core/api/api_errors.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/widgets.dart';
import '../../control/domain/models/control_enums.dart';
import '../../irrigation/data/repositories/irrigation_repository.dart';
import '../../irrigation/domain/models/centralized_irrigation.dart';
import '../../nodes/data/repositories/api_node_repository.dart';
import '../../nodes/data/repositories/node_repository.dart';
import '../../nodes/domain/models/models.dart';
import '../../nodes/presentation/widgets/node_registration_dialog.dart';
import '../../nodes/presentation/widgets/spatial_field_canvas_visualizer.dart';

import '../../nodes/presentation/widgets/transmission_interval_dialog.dart';
import '../../zones/data/repositories/zone_repository.dart';
import '../../zones/domain/models/monitoring_zone.dart';
import 'widgets/dynamic_zone_grid_visualizer.dart';
import 'widgets/field_header_overview_card.dart';
import 'widgets/pairing_requests_modal.dart';
import 'widgets/zone_detail_bottom_sheet.dart';
import '../../../core/api/api_factory.dart';
import '../../../core/api/api_mappers.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

enum FieldVisualizationMode { matrix, spatial }

class FieldScreen extends StatefulWidget {
  final VoidCallback? onNavigateToControl;
  final ZoneRepository? repository;
  final NodeRepository? nodeRepository;
  final IrrigationRepository? irrigationRepository;
  final ControlUserRole userRole;

  const FieldScreen({
    super.key,
    this.onNavigateToControl,
    this.repository,
    this.nodeRepository,
    this.irrigationRepository,
    this.userRole = ControlUserRole.operator,
  });

  @override
  State<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends State<FieldScreen> {
  late final ZoneRepository _zoneRepository;
  late final NodeRepository _nodeRepository;
  late final IrrigationRepository _irrigationRepository;
  late final ApiRepositoryFactory _apiFactory;

  bool _isLoading = true;
  String? _errorMessage;
  List<MonitoringZone> _zones = [];
  List<Esp32Node> _nodes = [];
  CentralizedIrrigation? _centralIrrigation;
  FieldVisualizationMode _visMode = FieldVisualizationMode.matrix;
  String? _selectedZoneCode;

  // Master State and Pairing Requests
  bool _masterEnabled = true;
  bool _isTogglingMaster = false;
  List<PairingRequestDto> _pendingPairings = [];
  Timer? _pairingPollTimer;

  @override
  void initState() {
    super.initState();
    _apiFactory = ApiRepositoryFactory();
    _zoneRepository = widget.repository ?? ZoneRepositoryImpl();
    _nodeRepository = widget.nodeRepository ?? ApiNodeRepository(_apiFactory.nodes);
    _irrigationRepository = widget.irrigationRepository ?? IrrigationRepositoryImpl();
    _loadZones();
    _startPairingPolling();
  }

  @override
  void dispose() {
    _pairingPollTimer?.cancel();
    super.dispose();
  }

  void _startPairingPolling() {
    _pairingPollTimer?.cancel();
    _pairingPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollPairingRequestsSilently();
    });
  }

  Future<void> _pollPairingRequestsSilently() async {
    if (!mounted) return;
    try {
      final pairings = await _apiFactory.system.getPendingPairingRequests();
      if (mounted) {
        if (_pendingPairings.length != pairings.length ||
            !_pendingPairings.every((p) => pairings.any((n) => n.id == p.id))) {
          setState(() {
            _pendingPairings = pairings;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadZones() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    List<MonitoringZone> zones = _zones;
    List<Esp32Node> nodes = _nodes;
    CentralizedIrrigation? sys = _centralIrrigation;
    final List<String> failures = [];

    // 1. Monitoring Zones
    try {
      zones = await _zoneRepository.fetchMonitoringZones();
    } catch (e) {
      debugPrint('[FieldScreen] Failed to fetch monitoring zones: $e');
      if (e is ApiException && e.kind == ApiErrorKind.authentication) {
        if (mounted) globalAuthNotifier.handleApiSecurityFailure(e);
        return;
      }
      failures.add('Zones: ${_formatErrorMessage(e)}');
    }

    // 2. Nodes
    try {
      nodes = await _nodeRepository.fetchNodes();
    } catch (e) {
      debugPrint('[FieldScreen] Failed to fetch nodes: $e');
      if (e is ApiException && e.kind == ApiErrorKind.authentication) {
        if (mounted) globalAuthNotifier.handleApiSecurityFailure(e);
        return;
      }
      failures.add('Nodes: ${_formatErrorMessage(e)}');
    }

    // 3. Central Irrigation Telemetry / Status
    try {
      sys = await _irrigationRepository.fetchSystemStatus();
    } catch (e) {
      debugPrint('[FieldScreen] Irrigation status unavailable: $e');
      // Irrigation status failure does not prevent displaying field zones and paired nodes
    }

    // 4. Master state & pending pairing requests
    bool masterOn = _masterEnabled;
    List<PairingRequestDto> pairings = _pendingPairings;
    try {
      final masterState = await _apiFactory.system.getMasterState();
      masterOn = masterState.masterEnabled;
      pairings = await _apiFactory.system.getPendingPairingRequests();
      debugPrint('[FieldScreen] Loaded ${pairings.length} pending pairing requests');
    } catch (err) {
      debugPrint('[FieldScreen] Pairing requests/master state fetch notice: $err');
    }

    if (mounted) {
      setState(() {
        _zones = zones;
        _nodes = nodes;
        _centralIrrigation = sys;
        _masterEnabled = masterOn;
        _pendingPairings = pairings;
        _isLoading = false;
        // Only set error message if fundamental zone/node data completely failed to load
        _errorMessage = (failures.isNotEmpty && zones.isEmpty && nodes.isEmpty)
            ? failures.join(' | ')
            : null;
      });
    }
  }

  String _formatErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.kind == ApiErrorKind.connectivity) {
        return 'Network connection failed (Server unreachable)';
      }
      if (error.kind == ApiErrorKind.timeout) {
        return 'Request timed out';
      }
      if (error.kind == ApiErrorKind.transportSecurity) {
        return 'TLS/SSL handshake failure';
      }
      if (error.statusCode != null) {
        return 'HTTP ${error.statusCode} (${error.message})';
      }
      return '${error.message} (${error.kind.name})';
    }
    return error.toString().replaceAll('Exception: ', '');
  }

  Future<void> _toggleMasterState(bool nextState) async {
    setState(() => _isTogglingMaster = true);
    try {
      final result = await _apiFactory.system.updateMasterState(
        enabled: nextState,
        notes: nextState ? 'Turned ON via ArvaLink' : 'Turned OFF via ArvaLink',
      );
      if (mounted) {
        setState(() {
          _masterEnabled = result.masterEnabled;
          _isTogglingMaster = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.masterEnabled
                  ? 'ArvaCore Master System turned ON.'
                  : 'ArvaCore Master System turned OFF. Telemetry & pairing disabled.',
            ),
            backgroundColor: result.masterEnabled ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e is ApiException
            ? (e.statusCode != null ? 'HTTP ${e.statusCode}: ${e.message}' : e.message)
            : e.toString().replaceAll('Exception: ', '');

        debugPrint('[FieldScreen] Master state update error: $e');

        final isOfflineOrServerError = (e is ApiException &&
            (e.kind == ApiErrorKind.connectivity ||
             e.kind == ApiErrorKind.timeout ||
             e.kind == ApiErrorKind.decoding ||
             e.kind == ApiErrorKind.server ||
             e.statusCode == 502 ||
             e.statusCode == 503 ||
             e.statusCode == 504)) ||
            e.toString().contains('XMLHttpRequest') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('SocketException');

        if (isOfflineOrServerError) {
          // Fall back gracefully in offline/mock demo mode
          setState(() {
            _masterEnabled = nextState;
            _isTogglingMaster = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Master System updated locally (Backend offline: $errorMsg)'),
              backgroundColor: AppColors.warning,
            ),
          );
        } else {
          setState(() => _isTogglingMaster = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update Master state: $errorMsg'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openPairingModal() async {
    try {
      final fresh = await _apiFactory.system.getPendingPairingRequests();
      if (mounted) setState(() => _pendingPairings = fresh);
    } catch (_) {}

    if (!mounted) return;
    PairingRequestsModal.show(
      context,
      requests: _pendingPairings,
      isMasterOff: !_masterEnabled,
      onAllow: (req) => _handleAllowPairing(req),
      onReject: (req) => _handleRejectPairing(req),
    );
  }

  Future<void> _handleRejectPairing(PairingRequestDto req) async {
    Navigator.of(context).pop(); // dismiss modal
    try {
      await _apiFactory.system.rejectPairingRequest(req.id, reason: 'Rejected by administrator');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rejected pairing request for ${req.nodeId}.'),
          backgroundColor: AppColors.error,
        ),
      );
      await _loadZones();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleAllowPairing(PairingRequestDto req) async {
    Navigator.of(context).pop(); // dismiss requests modal

    // Build discovered item from the pairing request
    final discoveryInfo = NodeDiscoveryInfo(
      id: req.nodeId,
      macAddress: req.macAddress ?? 'AA:BB:CC:DD:EE:01',
      hardwareModel: req.hardwareModel ?? 'ESP32 Wi-Fi Node',
      firmwareVersion: req.firmwareVersion ?? '1.0.0',
      rssiDbm: -65,
      detectedAt: DateTime.now(),
      pairingRequestId: req.id,
      recognized: req.recognized,
      pairingStatus: req.pairingStatus,
      existingLifecycleState: req.existingLifecycleState,
      existingZoneId: req.existingZoneId,
      existingZoneName: req.existingZoneName,
    );

    // Open Device Selection & Assignment Dialog
    if (!mounted) return;
    final registered = await NodeRegistrationDialog.show(
      context,
      discoveredNodes: [discoveryInfo],
      onRegister: (registerReq) async {
        // Parse zone number
        int? zoneNum;
        if (registerReq.zoneId.isNotEmpty) {
          zoneNum = int.tryParse(registerReq.zoneId.replaceAll(RegExp(r'[^0-9]'), ''));
        }
        await _apiFactory.system.approvePairingRequest(
          req.id,
          nodeId: registerReq.displayName.isNotEmpty ? registerReq.displayName : req.nodeId,
          identityType: 'MAC_ADDRESS',
          identityValue: registerReq.macAddress,
          macAddress: registerReq.macAddress,
          hardwareModel: req.hardwareModel ?? 'ESP32 Wi-Fi Node',
          firmwareVersion: req.firmwareVersion ?? '1.0.0',
          monitoringZoneId: zoneNum,
        );
        return true;
      },
    );

    if (registered == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ArvaNode ${req.nodeId} successfully approved and assigned!'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadZones();
    }
  }

  void _handleZoneSelection(MonitoringZone zone) {
    setState(() => _selectedZoneCode = zone.code);
    final assignedNodes = _nodes
        .where(
          (n) =>
              zone.assignedNodeIds.contains(n.id) ||
              n.assignedZoneId == zone.id ||
              n.assignedZoneId == zone.code,
        )
        .toList();
    ZoneDetailBottomSheet.show(
      context,
      zone: zone,
      assignedNodes: assignedNodes,
      userRole: widget.userRole,
      onConfigureInterval: (node) => _configureNodeInterval(node),
    );
  }

  Future<void> _configureNodeInterval(Esp32Node node) async {
    await TransmissionIntervalDialog.show(
      context,
      node: node,
      userRole: widget.userRole,
      onConfigure: (interval, {bool isAdaptive = false, String? reason}) async {
        await _nodeRepository.configureTransmissionInterval(
          node.id,
          TransmissionConfigDto(
            intervalSeconds: interval,
            isAdaptive: isAdaptive,
            reason: reason,
          ),
        );
        await _loadZones();
        return true;
      },
    );
  }

  Future<void> _openNodeScanner() async {
    try {
      final fresh = await _apiFactory.system.getPendingPairingRequests();
      if (mounted) setState(() => _pendingPairings = fresh);
      debugPrint('[FieldScreen] _openNodeScanner fetched ${fresh.length} pending requests');
    } catch (e) {
      debugPrint('[FieldScreen] _openNodeScanner failed to fetch pending requests: $e');
    }

    final List<NodeDiscoveryInfo> discovered = [];
    for (final p in _pendingPairings) {
      discovered.add(NodeDiscoveryInfo(
        id: p.nodeId,
        macAddress: p.macAddress ?? p.nodeId,
        hardwareModel: p.hardwareModel ?? 'ESP32 Wi-Fi Node',
        firmwareVersion: p.firmwareVersion ?? '1.0.0',
        rssiDbm: -65,
        detectedAt: ApiMappers.parseIsoDateTime(p.requestedAt) ?? DateTime.now(),
        pairingRequestId: p.id,
        recognized: p.recognized,
        pairingStatus: p.pairingStatus,
        existingLifecycleState: p.existingLifecycleState,
        existingZoneId: p.existingZoneId,
        existingZoneName: p.existingZoneName,
      ));
    }

    try {
      final unassigned = await _nodeRepository.fetchDiscoveredNodes();
      for (final u in unassigned) {
        if (!discovered.any((d) => d.macAddress == u.macAddress || d.id == u.id)) {
          discovered.add(u);
        }
      }
    } catch (_) {}

    if (!mounted) return;
    final registered = await NodeRegistrationDialog.show(
      context,
      discoveredNodes: discovered,
      onRefresh: () async {
        final List<NodeDiscoveryInfo> updated = [];
        try {
          final fresh = await _apiFactory.system.getPendingPairingRequests();
          if (mounted) setState(() => _pendingPairings = fresh);
          for (final p in fresh) {
            DateTime? parsedAt;
            try {
              parsedAt = DateTime.tryParse(p.requestedAt);
            } catch (_) {}
            updated.add(NodeDiscoveryInfo(
              id: p.nodeId,
              macAddress: p.macAddress ?? p.nodeId,
              hardwareModel: p.hardwareModel ?? 'ESP32 Wi-Fi Node',
              firmwareVersion: p.firmwareVersion ?? '1.0.0',
              rssiDbm: -65,
              detectedAt: parsedAt ?? DateTime.now(),
              pairingRequestId: p.id,
              recognized: p.recognized,
              pairingStatus: p.pairingStatus,
              existingLifecycleState: p.existingLifecycleState,
              existingZoneId: p.existingZoneId,
              existingZoneName: p.existingZoneName,
            ));
          }
        } catch (e) {
          debugPrint('[FieldScreen] NodeRegistrationDialog onRefresh error: $e');
        }

        try {
          final unassigned = await _nodeRepository.fetchDiscoveredNodes();
          for (final u in unassigned) {
            if (!updated.any((d) => d.macAddress == u.macAddress || d.id == u.id)) {
              updated.add(u);
            }
          }
        } catch (_) {}

        return updated;
      },
      onRegister: (request) async {
        final matching = discovered.firstWhere(
          (d) => d.macAddress == request.macAddress,
          orElse: () => discovered.first,
        );
        if (matching.pairingRequestId != null) {
          int? zoneNum;
          if (request.zoneId.isNotEmpty) {
            zoneNum = int.tryParse(request.zoneId.replaceAll(RegExp(r'[^0-9]'), ''));
          }
          await _apiFactory.system.approvePairingRequest(
            matching.pairingRequestId!,
            nodeId: request.displayName.isNotEmpty ? request.displayName : matching.id,
            identityType: 'MAC_ADDRESS',
            identityValue: request.macAddress,
            macAddress: request.macAddress,
            hardwareModel: matching.hardwareModel,
            monitoringZoneId: zoneNum,
          );
        } else {
          await _nodeRepository.registerNode(request);
        }
        await _loadZones();
        return true;
      },
    );
    if (registered == true) {
      await _loadZones();
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
        message: 'Loading Field Zone Telemetry...',
      );
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: _buildHeader(theme),
          ),
          Expanded(
            child: ErrorStateWidget(
              title: 'ArvaNet Gateway Telemetry Error',
              message: _errorMessage!,
              onRetry: () => _loadZones(),
            ),
          ),
        ],
      );
    }

    if (_zones.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: AppDimensions.spaceMd),
                FieldHeaderOverviewCard(
                  zones: const [],
                  isStale: false,
                  masterEnabled: _masterEnabled,
                  isTogglingMaster: _isTogglingMaster,
                  onToggleMaster: _toggleMasterState,
                  pendingPairingCount: _pendingPairings.length,
                  onOpenPairingRequests: _openPairingModal,
                ),
              ],
            ),
          ),
          Expanded(
            child: EmptyStateWidget(
              title: 'No Active Monitoring Zones',
              message: _pendingPairings.isNotEmpty
                  ? 'There are ${_pendingPairings.length} incoming hardware pairing request(s). Tap "Allow" on the banner above to approve and pair your node.'
                  : 'No ArvaNodes deployed or active in this field.',
              actionLabel: 'Refresh',
              onAction: () => _loadZones(),
            ),
          ),
        ],
      );
    }

    final isStale = false;

    return RefreshIndicator(
      onRefresh: () => _loadZones(),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: AppDimensions.spaceSm),
            // Mode Selector Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.grid_view, size: 16),
                    label: const Text('Matrix Grid'),
                    selected: _visMode == FieldVisualizationMode.matrix,
                    onSelected: (_) => setState(
                      () => _visMode = FieldVisualizationMode.matrix,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  ChoiceChip(
                    avatar: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Spatial Field Map'),
                    selected: _visMode == FieldVisualizationMode.spatial,
                    onSelected: (_) => setState(
                      () => _visMode = FieldVisualizationMode.spatial,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            _buildCentralActuatorsCard(_centralIrrigation),
            const SizedBox(height: AppDimensions.spaceMd),
            FieldHeaderOverviewCard(
              zones: _zones,
              isStale: isStale,
              masterEnabled: _masterEnabled,
              isTogglingMaster: _isTogglingMaster,
              onToggleMaster: _toggleMasterState,
              pendingPairingCount: _pendingPairings.length,
              onOpenPairingRequests: _openPairingModal,
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            if (_visMode == FieldVisualizationMode.spatial)
              SpatialFieldCanvasVisualizer(
                nodes: _nodes,
                onNodeSelected: (node) {
                  final zone = _zones
                      .where(
                        (z) =>
                            z.id == node.assignedZoneId ||
                            z.code == node.assignedZoneId ||
                            z.code.toLowerCase() ==
                                node.assignedZoneId
                                    ?.toLowerCase()
                                    .replaceAll('zone-', ''),
                      )
                      .firstOrNull;
                  if (zone != null) {
                    _handleZoneSelection(zone);
                  }
                },
                onConfigureInterval: (node) => _configureNodeInterval(node),
              )
            else
              DynamicZoneGridVisualizer(
                zones: _zones,
                selectedZoneCode: _selectedZoneCode,
                onZoneSelected: _handleZoneSelection,
                isMasterOff: !_masterEnabled,
              ),
            const SizedBox(height: AppDimensions.spaceLg),
            Text(
              'Detailed Zone Telemetry List',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _zones.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppDimensions.spaceMd),
              itemBuilder: (context, index) {
                return _buildZoneCard(_zones[index]);
              },
            ),
            const SizedBox(height: AppDimensions.spaceLg),
            _buildMonitoringNoticeCard(theme),
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
                '${AppStrings.arvaNodesName}: ${AppStrings.arvaNodeTitle}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.arvaNodeDescription,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        Badge(
          isLabelVisible: _pendingPairings.isNotEmpty,
          label: Text('${_pendingPairings.length}'),
          backgroundColor: AppColors.secondary,
          child: IconButton(
            onPressed: _openNodeScanner,
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            tooltip: 'Pair Pending ArvaNodes (${_pendingPairings.length} waiting)',
          ),
        ),
        IconButton(
          onPressed: () => _loadZones(),
          icon: const Icon(Icons.sync, color: AppColors.primary),
          tooltip: 'Sync Field Data',
        ),
      ],
    );
  }

  Widget _buildMonitoringNoticeCard(ThemeData theme) {
    return AquaCard(
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Read-Only Monitoring Zones',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.zoneNotice,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(MonitoringZone zone) {
    return AquaCard(
      onTap: () => _handleZoneSelection(zone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spaceSm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: Text(
                        zone.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Text(
                        zone.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              StatusBadge.zoneStatus(zone.status.name, compact: true),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: SensorMetricTile(
                  label: 'Soil Moisture',
                  value: '${zone.soilMoisturePercent.toStringAsFixed(1)}%',
                  icon: Icons.water,
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Water Level',
                  value: zone.waterLevelCm.toStringAsFixed(1),
                  unit: 'cm',
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
                  label: 'Signal (RSSI)',
                  value: '${zone.rssiDbm}',
                  unit: 'dBm',
                  icon: Icons.cell_tower,
                  color: AppColors.primaryLight,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Sensor Battery',
                  value: zone.batteryPercent.toString(),
                  unit: '%',
                  icon: zone.batteryPercent < 20
                      ? Icons.battery_alert
                      : Icons.battery_full,
                  color: zone.batteryPercent < 20
                      ? AppColors.error
                      : AppColors.deviceBatteryGood,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCentralActuatorsCard(CentralizedIrrigation? sys) {
    if (sys == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final pumpText = sys.mainPumpState == PumpState.active
        ? 'PUMPING'
        : (sys.mainPumpState == PumpState.warning
            ? 'WARNING'
            : (sys.mainPumpState == PumpState.offline ? 'OFFLINE' : 'OFF'));
    final valveText = sys.distributionValveState == ValveState.open
        ? 'OPEN'
        : (sys.distributionValveState == ValveState.partial ? 'PARTIAL' : 'CLOSED');
    final ctrlText = sys.mainPumpState == PumpState.offline ? 'OFFLINE' : 'ONLINE';

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
                    const Icon(Icons.settings_remote_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Text(
                        'Central Field Hardware Status',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              StatusBadge.deviceStatus(ctrlText, compact: true),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          const Divider(),
          const SizedBox(height: AppDimensions.spaceSm),
          Row(
            children: [
              Expanded(
                child: SensorMetricTile(
                  label: 'Main Pump',
                  value: pumpText,
                  icon: Icons.power_settings_new,
                  color: sys.mainPumpState == PumpState.active ? AppColors.pumpActive : AppColors.primary,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Main Valve',
                  value: valveText,
                  icon: Icons.alt_route,
                  color: sys.distributionValveState == ValveState.open ? AppColors.valveOpen : AppColors.primary,
                ),
              ),
              Expanded(
                child: SensorMetricTile(
                  label: 'Flow Rate',
                  value: sys.flowRateLitersPerMin.toStringAsFixed(1),
                  unit: 'L/min',
                  icon: Icons.speed,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
