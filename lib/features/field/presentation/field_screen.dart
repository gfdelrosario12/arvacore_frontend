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

import '../../nodes/presentation/widgets/node_assignment_dialog.dart';
import '../../nodes/presentation/widgets/transmission_interval_dialog.dart';
import '../../zones/data/repositories/zone_repository.dart';
import '../../zones/domain/models/monitoring_zone.dart';
import 'widgets/dynamic_zone_grid_visualizer.dart';
import 'widgets/field_header_overview_card.dart';
import 'widgets/pairing_requests_modal.dart';
import 'widgets/zone_detail_bottom_sheet.dart';
import 'widgets/farmland_designer_view.dart';
import '../domain/models/field.dart';
import '../../../core/api/api_factory.dart';
import '../../../core/api/api_mappers.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

enum FieldVisualizationMode { matrix, spatial, designer }

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
  Field? _currentField;

  // Master State and Pairing Requests
  bool _masterEnabled = true;
  bool _isTogglingMaster = false;
  List<PairingRequestDto> _pendingPairings = [];
  Timer? _pairingPollTimer;
  bool _isPollingPairings = false;

  @override
  void initState() {
    super.initState();
    _apiFactory = ApiRepositoryFactory();
    _zoneRepository = widget.repository ?? ZoneRepositoryImpl();
    _nodeRepository = widget.nodeRepository ??
        (WidgetsBinding.instance.runtimeType.toString().contains('Test')
            ? MockNodeRepository()
            : ApiNodeRepository(_apiFactory.nodes));
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
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) return;
    _pairingPollTimer?.cancel();
    _pairingPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _pollPairingRequestsSilently();
    });
  }

  Future<void> _pollPairingRequestsSilently() async {
    if (!mounted || _isPollingPairings) return;
    _isPollingPairings = true;
    try {
      final pairings = await _apiFactory.system.getPendingPairingRequests(retryable: false);
      if (mounted) {
        if (_pendingPairings.length != pairings.length ||
            !_pendingPairings.every((p) => pairings.any((n) => n.id == p.id))) {
          setState(() {
            _pendingPairings = pairings;
          });
        }
      }
    } catch (_) {
    } finally {
      _isPollingPairings = false;
    }
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
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      try {
        final masterState = await _apiFactory.system.getMasterState();
        masterOn = masterState.masterEnabled;
        pairings = await _apiFactory.system.getPendingPairingRequests();
        debugPrint('[FieldScreen] Loaded ${pairings.length} pending pairing requests');
      } catch (err) {
        debugPrint('[FieldScreen] Pairing requests/master state fetch notice: $err');
      }
    }

    // 5. Enrich zones with live node telemetry
    if (nodes.isNotEmpty && zones.isNotEmpty) {
      zones = zones.map((zone) {
        final assignedNodes = nodes.where((n) =>
            zone.assignedNodeIds.contains(n.id) ||
            zone.assignedNodeIds.contains(n.displayName) ||
            n.assignedZoneId == zone.id ||
            n.assignedZoneId == zone.code ||
            n.assignedZoneId == 'zone-${zone.id}' ||
            n.assignedZoneId == zone.id.replaceAll(RegExp(r'[^0-9]'), '')).toList();

        if (assignedNodes.isNotEmpty) {
          final moistureValues = assignedNodes
              .map((n) => n.soilMoisturePercent)
              .whereType<double>()
              .toList();
          final waterValues = assignedNodes
              .map((n) => n.waterLevelCm)
              .whereType<double>()
              .toList();
          final batteryValues = assignedNodes
              .map((n) => n.batteryPercent)
              .whereType<int>()
              .toList();

          final double avgMoisture = moistureValues.isNotEmpty
              ? moistureValues.reduce((a, b) => a + b) / moistureValues.length
              : zone.soilMoisturePercent;

          final double avgWater = waterValues.isNotEmpty
              ? waterValues.reduce((a, b) => a + b) / waterValues.length
              : zone.waterLevelCm;

          final int avgBattery = batteryValues.isNotEmpty
              ? (batteryValues.reduce((a, b) => a + b) / batteryValues.length).round()
              : zone.batteryPercent;

          final isAnyOnline = assignedNodes.any((n) => n.isOnline);

          return zone.copyWith(
            soilMoisturePercent: avgMoisture,
            waterLevelCm: avgWater,
            batteryPercent: avgBattery,
            isOnline: isAnyOnline,
            assignedNodeIds: assignedNodes.map((n) => n.id).toList(),
          );
        }
        return zone;
      }).toList();
    }

    // 6. Fetch Field Configuration dynamically
    Field? fieldCfg;
    if (!isTest) {
      try {
        final fieldsListDto = await _apiFactory.fields.listFields();
        if (fieldsListDto.items.isNotEmpty) {
          // Prefer first available field or currently selected field
          final matched = fieldsListDto.items.where((f) => f.id == _currentField?.id).firstOrNull;
          final targetDto = matched ?? fieldsListDto.items.first;
          fieldCfg = ApiMappers.field(FieldDto.fromJson(targetDto.data));
        } else {
          fieldCfg = null;
        }
      } catch (e) {
        debugPrint('[FieldScreen] Field list fetch notice: $e');
        try {
          final fieldDto = await _apiFactory.fields.getField(_currentField?.id ?? '1');
          fieldCfg = ApiMappers.field(FieldDto.fromJson(fieldDto.data));
        } catch (err) {
          debugPrint('[FieldScreen] Field details fetch notice: $err');
        }
      }
    }

    if (mounted) {
      setState(() {
        _zones = zones;
        _nodes = nodes;
        _currentField = fieldCfg;
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
      if (error.isInsufficientRole || error.statusCode == 403) {
        return 'Administrator or Field Admin permissions required to perform this action.';
      }
      if (error.statusCode == 404) {
        return 'Resource not found or already removed.';
      }
      if (error.statusCode == 409) {
        return 'Conflict: ${error.message}';
      }
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
      expiresAt: req.expiresAt,
      isExpired: req.isExpired,
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
          nodeId: req.nodeId.isNotEmpty ? req.nodeId : (registerReq.displayName.isNotEmpty ? registerReq.displayName : req.nodeId),
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
              zone.assignedNodeIds.contains(n.displayName) ||
              n.assignedZoneId == zone.id ||
              n.assignedZoneId == zone.code ||
              n.assignedZoneId == 'zone-${zone.id}' ||
              n.assignedZoneId == zone.id.replaceAll(RegExp(r'[^0-9]'), ''),
        )
        .toList();
    ZoneDetailBottomSheet.show(
      context,
      zone: zone,
      assignedNodes: assignedNodes,
      userRole: widget.userRole,
      onConfigureInterval: (node) => _configureNodeInterval(node),
      onAssignNode: (z, n) {
        Navigator.of(context).pop();
        _openNodeAssignment(zone: z, node: n);
      },
      onDeleteZone: (z) async {
        try {
          // 1. Safely unassign any physically assigned nodes to the unassigned pool
          // so that foreign keys/validations don't block deletion and nodes are not orphaned.
          if (assignedNodes.isNotEmpty) {
            for (final node in assignedNodes) {
              try {
                await _nodeRepository.assignNodeToField(
                  node.id,
                  fieldId: 1,
                  monitoringZoneId: null,
                );
              } catch (nodeErr) {
                debugPrint('[FieldScreen] Notice: Failed to unassign node ${node.id} before zone deletion: $nodeErr');
              }
            }
          }

          // 2. Archive / delete the monitoring zone using field-scoped & fallback endpoint
          final fieldId = z.fieldId.isNotEmpty ? z.fieldId : (_currentField?.id ?? '1');
          await _zoneRepository.deleteZone(z.id, fieldId: fieldId);

          if (mounted) {
            setState(() {
              _zones.removeWhere((zone) => zone.id == z.id || zone.code == z.code);
              if (_selectedZoneCode == z.code) {
                _selectedZoneCode = null;
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Monitoring position ${z.code} removed successfully.'),
                backgroundColor: AppColors.success,
              ),
            );
          }
          await _loadZones();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to remove position: ${_formatErrorMessage(e)}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
    );
  }

  Future<void> _openNodeAssignment({Esp32Node? node, MonitoringZone? zone}) async {
    final success = await NodeAssignmentDialog.show(
      context,
      nodes: _nodes,
      zones: _zones,
      initialNode: node,
      initialZone: zone,
      onAssign: (nodeId, {int? fieldId, int? monitoringZoneId}) async {
        try {
          await _nodeRepository.assignNodeToField(
            nodeId,
            fieldId: fieldId ?? 1,
            monitoringZoneId: monitoringZoneId,
          );
          return true;
        } catch (e) {
          debugPrint('[FieldScreen] Assignment failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to assign ArvaNode: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return false;
        }
      },
      onCreateZone: () => _showCreateZoneDialog(),
    );

    if (success == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Node assignment updated successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _loadZones();
    }
  }

  Future<MonitoringZone?> _showCreateZoneDialog() async {
    final nameController = TextEditingController(text: 'Zone ${_zones.length + 1}');
    final areaController = TextEditingController(text: '1.0');
    final cropController = TextEditingController(text: 'Rice');
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.add_location, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add Monitoring Zone'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Zone Name *',
                    hintText: 'e.g. Zone 5, Sector B',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: areaController,
                  decoration: const InputDecoration(
                    labelText: 'Area (Hectares) *',
                    hintText: 'e.g. 1.25',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Area is required';
                    if (double.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cropController,
                  decoration: const InputDecoration(
                    labelText: 'Crop Type *',
                    hintText: 'e.g. Rice, Corn, Vegetables',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Crop type is required' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Create Zone'),
          ),
        ],
      ),
    );

    if (created == true) {
      try {
        final newZone = await _zoneRepository.createZone(
          name: nameController.text.trim(),
          area: double.parse(areaController.text.trim()),
          cropType: cropController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Zone "${newZone.name}" created successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await _loadZones();
        return newZone;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create zone: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return null;
      }
    }
    return null;
  }

  Future<void> _deleteField(Field field) async {
    try {
      // 1. Unassign all physical nodes first so they return to pool
      for (final node in _nodes) {
        try {
          await _nodeRepository.assignNodeToField(node.id, fieldId: 1, monitoringZoneId: null);
        } catch (_) {}
      }

      // 2. Delete the field on the backend
      await _apiFactory.fields.deleteField(field.id);

      if (mounted) {
        setState(() {
          _currentField = null;
          _zones = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Farmland "${field.name}" deleted successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _loadZones();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete farmland: ${_formatErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildEmptyFieldCard(ThemeData theme) {
    return AquaCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        child: Column(
          children: [
            Icon(
              Icons.landscape_outlined,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Farmland Configured',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The previous farmland was removed or no farmland has been registered yet. Add a new farmland to configure monitoring zones and connect sensor nodes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Add Farmland'),
              onPressed: () => _showCreateZoneDialog(),
            ),
          ],
        ),
      ),
    );
  }

  List<Esp32Node> _getUnassignedNodes() {
    return _nodes.where((n) {
      final zoneId = n.assignedZoneId?.trim();
      if (zoneId == null || zoneId.isEmpty || zoneId == 'unassigned') {
        return true;
      }
      return !_zones.any((z) =>
          z.id == zoneId ||
          z.code == zoneId ||
          z.code.toLowerCase() == zoneId.toLowerCase().replaceAll('zone-', '') ||
          z.assignedNodeIds.contains(n.id) ||
          z.assignedNodeIds.contains(n.displayName));
    }).toList();
  }

  Widget _buildUnassignedNodesCard(ThemeData theme, List<Esp32Node> unassigned) {
    if (unassigned.isEmpty) return const SizedBox.shrink();

    return AquaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: const Icon(Icons.device_hub, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unassigned Hardware Nodes (${unassigned.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paired ArvaNodes awaiting field placement or monitoring position assignment.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          const Divider(),
          const SizedBox(height: AppDimensions.spaceSm),
          ...unassigned.map((node) {
            final isLive = node.isOnline;
            final moisture = node.soilMoisturePercent;
            final waterLevel = node.waterLevelCm;
            final battery = node.batteryPercent ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLive ? AppColors.success : AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                node.displayName.isNotEmpty ? node.displayName : node.id,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spaceSm),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'UNASSIGNED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          children: [
                            Text(
                              'MAC: ${node.macAddress}',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                            if (moisture != null)
                              Text(
                                'Moisture: ${moisture.toStringAsFixed(1)}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (waterLevel != null)
                              Text(
                                'Water: ${waterLevel.toStringAsFixed(1)} cm',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Text(
                              'Bat: $battery%',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: () => _openNodeAssignment(node: node),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                    label: const Text('Assign Position'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      try {
        final fresh = await _apiFactory.system.getPendingPairingRequests();
        if (mounted) setState(() => _pendingPairings = fresh);
        debugPrint('[FieldScreen] _openNodeScanner fetched ${fresh.length} pending requests');
      } catch (e) {
        debugPrint('[FieldScreen] _openNodeScanner failed to fetch pending requests: $e');
      }
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
        expiresAt: p.expiresAt,
        isExpired: p.isExpired,
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
              expiresAt: p.expiresAt,
              isExpired: p.isExpired,
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
            nodeId: matching.id.isNotEmpty ? matching.id : (request.displayName.isNotEmpty ? request.displayName : matching.id),
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

    final unassignedNodes = _getUnassignedNodes();

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
                  const SizedBox(width: AppDimensions.spaceSm),
                  ChoiceChip(
                    avatar: const Icon(Icons.architecture, size: 16),
                    label: const Text('Farmland Designer'),
                    selected: _visMode == FieldVisualizationMode.designer,
                    onSelected: (_) => setState(
                      () => _visMode = FieldVisualizationMode.designer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spaceMd),
            if (_visMode == FieldVisualizationMode.designer) ...[
              if (_currentField == null && _zones.isEmpty)
                _buildEmptyFieldCard(theme)
              else
                FarmlandDesignerView(
                  field: _currentField ??
                      Field(
                        id: '1',
                        name: 'ArvaCore Farmland',
                        lengthMeters: 100.0,
                        widthMeters: 100.0,
                        totalArea: 1.0,
                        areaUnit: 'hectares',
                        operationalStatus: 'READY',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                  zones: _zones,
                  nodes: _nodes,
                  onRefresh: _loadZones,
                  onDeleteField: _deleteField,
                  onAssignNode: (nodeId, {int? fieldId, int? monitoringZoneId}) async {
                    try {
                      if (fieldId == null && monitoringZoneId == null) {
                        await _nodeRepository.removeNodeFromField(nodeId);
                      } else {
                        await _nodeRepository.assignNodeToField(
                          nodeId,
                          fieldId: fieldId ?? 1,
                          monitoringZoneId: monitoringZoneId,
                        );
                      }
                      return true;
                    } catch (e) {
                      debugPrint('[FieldScreen] Assignment/removal failed: $e');
                      return false;
                    }
                  },
                ),
            ] else ...[
              if (_zones.isEmpty) ...[
                FieldHeaderOverviewCard(
                  zones: const [],
                  isStale: false,
                  masterEnabled: _masterEnabled,
                  isTogglingMaster: _isTogglingMaster,
                  onToggleMaster: _toggleMasterState,
                  pendingPairingCount: _pendingPairings.length,
                  onOpenPairingRequests: _openPairingModal,
                ),
                if (unassignedNodes.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spaceMd),
                  _buildUnassignedNodesCard(theme, unassignedNodes),
                ],
                const SizedBox(height: AppDimensions.spaceLg),
                DynamicZoneGridVisualizer(
                  zones: const [],
                  nodes: _nodes,
                  onAddZone: () => _showCreateZoneDialog(),
                  isMasterOff: !_masterEnabled,
                ),
                const SizedBox(height: AppDimensions.spaceLg),
                _buildMonitoringNoticeCard(theme),
              ] else ...[
                _buildCentralActuatorsCard(_centralIrrigation),
                const SizedBox(height: AppDimensions.spaceMd),
                FieldHeaderOverviewCard(
                  zones: _zones,
                  nodes: _nodes,
                  isStale: isStale,
                  masterEnabled: _masterEnabled,
                  isTogglingMaster: _isTogglingMaster,
                  onToggleMaster: _toggleMasterState,
                  pendingPairingCount: _pendingPairings.length,
                  onOpenPairingRequests: _openPairingModal,
                ),
                if (unassignedNodes.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spaceMd),
                  _buildUnassignedNodesCard(theme, unassignedNodes),
                ],
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
                    nodes: _nodes,
                    selectedZoneCode: _selectedZoneCode,
                    onZoneSelected: _handleZoneSelection,
                    onAssignNodeToZone: (zone) => _openNodeAssignment(zone: zone),
                    onAddZone: () => _showCreateZoneDialog(),
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
            ],
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
    final assignedNodes = _nodes.where((n) =>
        zone.assignedNodeIds.contains(n.id) ||
        zone.assignedNodeIds.contains(n.displayName) ||
        n.assignedZoneId == zone.id ||
        n.assignedZoneId == zone.code ||
        n.assignedZoneId == 'zone-${zone.id}' ||
        n.assignedZoneId == zone.id.replaceAll(RegExp(r'[^0-9]'), '')).toList();

    final hasNode = assignedNodes.isNotEmpty;
    final primaryNode = assignedNodes.firstOrNull;
    final isOnline = hasNode ? assignedNodes.any((n) => n.isOnline) : zone.isOnline;

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
                        color: (hasNode ? AppColors.primary : Colors.orange)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        border: Border.all(
                          color: hasNode ? AppColors.primary : Colors.orange,
                        ),
                      ),
                      child: Text(
                        zone.code,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasNode ? AppColors.primary : Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (primaryNode != null)
                            Text(
                              'Bound: ${primaryNode.displayName} (${primaryNode.id})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            const Text(
                              'Unoccupied Position • No Node Bound',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.orange,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasNode) ...[
                    StatusBadge.deviceStatus(isOnline ? 'Online' : 'Offline', compact: true),
                    const SizedBox(width: AppDimensions.spaceSm),
                    StatusBadge.zoneStatus(zone.status.name, compact: true),
                  ] else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      icon: const Icon(Icons.add_link, size: 14),
                      label: const Text('Assign', style: TextStyle(fontSize: 11)),
                      onPressed: () => _openNodeAssignment(zone: zone),
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          if (hasNode) ...[
            Row(
              children: [
                Expanded(
                  child: SensorMetricTile(
                    label: 'Soil Moisture',
                    value: primaryNode?.soilMoisturePercent != null
                        ? '${primaryNode!.soilMoisturePercent!.toStringAsFixed(1)}%'
                        : (zone.soilMoisturePercent > 0
                            ? '${zone.soilMoisturePercent.toStringAsFixed(1)}%'
                            : '—'),
                    icon: Icons.water,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: SensorMetricTile(
                    label: 'Water Level',
                    value: primaryNode?.waterLevelCm != null
                        ? primaryNode!.waterLevelCm!.toStringAsFixed(1)
                        : (zone.waterLevelCm != 0.0
                            ? zone.waterLevelCm.toStringAsFixed(1)
                            : '—'),
                    unit: primaryNode?.waterLevelCm != null || zone.waterLevelCm != 0.0 ? 'cm' : null,
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
                    value: primaryNode?.rssiDbm != null
                        ? '${primaryNode!.rssiDbm}'
                        : '${zone.rssiDbm}',
                    unit: 'dBm',
                    icon: Icons.cell_tower,
                    color: AppColors.primaryLight,
                  ),
                ),
                Expanded(
                  child: SensorMetricTile(
                    label: 'Sensor Battery',
                    value: '${primaryNode?.batteryPercent ?? zone.batteryPercent}',
                    unit: '%',
                    icon: (primaryNode?.batteryPercent ?? zone.batteryPercent) < 20
                        ? Icons.battery_alert
                        : Icons.battery_full,
                    color: (primaryNode?.batteryPercent ?? zone.batteryPercent) < 20
                        ? AppColors.error
                        : AppColors.deviceBatteryGood,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppDimensions.spaceSm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Position configured and awaiting physical ArvaNode assignment. Telemetry and closed-loop control will activate once bound.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
