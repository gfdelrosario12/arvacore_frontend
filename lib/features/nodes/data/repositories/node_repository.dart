import 'dart:async';
import '../../../../core/api/api_dtos.dart';
import '../../../zones/data/datasources/zone_data_source.dart';
import '../../../zones/domain/models/monitoring_zone.dart';
import '../../domain/models/models.dart';


abstract class NodeRepository {
  /// Fetch all registered nodes, optionally filtered by field, zone, or point
  Future<List<Esp32Node>> fetchNodes({String? fieldId, String? zoneId, String? pointId});

  /// Fetch discovered unassigned ESP32 nodes available for registration
  Future<List<NodeDiscoveryInfo>> fetchDiscoveredNodes();

  /// Fetch a single node by its ID
  Future<Esp32Node?> fetchNodeById(String id);

  /// Register a new ESP32 node and bind to field and zone
  Future<Esp32Node> registerNode(NodeRegistrationRequestDto request);

  /// Assign spatial coordinates and zone to an existing node
  Future<Esp32Node> assignSpatialCoordinates(
    String nodeId,
    NodeSpatialAssignmentDto assignment,
  );

  /// Update the transmission interval and mode for a node
  Future<TransmissionConfig> configureTransmissionInterval(
    String nodeId,
    TransmissionConfigDto config,
  );

  /// Replace a faulty/offline node with a newly commissioned node
  Future<Esp32Node> replaceNode({
    required String oldNodeId,
    required String newNodeId,
  });

  /// Transition lifecycle status of a node with transition validation
  Future<Esp32Node> transitionLifecycle({
    required String nodeId,
    required NodeLifecycleStatus targetStatus,
    String? reason,
    String? notes,
  });

  /// Replace an existing node with a new node atomically with audit preservation
  Future<NodeReplacementResult> executeNodeReplacement({
    required String oldNodeId,
    required String replacementNodeId,
    String? reason,
    bool transferCalibration = true,
  });

  /// Provision a discovered node with credentials and spatial binding
  Future<Esp32Node> provisionNode({
    required String nodeId,
    required NodeProvisioningRequestDto request,
  });

  /// Decommission a node permanently
  Future<bool> decommissionNode(String nodeId);

  /// Update mutable metadata (e.g. rename displayName or coordinates)
  Future<Esp32Node> updateNodeMetadata({
    required String nodeId,
    String? displayName,
    SpatialCoordinates? coordinates,
  });

  /// Stream of node list updates
  Stream<List<Esp32Node>> watchNodes();
}

class MockNodeRepository implements NodeRepository {
  final List<Esp32Node> _nodes;
  final List<NodeDiscoveryInfo> _discovered;
  final _controller = StreamController<List<Esp32Node>>.broadcast();

  MockNodeRepository({
    List<Esp32Node>? initialNodes,
    List<NodeDiscoveryInfo>? initialDiscovered,
  })  : _nodes = initialNodes ?? _generateSeedNodes(),
        _discovered = initialDiscovered ?? _generateSeedDiscovered();

