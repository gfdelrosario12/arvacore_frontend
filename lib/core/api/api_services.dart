import 'api_client.dart';
import 'api_dtos.dart';
import 'api_errors.dart';

class AuthApiService {
  final ApiClient client;

  const AuthApiService(this.client);

  Future<AuthResponseDto> login({required String identifier, required String password}) async {
    final response = await client.post(
      '/api/auth/login',
      authorized: false,
      body: {
        'username': identifier,
        'identifier': identifier,
        'password': password,
      },
    );
    return AuthResponseDto.fromJson(response);
  }

  Future<void> logout() async {
    await client.post('/api/auth/logout');
  }
}

class FieldApiService {
  final ApiClient client;

  const FieldApiService(this.client);

  Future<ResourceListDto> listFields() async =>
      ResourceListDto.fromJson(await client.get('/api/fields'));

  Future<ResourceDto> getField(String id) async =>
      ResourceDto.fromJson(await client.get('/api/fields/$id'));

  Future<ResourceDto> updateField(String id, Map<String, dynamic> body) async =>
      ResourceDto.fromJson(await client.put('/api/fields/$id', body: body));

  Future<void> deleteField(String id) async {
    final cleanId = id.replaceAll(RegExp(r'[^0-9]'), '');
    final effectiveId = cleanId.isEmpty ? id : cleanId;
    await client.delete('/api/fields/$effectiveId');
  }

  Future<ResourceListDto> listQuarters({String? fieldId}) async {
    final targetFieldId = (fieldId != null && fieldId.isNotEmpty)
        ? fieldId.replaceAll(RegExp(r'[^0-9]'), '')
        : '1';
    final effectiveFieldId = targetFieldId.isEmpty ? '1' : targetFieldId;

    try {
      final fieldZones = await client.get('/api/fields/$effectiveFieldId/zones');
      if (fieldZones is List && fieldZones.isNotEmpty) {
        return ResourceListDto.fromJson(fieldZones);
      }
    } catch (_) {}

    try {
      final res = await client.get('/api/zones/all');
      return ResourceListDto.fromJson(res);
    } catch (_) {
      try {
        final topo = await client.get('/api/fields/$effectiveFieldId/topology');
        if (topo is Map && topo['zones'] is List) {
          return ResourceListDto.fromJson(topo['zones']);
        }
      } catch (_) {}
      return ResourceListDto.fromJson(await client.get('/api/quarters'));
    }
  }

  Future<ResourceDto> getQuarter(String id) async =>
      ResourceDto.fromJson(await client.get('/api/quarters/$id'));

  Future<ResourceDto> createZone({
    required String name,
    required double area,
    required String cropType,
    double? waterAllocationLimit,
  }) async {
    final res = await client.post('/api/zones', body: {
      'name': name,
      'area': area,
      'cropType': cropType,
      if (waterAllocationLimit != null) 'waterAllocationLimit': waterAllocationLimit,
    });
    return ResourceDto.fromJson(res);
  }

  Future<void> deleteZone(String zoneId, {String? fieldId}) async {
    final cleanZoneId = zoneId.replaceAll(RegExp(r'[^0-9]'), '');
    final effectiveZoneId = cleanZoneId.isEmpty ? zoneId : cleanZoneId;
    final effectiveFieldId = (fieldId != null && fieldId.isNotEmpty)
        ? fieldId.replaceAll(RegExp(r'[^0-9]'), '')
        : '1';
    final targetFieldId = effectiveFieldId.isEmpty ? '1' : effectiveFieldId;

    try {
      // First attempt the field-scoped endpoint: /api/v1/fields/{fieldId}/zones/{zoneId}
      await client.delete('/api/fields/$targetFieldId/zones/$effectiveZoneId');
    } on ApiException catch (e) {
      // If 404, 405, or method not allowed on field-scoped route, try direct /api/zones/{zoneId}
      if (e.statusCode == 404 || e.statusCode == 405) {
        await client.delete('/api/zones/$effectiveZoneId');
      } else {
        rethrow;
      }
    }
  }

  Future<ResourceListDto> measurements({String? quarterId}) async =>
      ResourceListDto.fromJson(
        await client.get(
          '/api/measurements',
          query: quarterId == null ? null : {'quarterId': quarterId},
        ),
      );

