import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/api/api_dtos.dart';
import '../../../../core/realtime/realtime_coordinator.dart';
import '../../../../core/realtime/realtime_events.dart';
import '../../../control/domain/models/control_enums.dart';
import '../../../../core/api/api_factory.dart';
import '../../data/repositories/api_node_repository.dart';
import '../../data/repositories/node_repository.dart';
import '../../domain/models/models.dart';

class NodeManagementStateData {
  final List<Esp32Node> nodes;
  final List<NodeDiscoveryInfo> discoveredNodes;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final Esp32Node? selectedNode;
  final String? selectedZoneFilter;
  final ControlUserRole userRole;

  const NodeManagementStateData({
    this.nodes = const [],
    this.discoveredNodes = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.selectedNode,
    this.selectedZoneFilter,
    this.userRole = ControlUserRole.operator,
  });

  int get totalNodes => nodes.length;
  int get onlineCount => nodes.where((n) => n.isOnline).length;
  int get offlineCount => nodes.where((n) => !n.isOnline).length;
  int get adaptiveCount =>
      nodes.where((n) => n.transmissionConfig.isAdaptive).length;

  bool get isAuthorizedForMutation =>
      userRole == ControlUserRole.admin || userRole == ControlUserRole.operator;

  List<Esp32Node> get filteredNodes {
    if (selectedZoneFilter == null) return nodes;
    return nodes.where((n) => n.assignedZoneId == selectedZoneFilter).toList();
  }

  List<Esp32Node> nodesForZone(String zoneId) =>
      nodes.where((n) => n.assignedZoneId == zoneId).toList();

  NodeManagementStateData copyWith({
    List<Esp32Node>? nodes,
    List<NodeDiscoveryInfo>? discoveredNodes,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    Esp32Node? selectedNode,
    bool clearSelectedNode = false,
    String? selectedZoneFilter,
    bool clearZoneFilter = false,
    ControlUserRole? userRole,
  }) {
    return NodeManagementStateData(
      nodes: nodes ?? this.nodes,
      discoveredNodes: discoveredNodes ?? this.discoveredNodes,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedNode:
          clearSelectedNode ? null : (selectedNode ?? this.selectedNode),
      selectedZoneFilter:
          clearZoneFilter ? null : (selectedZoneFilter ?? this.selectedZoneFilter),
      userRole: userRole ?? this.userRole,
    );
  }
}

class NodeManagementNotifier extends ChangeNotifier {
  final NodeRepository _repository;
  final RealtimeCoordinator? _realtimeCoordinator;
  NodeManagementStateData _state = const NodeManagementStateData();
  StreamSubscription<List<Esp32Node>>? _nodeSubscription;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  bool _isDisposed = false;

  NodeManagementNotifier({
    NodeRepository? repository,
    RealtimeCoordinator? realtimeCoordinator,
  })  : _repository =
            repository ?? ApiNodeRepository(ApiRepositoryFactory().nodes),
        _realtimeCoordinator = realtimeCoordinator {
    _init();
  }

  NodeManagementStateData get state => _state;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void _init() {
    fetchNodes();
    fetchDiscoveredNodes();
    _nodeSubscription = _repository.watchNodes().listen((nodes) {
      _state = _state.copyWith(nodes: nodes);
      notifyListeners();
    });

    if (_realtimeCoordinator != null) {
      _realtimeSubscription =
          _realtimeCoordinator.events.listen(handleRealtimeEvent);
    }
  }