  static List<Esp32Node> _generateSeedNodes() {
    final now = DateTime.now();
    return [
      Esp32Node(
        id: 'NODE-01',
        macAddress: 'A4:CF:12:89:33:01',
        displayName: 'Physical ESP32 Node 01 (Q1)',
        assignedFieldId: 'field-main',
        assignedZoneId: 'zone-q1',
        coordinates: const SpatialCoordinates(
          latitude: 14.1524,
          longitude: 121.2431,
          localX: 25.0,
          localY: 75.0,
          elevationMeters: 18.5,
        ),
        transmissionConfig: TransmissionConfig(
          intervalSeconds: 300,
          isAdaptive: false,
          lastConfiguredAt: now.subtract(const Duration(days: 2)),
        ),
        isOnline: true,
        batteryPercent: 95,
        batteryVoltage: 4.15,
        rssiDbm: -82,
        snrDb: 9.0,
        lastSeen: now.subtract(const Duration(minutes: 1)),
        soilMoisturePercent: 42.5,
        waterLevelCm: 5.2,
        temperatureCelsius: 28.4,
        humidityPercent: 78.0,
      ),
      Esp32Node(
        id: 'NODE-Q1',
        macAddress: 'A4:CF:12:89:33:01',
        displayName: 'North-East Field Node (Q1)',
        assignedFieldId: 'field-main',
        assignedZoneId: 'zone-q1',
        coordinates: const SpatialCoordinates(
          latitude: 14.1524,
          longitude: 121.2431,
          localX: 25.0,
          localY: 75.0,
          elevationMeters: 18.5,
        ),
        transmissionConfig: TransmissionConfig(
          intervalSeconds: 300,
          isAdaptive: false,
          lastConfiguredAt: now.subtract(const Duration(days: 2)),
        ),
        isOnline: true,
        batteryPercent: 92,
        batteryVoltage: 4.12,
        rssiDbm: -85,
        snrDb: 8.5,
        lastSeen: now.subtract(const Duration(minutes: 2)),
        soilMoisturePercent: 42.5,
        waterLevelCm: 5.2,
        temperatureCelsius: 28.4,
        humidityPercent: 78.0,
      ),
      Esp32Node(
        id: 'NODE-Q2',
        macAddress: 'A4:CF:12:89:33:02',
        displayName: 'North-West Field Node (Q2)',
        assignedFieldId: 'field-main',
        assignedZoneId: 'zone-q2',
        coordinates: const SpatialCoordinates(
          latitude: 14.1538,
          longitude: 121.2415,
          localX: 75.0,
          localY: 75.0,
          elevationMeters: 19.1,
        ),
        transmissionConfig: TransmissionConfig(
          intervalSeconds: 60,
          isAdaptive: true,
          adaptiveReason: 'RF signal degraded, reporting fallback',
          lastConfiguredAt: now.subtract(const Duration(hours: 4)),
        ),
        isOnline: true,
        batteryPercent: 68,
        batteryVoltage: 3.82,
        rssiDbm: -108,
        snrDb: 3.2,
        lastSeen: now.subtract(const Duration(minutes: 18)),
        soilMoisturePercent: 24.1,
        waterLevelCm: 2.1,
        temperatureCelsius: 30.1,
        humidityPercent: 65.0,
      ),
      Esp32Node(
        id: 'NODE-Q3',
        macAddress: 'A4:CF:12:89:33:03',
        displayName: 'South-East Field Node (Q3)',
        assignedFieldId: 'field-main',
        assignedZoneId: 'zone-q3',
        coordinates: const SpatialCoordinates(
          latitude: 14.1508,
          longitude: 121.2428,
          localX: 25.0,
          localY: 25.0,
          elevationMeters: 17.8,
        ),
        transmissionConfig: TransmissionConfig(
          intervalSeconds: 900,
          isAdaptive: true,
          adaptiveReason: 'Battery conservation mode active (<20%)',
          lastConfiguredAt: now.subtract(const Duration(hours: 1)),
        ),
        isOnline: true,
        batteryPercent: 15,
        batteryVoltage: 3.24,
        rssiDbm: -92,
        snrDb: 7.1,
        lastSeen: now.subtract(const Duration(minutes: 5)),
        soilMoisturePercent: 55.0,
        waterLevelCm: 7.8,
        temperatureCelsius: 27.2,
        humidityPercent: 82.5,
      ),
      Esp32Node(
        id: 'NODE-Q4',
        macAddress: 'A4:CF:12:89:33:04',
        displayName: 'South-West Field Node (Q4)',
        assignedFieldId: 'field-main',
        assignedZoneId: 'zone-q4',
        coordinates: const SpatialCoordinates(
          latitude: 14.1512,
          longitude: 121.2445,
          localX: 75.0,
          localY: 25.0,
          elevationMeters: 18.0,
        ),
        transmissionConfig: TransmissionConfig(
          intervalSeconds: 30,
          isAdaptive: true,
          adaptiveReason: 'Critical moisture threshold drop triggered rapid reporting',
          lastConfiguredAt: now.subtract(const Duration(minutes: 30)),
        ),
        isOnline: true,
        batteryPercent: 88,
        batteryVoltage: 4.02,
        rssiDbm: -88,
        snrDb: 8.0,
        lastSeen: now.subtract(const Duration(minutes: 3)),
        soilMoisturePercent: 14.8,
        waterLevelCm: 0.5,
        temperatureCelsius: 31.8,
        humidityPercent: 58.0,
      ),
    ];
  }