  Future<FieldTopologyDto> getTopology(String fieldId) async {
    final response = await client.get('/api/fields/$fieldId/topology');
    return FieldTopologyDto.fromJson(response as JsonMap);
  }

  Future<List<MonitoringPointDto>> listMonitoringPoints(String fieldId) async {
    final response = await client.get('/api/fields/$fieldId/monitoring-points');
    if (response is Map && response['data'] is List) {
      return (response['data'] as List)
          .map((e) => MonitoringPointDto.fromJson(e as JsonMap))
          .toList();
    }
    return [];
  }

  Future<MonitoringPointDto> assignNodeToPoint(
    String pointId,
    String nodeId,
  ) async {
    final response = await client.put(
      '/api/monitoring-points/$pointId/assign-node',
      body: {'nodeId': nodeId},
    );
    return MonitoringPointDto.fromJson(response as JsonMap);
  }

  Future<Map<String, dynamic>> getFieldReadiness(String fieldId) async {
    final res = await client.get('/api/fields/$fieldId/readiness');
    return res is Map<String, dynamic> ? res : (res as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> getFieldZones(String fieldId) async {
    final res = await client.get('/api/fields/$fieldId/zones');
    if (res is List) {
      return res.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createFieldZone(String fieldId, Map<String, dynamic> body) async {
    final res = await client.post('/api/fields/$fieldId/zones', body: body);
    return res is Map<String, dynamic> ? res : (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateFieldZone(String fieldId, String zoneId, Map<String, dynamic> body) async {
    final res = await client.put('/api/fields/$fieldId/zones/$zoneId', body: body);
    return res is Map<String, dynamic> ? res : (res as Map).cast<String, dynamic>();
  }

  Future<void> archiveFieldZone(String fieldId, String zoneId) async {
    await client.delete('/api/fields/$fieldId/zones/$zoneId');
  }

  Future<List<Map<String, dynamic>>> splitFieldZone(String fieldId, String zoneId, Map<String, dynamic> body) async {
    final res = await client.post('/api/fields/$fieldId/zones/$zoneId/split', body: body);
    if (res is List) {
      return res.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> mergeFieldZones(String fieldId, Map<String, dynamic> body) async {
    final res = await client.post('/api/fields/$fieldId/zones/merge', body: body);
    return res is Map<String, dynamic> ? res : (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> saveFieldLayout(String fieldId, Map<String, dynamic> body) async {
    final res = await client.post('/api/fields/$fieldId/layout', body: body);
    return res is Map<String, dynamic> ? res : (res as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> getFieldHistory(String fieldId) async {
    final res = await client.get('/api/fields/$fieldId/history');
    if (res is List) {
      return res.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }
}

class AnalyticsApiService {
  final ApiClient client;

  const AnalyticsApiService(this.client);

  Future<ResourceDto> analytics() async =>
      ResourceDto.fromJson(await client.get('/api/analytics'));

  Future<ResourceDto> waterLevelAnalytics() async =>
      ResourceDto.fromJson(await client.get('/api/analytics/water-level'));
}

class AlertApiService {
  final ApiClient client;

  const AlertApiService(this.client);

  Future<ResourceListDto> listAlerts({
    String? category,
    String? severity,
    bool? unreadOnly,
    String? nodeId,
    String? search,
  }) async {
    final query = <String, String>{};
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (severity != null && severity.isNotEmpty) query['severity'] = severity;
    if (unreadOnly != null) query['unreadOnly'] = unreadOnly.toString();
    if (nodeId != null && nodeId.isNotEmpty) query['nodeId'] = nodeId;
    if (search != null && search.isNotEmpty) query['search'] = search;
    return ResourceListDto.fromJson(
      await client.get('/api/alerts', query: query.isEmpty ? null : query),
    );
  }

  Future<Map<String, dynamic>> syncAlerts({int? sinceId, String? since}) async {
    final query = <String, String>{};
    if (sinceId != null) query['sinceId'] = sinceId.toString();
    if (since != null && since.isNotEmpty) query['since'] = since;
    final res = await client.get(
      '/api/alerts/sync',
      query: query.isEmpty ? null : query,
    );
    return res is Map<String, dynamic>
        ? res
        : (res is Map ? res.cast<String, dynamic>() : <String, dynamic>{});
  }

  Future<int> getUnreadCount() async {
    final res = await client.get('/api/alerts/unread-count');
    if (res is Map) {
      final raw = res['unreadCount'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  Future<void> markAsRead(String alertId) async {
    final cleanId = alertId.replaceAll(RegExp(r'[^0-9]'), '');
    final targetId = cleanId.isEmpty ? alertId : cleanId;
    await client.put('/api/alerts/$targetId/read');
  }

  Future<void> markAllAsRead() async {
    await client.put('/api/alerts/read-all');
  }

  Future<void> deleteAlert(String alertId) async {
    final cleanId = alertId.replaceAll(RegExp(r'[^0-9]'), '');
    final targetId = cleanId.isEmpty ? alertId : cleanId;
    await client.delete('/api/alerts/$targetId');
  }
}

class DeviceApiService {
  final ApiClient client;

  const DeviceApiService(this.client);

  Future<ResourceListDto> listDevices() async =>
      ResourceListDto.fromJson(await client.get('/api/devices'));

  Future<ResourceDto> gateway() async =>
      ResourceDto.fromJson(await client.get('/api/gateway'));
}

class NodeApiService {
  final ApiClient client;

  const NodeApiService(this.client);

  Future<ResourceListDto> listNodes({String? fieldId, String? zoneId}) async {
    final query = <String, String>{};
    if (fieldId != null) query['fieldId'] = fieldId;
    if (zoneId != null) query['zoneId'] = zoneId;
    return ResourceListDto.fromJson(
      await client.get('/api/nodes', query: query.isEmpty ? null : query),
    );
  }

  Future<ResourceDto> getNode(String id) async =>
      ResourceDto.fromJson(await client.get('/api/nodes/$id'));

  /// Batched latest-telemetry snapshot for every node visible to the caller.
  ///
  /// A single request resolves the newest reading of every sensor type for every
  /// requested node, which keeps the Home Dashboard poll at one round trip and
  /// avoids re-reading the full telemetry history on the backend.
  Future<ResourceDto> getLatestTelemetrySnapshot({List<String>? nodeIds}) async {
    final query = <String, String>{};
    if (nodeIds != null && nodeIds.isNotEmpty) {
      query['nodeIds'] = nodeIds.join(',');
    }
    return ResourceDto.fromJson(
      await client.get(
        '/api/nodes/telemetry/latest',
        query: query.isEmpty ? null : query,
      ),
    );
  }

  Future<ResourceListDto> listDiscoveredNodes() async =>
      ResourceListDto.fromJson(await client.get('/api/nodes/unassigned'));

  Future<ResourceDto> registerNode(NodeRegistrationRequestDto request) async =>
      ResourceDto.fromJson(
        await client.post('/api/nodes/register', body: request.toJson()),
      );

  Future<ResourceDto> assignSpatial(
    String id,
    NodeSpatialAssignmentDto assignment,
  ) async =>
      ResourceDto.fromJson(
        await client.put('/api/nodes/$id/spatial', body: assignment.toJson()),
      );

  Future<ResourceDto> configureTransmissionInterval(
    String id,
    TransmissionConfigDto config,
  ) async =>
      ResourceDto.fromJson(
        await client.put(
          '/api/nodes/$id/transmission-interval',
          body: config.toJson(),
        ),
      );

  Future<ResourceDto> provisionNode(
    String id,
    NodeProvisioningRequestDto request,
  ) async =>
      ResourceDto.fromJson(
        await client.post('/api/nodes/$id/provision', body: request.toJson()),
      );

  Future<ResourceDto> updateLifecycle(
    String id,
    NodeLifecycleUpdateDto update,
  ) async =>
      ResourceDto.fromJson(
        await client.post('/api/nodes/$id/lifecycle', body: update.toJson()),
      );

  Future<NodeReplacementResultDto> replaceNode(
    String id,
    NodeReplacementRequestDto request,
  ) async {
    final response = await client.post(
      '/api/nodes/$id/replace',
      body: request.toJson(),
    );
    return NodeReplacementResultDto.fromJson(
      response is Map<String, dynamic>
          ? response
          : (response as Map).cast<String, dynamic>(),
    );
  }

  Future<ResourceDto> updateNode(
    String id,
    Map<String, dynamic> patch,
  ) async =>
      ResourceDto.fromJson(
        await client.patch('/api/nodes/$id', body: patch),
      );

  Future<bool> decommissionNode(String id) async {
    await client.delete('/api/nodes/$id');
    return true;
  }

  Future<bool> unpairNode(String id) async {
    await client.delete('/api/nodes/$id/pairing');
    return true;
  }

  Future<ResourceDto> assignNodeToField(
    String id, {
    int? fieldId,
    int? monitoringZoneId,
  }) async {
    final response = await client.put(
      '/api/nodes/$id/field-assignment',
      body: {
        if (fieldId != null) 'fieldId': fieldId,
        'monitoringZoneId': monitoringZoneId,
      },
    );
    return ResourceDto.fromJson(response);
  }

  Future<bool> removeNodeFromField(String id) async {
    try {
      await client.delete('/api/nodes/$id/field-assignment');
      return true;
    } catch (_) {
      await client.put(
        '/api/nodes/$id/field-assignment',
        body: {'monitoringZoneId': null},
      );
      return true;
    }
  }

  Future<Map<String, dynamic>> resetNodePairing(String nodeId, {String? reason}) async {
    final response = await client.post(
      '/api/nodes/$nodeId/pairing/reset',
      body: {if (reason != null) 'reason': reason},
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    return {'nodeId': nodeId, 'succeeded': true};
  }
}

class SystemApiService {
  final ApiClient client;

  const SystemApiService(this.client);

  Future<MasterStateDto> getMasterState() async {
    final response = await client.get('/api/system/master-state');
    return MasterStateDto.fromJson(response);
  }

  Future<MasterStateDto> updateMasterState({required bool enabled, String? notes}) async {
    final response = await client.put(
      '/api/system/master-state',
      body: {
        'enabled': enabled,
        'masterEnabled': enabled,
        if (notes != null) 'notes': notes,
      },
    );
    return MasterStateDto.fromJson(response);
  }

  Future<CoreHealthDto> getCoreHealth() async {
    final response = await client.get('/api/system/health');
    return CoreHealthDto.fromJson(response);
  }

  Future<List<PairingRequestDto>> getPendingPairingRequests({bool retryable = false}) async {
    final response = await client.get('/api/pairing/requests/pending', retryable: retryable);
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => PairingRequestDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<PairingRequestDto> rejectPairingRequest(int id, {String? reason}) async {
    final response = await client.post(
      '/api/pairing/requests/$id/reject',
      body: {'reason': reason ?? 'Rejected by administrator'},
    );
    return PairingRequestDto.fromJson(response);
  }

  Future<ResourceDto> approvePairingRequest(
    int id, {
    required String nodeId,
    required String identityType,
    required String identityValue,
    String? macAddress,
    String? hardwareModel,
    String? firmwareVersion,
    int? monitoringZoneId,
  }) async {
    final response = await client.post(
      '/api/pairing/requests/$id/approve',
      body: {
        'nodeId': nodeId,
        'identityType': identityType,
        'identityValue': identityValue,
        if (macAddress != null) 'macAddress': macAddress,
        if (hardwareModel != null) 'hardwareModel': hardwareModel,
        if (firmwareVersion != null) 'firmwareVersion': firmwareVersion,
        if (monitoringZoneId != null) 'monitoringZoneId': monitoringZoneId,
      },
    );
    return ResourceDto.fromJson(response);
  }

  Future<Map<String, dynamic>> resetPairing({
    List<String>? nodeIds,
    String? reason,
    bool clearFieldAssignments = true,
  }) async {
    final response = await client.post(
      '/api/pairing/reset',
      body: {
        if (nodeIds != null && nodeIds.isNotEmpty) 'nodeIds': nodeIds,
        if (reason != null) 'reason': reason,
        'clearFieldAssignments': clearFieldAssignments,
      },
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    return {'succeeded': true};
  }
}

class IrrigationApiService {
  final ApiClient client;

  const IrrigationApiService(this.client);

  Future<IrrigationResultDto> status({int fieldId = 1}) async {
    try {
      final response = await client.get('/api/irrigation/field/$fieldId/status');
      if (response is Map) {
        return IrrigationResultDto(Map<String, dynamic>.from(response));
      }
    } catch (_) {}

    try {
      final generic = await client.get('/api/irrigation/status');
      if (generic != null) {
        return IrrigationResultDto.fromJson(generic);
      }
    } catch (_) {}

    // Return empty status DTO if backend has no dedicated status endpoint
    return const IrrigationResultDto({});
  }

  Future<CommandStatusResponseDto> startManual({
    required String operatorId,
    int fieldId = 1,
    required String rationale,
    required int durationMinutes,
    double? targetWaterDepthCm,
    bool overridePolicy = false,
  }) async {
    final response = await client.post(
      '/api/irrigation/manual/start',
      body: {
        'operatorId': operatorId,
        'fieldId': fieldId,
        'rationale': rationale,
        'durationMinutes': durationMinutes,
        if (targetWaterDepthCm != null) 'targetWaterDepthCm': targetWaterDepthCm,
        'overridePolicy': overridePolicy,
      },
    );
    return CommandStatusResponseDto.fromJson(response);
  }

  Future<CommandStatusResponseDto> stopManual({
    required String operatorId,
    int fieldId = 1,
    required String rationale,
  }) async {
    final response = await client.post(
      '/api/irrigation/manual/stop',
      body: {
        'operatorId': operatorId,
        'fieldId': fieldId,
        'rationale': rationale,
      },
    );
    return CommandStatusResponseDto.fromJson(response);
  }

  Future<CommandStatusResponseDto> emergencyStop({
    required String operatorId,
    int? fieldId = 1,
    required String reason,
    String scope = 'FIELD',
  }) async {
    final response = await client.post(
      '/api/irrigation/emergency-stop',
      body: {
        'operatorId': operatorId,
        if (fieldId != null) 'fieldId': fieldId,
        'reason': reason,
        'scope': scope,
      },
    );
    return CommandStatusResponseDto.fromJson(response);
  }

  Future<IrrigationResultDto> start({required int durationMinutes}) async {
    return IrrigationResultDto.fromJson(
      await client.post(
        '/api/irrigation/start',
        body: IrrigationCommandDto(
          durationMinutes: durationMinutes,
        ).toJson(),
      ),
    );
  }

  Future<IrrigationResultDto> stop() async {
    return IrrigationResultDto.fromJson(
      await client.post(
        '/api/irrigation/stop',
        body: const IrrigationCommandDto().toJson(),
      ),
    );
  }

  Future<AutoIrrigationConfigDto> getAutoConfig({
    String systemId = 'default',
  }) async {
    final response = await client.get(
      '/api/irrigation/auto-config',
      query: {'systemId': systemId},
    );
    return AutoIrrigationConfigDto.fromJson(response as JsonMap);
  }

  Future<AutoIrrigationConfigDto> updateAutoConfig(
    AutoIrrigationConfigDto config,
  ) async {
    final response = await client.put(
      '/api/irrigation/auto-config',
      body: config.toJson(),
    );
    return AutoIrrigationConfigDto.fromJson(response as JsonMap);
  }

  Future<AutoIrrigationStatusDto> getAutoState({
    String systemId = 'default',
  }) async {
    final response = await client.get(
      '/api/irrigation/auto-state',
      query: {'systemId': systemId},
    );
    return AutoIrrigationStatusDto.fromJson(response as JsonMap);
  }

  Future<AutoIrrigationStatusDto> clearLockout(
    ClearLockoutRequestDto request,
  ) async {
    final response = await client.post(
      '/api/irrigation/auto-lockout/clear',
      body: request.toJson(),
    );
    return AutoIrrigationStatusDto.fromJson(response as JsonMap);
  }

  Future<IrrigationAuditLogListDto> getAuditLogs({
    String systemId = 'default',
    int limit = 50,
  }) async {
    final response = await client.get(
      '/api/irrigation/audit-log',
      query: {
        'systemId': systemId,
        'limit': limit.toString(),
      },
    );
    return IrrigationAuditLogListDto.fromJson(response);
  }
}

/// Service for querying audit events from backend REST API.
///
/// NOTE: POST /api/audit/events is backend-only and not exposed to frontend clients
/// to enforce tamper-resistant server-side event generation.
class AccountAuditApiService {
  final ApiClient client;

  const AccountAuditApiService(this.client);

  Future<AccountAuditEventListDto> getAuditEvents({
    String? category,
    String? actorId,
    String? targetType,
    String? targetId,
    DateTime? from,
    DateTime? to,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (actorId != null && actorId.isNotEmpty) query['actorId'] = actorId;
    if (targetType != null && targetType.isNotEmpty) query['targetType'] = targetType;
    if (targetId != null && targetId.isNotEmpty) query['targetId'] = targetId;
    if (from != null) query['from'] = from.toIso8601String();
    if (to != null) query['to'] = to.toIso8601String();

    final response = await client.get(
      '/api/audit/events',
      query: query,
    );
    return AccountAuditEventListDto.fromJson(response);
  }

  Future<AccountAuditEventDto> getAuditEvent(String eventId) async {
    final response = await client.get('/api/audit/events/$eventId');
    return AccountAuditEventDto.fromJson(response as JsonMap);
  }
}

class LoRaWANApiService {
  final ApiClient client;

  const LoRaWANApiService(this.client);

  Future<List<JsonMap>> listDevices() async {
    final response = await client.get('/api/lorawan/devices');
    if (response is Map && response['data'] is List) {
      return (response['data'] as List).cast<JsonMap>();
    }
    return [];
  }

  Future<JsonMap> getDevice(String devEui) async {
    final response = await client.get('/api/lorawan/devices/$devEui');
    return response as JsonMap;
  }

  Future<JsonMap> queueDownlink(String devEui, JsonMap payload) async {
    final response = await client.post(
      '/api/lorawan/devices/$devEui/downlink',
      body: payload,
    );
    return response as JsonMap;
  }

  Future<List<JsonMap>> getTelemetry({String? devEui, int limit = 50}) async {
    final query = <String, String>{'limit': limit.toString()};
    if (devEui != null && devEui.isNotEmpty) query['devEui'] = devEui;
    final response = await client.get('/api/lorawan/telemetry', query: query);
    if (response is Map && response['data'] is List) {
      return (response['data'] as List).cast<JsonMap>();
    }
    return [];
  }
}

class EvaluationApiService {
  final ApiClient client;

  const EvaluationApiService(this.client);

  Future<SystemEvaluationSummaryDto> getSummary({String? nodeId, int? fieldId}) async {
    final query = <String, String>{};
    if (nodeId != null && nodeId.isNotEmpty) query['nodeId'] = nodeId;
    if (fieldId != null) query['fieldId'] = fieldId.toString();

    final response = await client.get('/api/v1/evaluation/summary', query: query.isEmpty ? null : query);
    return SystemEvaluationSummaryDto.fromJson(response as JsonMap);
  }

  Future<ReferenceMeasurementDto> createReferenceMeasurement(ReferenceMeasurementDto request) async {
    final response = await client.post(
      '/api/v1/evaluation/reference-measurements',
      body: request.toJson(),
    );
    return ReferenceMeasurementDto.fromJson(response as JsonMap);
  }

  Future<List<ReferenceMeasurementDto>> listReferenceMeasurements({
    required String indicatorType,
    String? nodeId,
  }) async {
    final query = <String, String>{'indicatorType': indicatorType};
    if (nodeId != null && nodeId.isNotEmpty) query['nodeId'] = nodeId;

    final response = await client.get('/api/v1/evaluation/reference-measurements', query: query);
    if (response is List) {
      return response.map(ReferenceMeasurementDto.fromJson).toList();
    }
    return [];
  }
}

class TelemetryStreamApiService {
  final ApiClient client;

  const TelemetryStreamApiService(this.client);

  Future<dynamic> getEvents({
    String? nodeId,
    int? fieldId,
    String? status,
    DateTime? from,
    DateTime? to,
    String? search,
    int page = 0,
    int size = 50,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    if (nodeId != null && nodeId.trim().isNotEmpty) query['nodeId'] = nodeId.trim();
    if (fieldId != null) query['fieldId'] = fieldId.toString();
    if (status != null && status.trim().isNotEmpty) query['status'] = status.trim();
    if (from != null) query['from'] = from.toIso8601String();
    if (to != null) query['to'] = to.toIso8601String();
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();

    return client.get('/api/v1/telemetry/stream/events', query: query);
  }

  Future<dynamic> getRecentEvents({int limit = 50, DateTime? after}) async {
    final query = <String, String>{'limit': limit.toString()};
    if (after != null) query['after'] = after.toIso8601String();
    return client.get('/api/v1/telemetry/stream/recent', query: query);
  }

  Future<dynamic> getSummary() async {
    return client.get('/api/v1/telemetry/stream/summary');
  }

  Future<dynamic> getFilterOptions() async {
    return client.get('/api/v1/telemetry/stream/filters');
  }
}


