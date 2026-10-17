import 'dart:async';
import '../../../../core/api/api_dtos.dart';
import '../../../../core/api/api_mappers.dart';
import '../../../../core/api/api_services.dart';
import '../../domain/models/models.dart';
import 'node_repository.dart';

class ApiNodeRepository implements NodeRepository {
  final NodeApiService api;

  ApiNodeRepository(this.api);

  @override
  Future<List<Esp32Node>> fetchNodes({
    String? fieldId,
    String? zoneId,
    String? pointId,
  }) async {
    final response = await api.listNodes(fieldId: fieldId, zoneId: zoneId);
    var nodes = response.items.map(ApiMappers.esp32Node);
    if (pointId != null) {
      nodes = nodes.where((n) => n.assignedPointId == pointId);
    }
    return nodes.toList(growable: false);
  }

  @override
  Future<NodeReplacementResult> executeNodeReplacement({
    required String oldNodeId,
    required String replacementNodeId,
    String? reason,
    bool transferCalibration = true,
  }) async {
    final response = await api.replaceNode(
      oldNodeId,
      NodeReplacementRequestDto(
        replacementNodeId: replacementNodeId,
        reason: reason,
        transferCalibration: transferCalibration,
      ),
    );
    return ApiMappers.nodeReplacementResult(response);
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
  Future<Esp32Node> transitionLifecycle({
    required String nodeId,
    required NodeLifecycleStatus targetStatus,
    String? reason,
    String? notes,
  }) async {
    final response = await api.updateLifecycle(
      nodeId,
      NodeLifecycleUpdateDto(
        state: targetStatus.name,
        reason: reason,
        notes: notes,
      ),
    );
    return ApiMappers.esp32Node(response);
  }

  @override
  Future<Esp32Node> provisionNode({
    required String nodeId,
    required NodeProvisioningRequestDto request,
  }) async {
    final response = await api.provisionNode(nodeId, request);
    return ApiMappers.esp32Node(response);
  }

  @override
  Future<bool> decommissionNode(String nodeId) async {
    return await api.decommissionNode(nodeId);
  }

  @override
  Future<Esp32Node> updateNodeMetadata({
    required String nodeId,
    String? displayName,
    SpatialCoordinates? coordinates,
  }) async {
    final response = await api.updateNode(nodeId, {
      if (displayName != null) 'displayName': displayName,
      if (coordinates != null) 'coordinates': coordinates.toJson(),
    });
    return ApiMappers.esp32Node(response);
  }

  @override
  Future<List<NodeDiscoveryInfo>> fetchDiscoveredNodes() async {
    final response = await api.listDiscoveredNodes();
    return response.items
        .map(ApiMappers.nodeDiscoveryInfo)
        .toList(growable: false);
  }

  @override
  Future<Esp32Node?> fetchNodeById(String id) async {
    final response = await api.getNode(id);
    return ApiMappers.esp32Node(response);
  }

  @override
  Future<Esp32Node> registerNode(NodeRegistrationRequestDto request) async {
    final response = await api.registerNode(request);
    return ApiMappers.esp32Node(response);
  }

  @override
  Future<Esp32Node> assignSpatialCoordinates(
    String nodeId,
    NodeSpatialAssignmentDto assignment,
  ) async {
    final response = await api.assignSpatial(nodeId, assignment);
    return ApiMappers.esp32Node(response);
  }

  @override
  Future<TransmissionConfig> configureTransmissionInterval(
    String nodeId,
    TransmissionConfigDto config,
  ) async {
    final response = await api.configureTransmissionInterval(nodeId, config);
    return ApiMappers.transmissionConfig(response.data);
  }

  @override
  Future<Esp32Node> assignNodeToField(
    String nodeId, {
    int? fieldId,
    int? monitoringZoneId,
  }) async {
    final response = await api.assignNodeToField(
      nodeId,
      fieldId: fieldId,
      monitoringZoneId: monitoringZoneId,
    );
    return ApiMappers.esp32Node(response);
  }

  @override
  Stream<List<Esp32Node>> watchNodes() => const Stream.empty();
}