  static List<NodeDiscoveryInfo> _generateSeedDiscovered() {
    final now = DateTime.now();
    return [
      NodeDiscoveryInfo(
        id: 'DISC-ESP32-98F1',
        macAddress: 'A4:CF:12:98:F1:AA',
        hardwareModel: 'ArvaNode ESP32 Soil & Depth Node v2',
        firmwareVersion: 'v2.1.0',
        rssiDbm: -74,
        detectedAt: now.subtract(const Duration(minutes: 8)),
      ),
      NodeDiscoveryInfo(
        id: 'DISC-ESP32-B2C3',
        macAddress: 'A4:CF:12:B2:C3:44',
        hardwareModel: 'ArvaNode ESP32 Soil & Depth Node v2',
        firmwareVersion: 'v2.1.0',
        rssiDbm: -81,
        detectedAt: now.subtract(const Duration(minutes: 2)),
      ),
    ];
  }

  @override
  Future<List<Esp32Node>> fetchNodes({String? fieldId, String? zoneId, String? pointId}) async {
    var results = List<Esp32Node>.from(_nodes);
    if (fieldId != null) {
      results = results.where((n) => n.assignedFieldId == fieldId).toList();
    }
    if (zoneId != null) {
      results = results.where((n) => n.assignedZoneId == zoneId).toList();
    }
    if (pointId != null) {
      results = results.where((n) => n.assignedPointId == pointId).toList();
    }
    return results;
  }

  @override
  Future<List<NodeDiscoveryInfo>> fetchDiscoveredNodes() async {
    return List.unmodifiable(_discovered);
  }