  Future<void> fetchNodes() async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();
    try {
      final nodes = await _repository.fetchNodes();
      _state = _state.copyWith(nodes: nodes, isLoading: false);
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to fetch ESP32 nodes: $e',
      );
    }
    notifyListeners();
  }

  Future<void> fetchDiscoveredNodes() async {
    try {
      final discovered = await _repository.fetchDiscoveredNodes();
      _state = _state.copyWith(discoveredNodes: discovered);
      notifyListeners();
    } catch (_) {}
  }

  void selectNode(Esp32Node? node) {
    if (node == null) {
      _state = _state.copyWith(clearSelectedNode: true);
    } else {
      _state = _state.copyWith(selectedNode: node);
    }
    notifyListeners();
  }

  void setZoneFilter(String? zoneId) {
    if (zoneId == null) {
      _state = _state.copyWith(clearZoneFilter: true);
    } else {
      _state = _state.copyWith(selectedZoneFilter: zoneId);
    }
    notifyListeners();
  }

  void setUserRole(ControlUserRole role) {
    _state = _state.copyWith(userRole: role);
    notifyListeners();
  }

  bool _checkAuthorized(ControlUserRole? role, String actionDescription) {
    final effectiveRole = role ?? _state.userRole;
    if (effectiveRole == ControlUserRole.viewer) {
      _state = _state.copyWith(
        errorMessage: 'Unauthorized: Viewers cannot $actionDescription.',
        isSubmitting: false,
      );
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> registerNode(
    NodeRegistrationRequestDto request, {
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'register sensor nodes')) {
      return false;
    }
    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final newNode = await _repository.registerNode(request);
      final updatedList = List<Esp32Node>.from(_state.nodes)..add(newNode);
      final updatedDiscovered = _state.discoveredNodes
          .where((d) => d.macAddress != request.macAddress)
          .toList();
      _state = _state.copyWith(
        nodes: updatedList,
        discoveredNodes: updatedDiscovered,
        isSubmitting: false,
        selectedNode: newNode,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Node registration failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignSpatial(
    String nodeId,
    NodeSpatialAssignmentDto assignment, {
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'assign spatial coordinates')) {
      return false;
    }
    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final updatedNode =
          await _repository.assignSpatialCoordinates(nodeId, assignment);
      final updatedNodes = _state.nodes.map((n) {
        return n.id == nodeId ? updatedNode : n;
      }).toList();
      _state = _state.copyWith(
        nodes: updatedNodes,
        selectedNode: updatedNode,
        isSubmitting: false,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Spatial assignment failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> configureTransmissionInterval(
    String nodeId,
    int intervalSeconds, {
    bool isAdaptive = false,
    String? reason,
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'configure transmission intervals')) {
      return false;
    }
    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final config = await _repository.configureTransmissionInterval(
        nodeId,
        TransmissionConfigDto(
          intervalSeconds: intervalSeconds,
          isAdaptive: isAdaptive,
          reason: reason,
        ),
      );
      final updatedNodes = _state.nodes.map((n) {
        if (n.id == nodeId) {
          return n.copyWith(transmissionConfig: config);
        }
        return n;
      }).toList();
      _state = _state.copyWith(
        nodes: updatedNodes,
        selectedNode: _state.selectedNode?.id == nodeId
            ? _state.selectedNode?.copyWith(transmissionConfig: config)
            : _state.selectedNode,
        isSubmitting: false,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Interval configuration failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> transitionLifecycle(
    String nodeId,
    NodeLifecycleStatus targetStatus, {
    String? reason,
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'modify node lifecycle state')) {
      return false;
    }

    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final updatedNode = await _repository.transitionLifecycle(
        nodeId: nodeId,
        targetStatus: targetStatus,
        reason: reason,
      );
      final updatedNodes = _state.nodes.map((n) {
        return n.id == nodeId ? updatedNode : n;
      }).toList();
      _state = _state.copyWith(
        nodes: updatedNodes,
        selectedNode: _state.selectedNode?.id == nodeId
            ? updatedNode
            : _state.selectedNode,
        isSubmitting: false,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Lifecycle transition failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  Future<NodeReplacementResult?> executeNodeReplacement(
    String targetNodeId,
    NodeReplacementRequestDto request, {
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'replace sensor nodes')) {
      return null;
    }

    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final result = await _repository.executeNodeReplacement(
        oldNodeId: targetNodeId,
        replacementNodeId: request.replacementNodeId,
        reason: request.reason,
        transferCalibration: request.transferCalibration,
      );
      final updatedNodes = _state.nodes.map((n) {
        if (n.id == result.replacedNode.id) return result.replacedNode;
        if (n.id == result.activeNode.id) return result.activeNode;
        return n;
      }).toList();

      if (!updatedNodes.any((n) => n.id == result.activeNode.id)) {
        updatedNodes.add(result.activeNode);
      }

      _state = _state.copyWith(
        nodes: updatedNodes,
        selectedNode: _state.selectedNode?.id == targetNodeId
            ? result.activeNode
            : (_state.selectedNode?.id == result.activeNode.id
                ? result.activeNode
                : _state.selectedNode),
        isSubmitting: false,
      );
      notifyListeners();
      return result;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Node replacement failed: $e',
      );
      notifyListeners();
      return null;
    }
  }

  Future<bool> replaceNode(
    String oldNodeId,
    String newNodeId, {
    String? reason,
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'replace sensor nodes')) {
      return false;
    }

    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final activeNode = await _repository.replaceNode(
        oldNodeId: oldNodeId,
        newNodeId: newNodeId,
      );
      await fetchNodes();
      _state = _state.copyWith(
        selectedNode: activeNode,
        isSubmitting: false,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Node replacement failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> provisionNode(
    String nodeId,
    NodeProvisioningRequestDto request, {
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'provision sensor nodes')) {
      return false;
    }

    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final provisioned = await _repository.provisionNode(
        nodeId: nodeId,
        request: request,
      );
      final updatedNodes = _state.nodes.map((n) {
        return n.id == nodeId ? provisioned : n;
      }).toList();
      if (!updatedNodes.any((n) => n.id == nodeId)) {
        updatedNodes.add(provisioned);
      }
      _state = _state.copyWith(
        nodes: updatedNodes,
        selectedNode: _state.selectedNode?.id == nodeId
            ? provisioned
            : _state.selectedNode,
        isSubmitting: false,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Node provisioning failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> decommissionNode(
    String nodeId, {
    String? reason,
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'decommission sensor nodes')) {
      return false;
    }

    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final success = await _repository.decommissionNode(nodeId);
      if (success) {
        final updatedNodes = _state.nodes.map((n) {
          if (n.id == nodeId) {
            return n.copyWith(
              lifecycleStatus: NodeLifecycleStatus.decommissioned,
              isOnline: false,
            );
          }
          return n;
        }).toList();
        _state = _state.copyWith(
          nodes: updatedNodes,
          selectedNode: _state.selectedNode?.id == nodeId
              ? _state.selectedNode?.copyWith(
                  lifecycleStatus: NodeLifecycleStatus.decommissioned,
                  isOnline: false,
                )
              : _state.selectedNode,
          isSubmitting: false,
        );
      } else {
        _state = _state.copyWith(isSubmitting: false);
      }
      notifyListeners();
      return success;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Node decommissioning failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> unpairNode(
    String nodeId, {
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'unpair sensor nodes')) {
      return false;
    }

    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final success = await _repository.unpairNode(nodeId);
      if (success) {
        await fetchNodes();
        await fetchDiscoveredNodes();
        _state = _state.copyWith(
          isSubmitting: false,
          clearSelectedNode: _state.selectedNode?.id == nodeId,
        );
      } else {
        _state = _state.copyWith(isSubmitting: false);
      }
      notifyListeners();
      return success;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Node unpairing failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeNodeFromField(
    String nodeId, {
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'manage field assignments')) {
      return false;
    }

    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final success = await _repository.removeNodeFromField(nodeId);
      if (success) {
        await fetchNodes();
        _state = _state.copyWith(isSubmitting: false);
      } else {
        _state = _state.copyWith(isSubmitting: false);
      }
      notifyListeners();
      return success;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Removing node from field failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPairingState({
    List<String>? nodeIds,
    String? reason,
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'reset node pairings')) {
      return false;
    }

    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final success = await _repository.resetPairingState(nodeIds: nodeIds, reason: reason);
      if (success) {
        await fetchNodes();
        await fetchDiscoveredNodes();
        _state = _state.copyWith(
          isSubmitting: false,
          clearSelectedNode: true,
        );
      } else {
        _state = _state.copyWith(isSubmitting: false);
      }
      notifyListeners();
      return success;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Pairing reset failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> renameNode(
    String nodeId,
    String newLabel, {
    ControlUserRole? userRole,
  }) async {
    if (!_checkAuthorized(userRole, 'rename sensor nodes')) {
      return false;
    }

    _state = _state.copyWith(isSubmitting: true, clearError: true);
    notifyListeners();
    try {
      final updatedNode = await _repository.updateNodeMetadata(
        nodeId: nodeId,
        displayName: newLabel,
      );
      final updatedNodes = _state.nodes.map((n) {
        return n.id == nodeId ? updatedNode : n;
      }).toList();
      _state = _state.copyWith(
        nodes: updatedNodes,
        selectedNode: _state.selectedNode?.id == nodeId
            ? updatedNode
            : _state.selectedNode,
        isSubmitting: false,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isSubmitting: false,
        errorMessage: 'Node rename failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  void handleRealtimeEvent(RealtimeEvent event) {
    final payload = event.payload;
    final targetId = payload['nodeId']?.toString() ?? event.scope;

    if (event.type == RealtimeEventType.transmissionIntervalUpdated) {
      final interval = int.tryParse(payload['intervalSeconds']?.toString() ??
              payload['interval']?.toString() ??
              '') ??
          300;
      final isAdaptive = payload['isAdaptive'] as bool? ?? true;
      final reason = payload['reason']?.toString() ??
          payload['adaptiveReason']?.toString() ??
          'Adaptive trigger';

      final updatedNodes = _state.nodes.map((node) {
        if (node.id == targetId || node.macAddress == targetId) {
          return node.copyWith(
            transmissionConfig: TransmissionConfig(
              intervalSeconds: interval,
              isAdaptive: isAdaptive,
              adaptiveReason: reason,
              lastConfiguredAt: event.occurredAt,
            ),
          );
        }
        return node;
      }).toList();

      _state = _state.copyWith(nodes: updatedNodes);
      notifyListeners();
    } else if (event.type == RealtimeEventType.measurement) {
      final moisture = double.tryParse(payload['soilMoisture']?.toString() ??
          payload['soilMoisturePercent']?.toString() ??
          '');
      final water = double.tryParse(payload['waterLevel']?.toString() ??
          payload['waterLevelCm']?.toString() ??
          '');
      final temp = double.tryParse(payload['temperature']?.toString() ??
          payload['temperatureCelsius']?.toString() ??
          '');
      final hum = double.tryParse(payload['humidity']?.toString() ??
          payload['humidityPercent']?.toString() ??
          '');

      final updatedNodes = _state.nodes.map((node) {
        if (node.id == targetId || node.assignedZoneId == targetId) {
          return node.copyWith(
            soilMoisturePercent: moisture ?? node.soilMoisturePercent,
            waterLevelCm: water ?? node.waterLevelCm,
            temperatureCelsius: temp ?? node.temperatureCelsius,
            humidityPercent: hum ?? node.humidityPercent,
            lastSeen: event.occurredAt,
          );
        }
        return node;
      }).toList();

      _state = _state.copyWith(nodes: updatedNodes);
      notifyListeners();
    } else if (event.type == RealtimeEventType.nodeStatus ||
        event.type == RealtimeEventType.sensorStatus) {
      final isOnline = payload['isOnline'] as bool? ?? true;
      final battery = int.tryParse(payload['batteryPercent']?.toString() ?? '');
      final rssi = int.tryParse(payload['rssiDbm']?.toString() ?? '');

      final updatedNodes = _state.nodes.map((node) {
        if (node.id == targetId) {
          return node.copyWith(
            isOnline: isOnline,
            batteryPercent: battery ?? node.batteryPercent,
            rssiDbm: rssi ?? node.rssiDbm,
            lastSeen: event.occurredAt,
          );
        }
        return node;
      }).toList();

      _state = _state.copyWith(nodes: updatedNodes);
      notifyListeners();
    } else if (event.type == RealtimeEventType.nodeDiscovered) {
      final newDiscovery = NodeDiscoveryInfo(
        id: payload['id']?.toString() ?? 'DISC-${event.sequence}',
        macAddress: payload['macAddress']?.toString() ?? '',
        hardwareModel: payload['hardwareModel']?.toString() ?? 'ESP32 Node',
        firmwareVersion: payload['firmwareVersion']?.toString() ?? '1.0.0',
        rssiDbm: int.tryParse(payload['rssiDbm']?.toString() ?? '') ?? -85,
        detectedAt: event.occurredAt,
      );

      final exists = _state.discoveredNodes
          .any((d) => d.macAddress == newDiscovery.macAddress);
      if (!exists && newDiscovery.macAddress.isNotEmpty) {
        _state = _state.copyWith(
          discoveredNodes: [..._state.discoveredNodes, newDiscovery],
        );
        notifyListeners();
      }
    } else if (event.type == RealtimeEventType.nodeLifecycleUpdated) {
      final statusStr = payload['status']?.toString() ??
          payload['lifecycleStatus']?.toString();

      if (statusStr?.toUpperCase() == 'UNREGISTERED' ||
          statusStr?.toUpperCase() == 'REVOKED') {
        final updatedNodes = _state.nodes
            .where((node) => node.id != targetId && node.macAddress != targetId)
            .toList();
        _state = _state.copyWith(
          nodes: updatedNodes,
          clearSelectedNode: _state.selectedNode?.id == targetId ||
              _state.selectedNode?.macAddress == targetId,
        );
        fetchDiscoveredNodes();
        notifyListeners();
        return;
      }

      final newStatus = NodeLifecycleStatus.values
          .cast<NodeLifecycleStatus?>()
          .firstWhere(
            (s) => s?.name.toLowerCase() == statusStr?.toLowerCase(),
            orElse: () => null,
          );

      if (newStatus != null) {
        final updatedNodes = _state.nodes.map((node) {
          if (node.id == targetId || node.macAddress == targetId) {
            return node.copyWith(
              lifecycleStatus: newStatus,
              isOnline: newStatus == NodeLifecycleStatus.active
                  ? true
                  : (newStatus.isRetired ? false : node.isOnline),
              lastSeen: event.occurredAt,
            );
          }
          return node;
        }).toList();

        _state = _state.copyWith(
          nodes: updatedNodes,
          selectedNode: (_state.selectedNode?.id == targetId ||
                  _state.selectedNode?.macAddress == targetId)
              ? _state.selectedNode?.copyWith(
                  lifecycleStatus: newStatus,
                  isOnline: newStatus == NodeLifecycleStatus.active
                      ? true
                      : (newStatus.isRetired
                          ? false
                          : _state.selectedNode?.isOnline),
                  lastSeen: event.occurredAt,
                )
              : _state.selectedNode,
        );
        notifyListeners();
      }
    } else if (event.type == RealtimeEventType.nodeReplaced) {
      final oldId = payload['oldNodeId']?.toString() ??
          payload['targetNodeId']?.toString() ??
          targetId;
      final newId = payload['newNodeId']?.toString() ??
          payload['replacementNodeId']?.toString() ??
          payload['activeNodeId']?.toString();
      final zoneId = payload['zoneId']?.toString() ??
          payload['monitoringPointId']?.toString();

      final updatedNodes = _state.nodes.map((node) {
        if (node.id == oldId) {
          return node.copyWith(
            lifecycleStatus: NodeLifecycleStatus.replaced,
            replacedByNodeId: newId,
            replacedAt: event.occurredAt,
            isOnline: false,
          );
        }
        if (node.id == newId) {
          return node.copyWith(
            lifecycleStatus: NodeLifecycleStatus.active,
            replacesNodeId: oldId,
            assignedZoneId: zoneId ?? node.assignedZoneId,
            isOnline: true,
          );
        }
        return node;
      }).toList();

      _state = _state.copyWith(nodes: updatedNodes);
      if (_state.selectedNode?.id == oldId && newId != null) {
        final replacementNode = updatedNodes
            .cast<Esp32Node?>()
            .firstWhere((n) => n?.id == newId, orElse: () => null);
        if (replacementNode != null) {
          _state = _state.copyWith(selectedNode: replacementNode);
        }
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _nodeSubscription?.cancel();
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}