  @override
  Future<Esp32Node?> fetchNodeById(String id) async {
    try {
      return _nodes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Esp32Node> registerNode(NodeRegistrationRequestDto request) async {
    final id = 'NODE-${request.macAddress.replaceAll(':', '').toUpperCase().substring(6)}';
    final newNode = Esp32Node(
      id: id,
      macAddress: request.macAddress,
      displayName: request.displayName,
      assignedFieldId: request.fieldId,
      assignedZoneId: request.zoneId,
      coordinates: SpatialCoordinates(
        latitude: request.latitude,
        longitude: request.longitude,
        localX: request.localX,
        localY: request.localY,
      ),
      transmissionConfig: TransmissionConfig(
        intervalSeconds: request.transmissionIntervalSeconds,
        isAdaptive: false,
        lastConfiguredAt: DateTime.now(),
      ),
      isOnline: true,
      batteryPercent: 100,
      batteryVoltage: 4.20,
      rssiDbm: -70,
      snrDb: 10.0,
      lastSeen: DateTime.now(),
      soilMoisturePercent: 45.0,
      waterLevelCm: 4.0,
      temperatureCelsius: 28.0,
      humidityPercent: 70.0,
    );
    _nodes.add(newNode);
    _discovered.removeWhere((d) => d.macAddress == request.macAddress);

    if (!const {'zone-q1', 'zone-q2', 'zone-q3', 'zone-q4'}.contains(request.zoneId)) {
      final code = request.zoneId.replaceAll('zone-', '').toUpperCase();
      MockZoneDataSource.addCustomZone(
        MonitoringZone(
          id: request.zoneId,
          code: code.length > 5 ? code.substring(0, 5) : code,
          name: '${request.displayName} Zone',
          soilMoisturePercent: 45.0,
          waterLevelCm: 4.0,
          temperatureCelsius: 28.0,
          humidityPercent: 70.0,
          batteryPercent: 100,
          status: ZoneStatus.optimal,
          lastUpdated: DateTime.now(),
          isOnline: true,
          rssiDbm: -70,
          snrDb: 10.0,
          assignedNodeIds: [id],
          coordinates: SpatialCoordinates(
            latitude: request.latitude,
            longitude: request.longitude,
            localX: request.localX,
            localY: request.localY,
          ),
          transmissionConfig: TransmissionConfig(
            intervalSeconds: request.transmissionIntervalSeconds,
            isAdaptive: false,
            lastConfiguredAt: DateTime.now(),
          ),
        ),
      );
    }

    _controller.add(List.unmodifiable(_nodes));
    return newNode;
  }

  @override
  Future<Esp32Node> assignSpatialCoordinates(
    String nodeId,
    NodeSpatialAssignmentDto assignment,
  ) async {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index == -1) {
      throw Exception('Node $nodeId not found.');
    }
    final current = _nodes[index];
    final updated = current.copyWith(
      assignedFieldId: assignment.fieldId,
      assignedZoneId: assignment.zoneId,
      coordinates: SpatialCoordinates(
        latitude: assignment.latitude ?? current.coordinates?.latitude,
        longitude: assignment.longitude ?? current.coordinates?.longitude,
        localX: assignment.localX ?? current.coordinates?.localX,
        localY: assignment.localY ?? current.coordinates?.localY,
        elevationMeters: current.coordinates?.elevationMeters,
      ),
    );
    _nodes[index] = updated;
    _controller.add(List.unmodifiable(_nodes));
    return updated;
  }

  @override
  Future<TransmissionConfig> configureTransmissionInterval(
    String nodeId,
    TransmissionConfigDto config,
  ) async {
    final index = _nodes.indexWhere((n) => n.id == nodeId);
    if (index == -1) {
      throw Exception('Node $nodeId not found.');
    }
    final current = _nodes[index];
    final updatedConfig = TransmissionConfig(
      intervalSeconds: config.intervalSeconds,
      isAdaptive: config.isAdaptive,
      adaptiveReason: config.reason,
      lastConfiguredAt: DateTime.now(),
    );
    _nodes[index] = current.copyWith(transmissionConfig: updatedConfig);
    _controller.add(List.unmodifiable(_nodes));
    return updatedConfig;
  }

  @override
  Future<Esp32Node> transitionLifecycle({
    required String nodeId,
    required NodeLifecycleStatus targetStatus,
    String? reason,
    String? notes,
  }) async {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx == -1) {
      throw Exception('Node $nodeId not found.');
    }
    final current = _nodes[idx];
    if (!current.lifecycleState.canTransitionTo(targetStatus)) {
      throw StateError(
        'Invalid lifecycle transition from ${current.lifecycleState.name} to ${targetStatus.name}.',
      );
    }

    final updated = current.copyWith(
      lifecycleState: targetStatus,
      assignedZoneId: targetStatus == NodeLifecycleStatus.decommissioned
          ? null
          : current.assignedZoneId,
      assignedPointId: targetStatus == NodeLifecycleStatus.decommissioned
          ? null
          : current.assignedPointId,
    );
    _nodes[idx] = updated;
    _controller.add(List.unmodifiable(_nodes));
    return updated;
  }

  @override
  Future<NodeReplacementResult> executeNodeReplacement({
    required String oldNodeId,
    required String replacementNodeId,
    String? reason,
    bool transferCalibration = true,
  }) async {
    final oldIdx = _nodes.indexWhere((n) => n.id == oldNodeId);
    final newIdx = _nodes.indexWhere((n) => n.id == replacementNodeId);
    if (oldIdx == -1 || newIdx == -1) {
      throw Exception('Node not found for replacement.');
    }
    final oldNode = _nodes[oldIdx];
    final newNode = _nodes[newIdx];
    final now = DateTime.now();

    final retiredOldNode = oldNode.copyWith(
      assignedPointId: null,
      lifecycleState: NodeLifecycleStatus.replaced,
      replacedByNodeId: newNode.id,
      replacedAt: now,
      isOnline: false,
    );
    final activatedNewNode = newNode.copyWith(
      assignedFieldId: oldNode.assignedFieldId,
      assignedZoneId: oldNode.assignedZoneId,
      assignedPointId: oldNode.assignedPointId,
      coordinates: oldNode.coordinates,
      lifecycleState: NodeLifecycleStatus.active,
      replacesNodeId: oldNode.id,
      isOnline: true,
      soilMoisturePercent: oldNode.soilMoisturePercent,
      waterLevelCm: oldNode.waterLevelCm,
      temperatureCelsius: oldNode.temperatureCelsius,
      humidityPercent: oldNode.humidityPercent,
    );

    _nodes[oldIdx] = retiredOldNode;
    _nodes[newIdx] = activatedNewNode;
    _controller.add(List.unmodifiable(_nodes));

    return NodeReplacementResult(
      oldNodeId: oldNode.id,
      replacementNodeId: newNode.id,
      fieldId: oldNode.assignedFieldId ?? 'field-main',
      zoneId: oldNode.assignedZoneId ?? 'zone-q1',
      monitoringPointId: oldNode.assignedPointId,
      replacedAt: now,
      reason: reason,
      historicalMeasurementsPreserved: true,
      updatedReplacementNode: activatedNewNode,
      retiredNode: retiredOldNode,
    );
  }

  @override
  Future<Esp32Node> replaceNode({
    required String oldNodeId,
    required String newNodeId,
  }) async {
    final result = await executeNodeReplacement(
      oldNodeId: oldNodeId,
      replacementNodeId: newNodeId,
    );
    return result.updatedReplacementNode;
  }

  @override
  Future<Esp32Node> provisionNode({
    required String nodeId,
    required NodeProvisioningRequestDto request,
  }) async {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx == -1) {
      throw Exception('Node $nodeId not found.');
    }
    final current = _nodes[idx];
    final updated = current.copyWith(
      lifecycleState: NodeLifecycleStatus.provisioned,
      commissioningToken: request.commissioningToken,
      assignedFieldId: request.fieldId,
      assignedZoneId: request.zoneId ?? current.assignedZoneId,
      assignedPointId: request.monitoringPointId ?? current.assignedPointId,
      coordinates: (request.latitude != null || request.localX != null)
          ? SpatialCoordinates(
              latitude: request.latitude,
              longitude: request.longitude,
              localX: request.localX,
              localY: request.localY,
            )
          : current.coordinates,
      commissionedAt: DateTime.now(),
    );
    _nodes[idx] = updated;
    _controller.add(List.unmodifiable(_nodes));
    return updated;
  }

  @override
  Future<bool> decommissionNode(String nodeId) async {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx == -1) return false;
    _nodes[idx] = _nodes[idx].copyWith(
      lifecycleState: NodeLifecycleStatus.decommissioned,
      assignedZoneId: null,
      assignedPointId: null,
    );
    _controller.add(List.unmodifiable(_nodes));
    return true;
  }

  @override
  Future<Esp32Node> updateNodeMetadata({
    required String nodeId,
    String? displayName,
    SpatialCoordinates? coordinates,
  }) async {
    final idx = _nodes.indexWhere((n) => n.id == nodeId);
    if (idx == -1) {
      throw Exception('Node $nodeId not found.');
    }
    final current = _nodes[idx];
    final updated = current.copyWith(
      displayName: displayName ?? current.displayName,
      coordinates: coordinates ?? current.coordinates,
    );
    _nodes[idx] = updated;
    _controller.add(List.unmodifiable(_nodes));
    return updated;
  }

  @override
  Stream<List<Esp32Node>> watchNodes() => _controller.stream;

  void updateNode(Esp32Node updated) {
    final index = _nodes.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      _nodes[index] = updated;
      _controller.add(List.unmodifiable(_nodes));
    }
  }
}

