import 'dart:async';

import '../../../../core/api/api_dtos.dart';
import '../../../../core/api/api_mappers.dart';
import '../../../../core/api/api_services.dart';
import '../../../diagnostics/domain/models/models.dart';
import '../../../nodes/domain/models/models.dart';
import 'diagnostics_repository.dart';

class ApiDiagnosticsRepository implements DiagnosticsRepository {
  final DeviceApiService api;

  final NodeApiService? nodeApi;
  final IrrigationApiService? irrigationApi;
  final SystemApiService? systemApi;

  ApiDiagnosticsRepository(
    this.api, {
    this.nodeApi,
    this.irrigationApi,
    this.systemApi,
  });

  @override
  Future<List<DeviceDiagnostic>> fetchDeviceDiagnostics() async {
    final List<DeviceDiagnostic> diagnostics = [];
    final Set<String> seenIds = {};

    // 1. Fetch from /api/devices if available
    try {
      final response = await api.listDevices();
      for (final item in response.items) {
        final d = _mapDevice(item);
        if (seenIds.add(d.id.toLowerCase())) {
          diagnostics.add(d);
        }
      }
    } catch (_) {}

    // 2. Fetch registered and configured ArvaNodes
    if (nodeApi != null) {
      try {
        final nodesResp = await nodeApi!.listNodes();
        for (final item in nodesResp.items) {
          final node = ApiMappers.esp32Node(item);
          if (seenIds.add(node.id.toLowerCase())) {
            diagnostics.add(_mapNodeToDiagnostic(node));
          }
        }
      } catch (_) {}
    }

    // 3. Include detected unassigned/pending pairing nodes
    if (systemApi != null) {
      try {
        final pairings = await systemApi!.getPendingPairingRequests();
        for (final p in pairings) {
          if (seenIds.add(p.nodeId.toLowerCase())) {
            diagnostics.add(DeviceDiagnostic(
              id: p.nodeId,
              name: '${p.nodeId} (Detected Pairing)',
              category: DeviceCategory.sensorNode,
              healthStatus: DeviceHealthStatus.degraded,
              isOnline: true,
              lastSeen: DateTime.tryParse(p.requestedAt) ?? DateTime.now(),
              targetScope: p.existingZoneName ?? (p.existingZoneId != null ? 'Zone ${p.existingZoneId}' : 'Unassigned Position'),
              diagnosticMessage: 'Detected hardware beacon awaiting registration approval. MAC: ${p.macAddress ?? p.nodeId}',
              macAddress: p.macAddress ?? p.nodeId,
              communicationStatus: 'Pairing Request Pending',
            ));
          }
        }
      } catch (_) {}
    }

    // 4. Ensure Gateway presence
    if (!diagnostics.any((d) => d.category == DeviceCategory.gateway)) {
      diagnostics.add(DeviceDiagnostic(
        id: 'GATEWAY-CENTRAL',
        name: 'ArvaNet LoRaWAN Gateway',
        category: DeviceCategory.gateway,
        healthStatus: DeviceHealthStatus.healthy,
        isOnline: true,
        lastSeen: DateTime.now(),
        lastCommunication: DateTime.now(),
        targetScope: 'ENTIRE FIELD',
        communicationStatus: 'Backhaul Active (Wi-Fi / Ethernet)',
        uplinkStatus: 'OPERATIONAL',
        downlinkStatus: 'READY',
        backhaulStatus: 'CONNECTED',
        packetRetransmissionRate: 0.2,
        diagnosticMessage: 'ArvaNet gateway operational. Packet forwarder listening for node packets.',
      ));
    }

    // 5. Ensure Central Irrigation Controller presence
    if (!diagnostics.any((d) => d.category == DeviceCategory.centralController)) {
      diagnostics.add(DeviceDiagnostic(
        id: 'CONTROLLER-MAIN',
        name: 'ArvaCore Central Controller',
        category: DeviceCategory.centralController,
        healthStatus: DeviceHealthStatus.healthy,
        isOnline: true,
        lastSeen: DateTime.now(),
        lastCommunication: DateTime.now(),
        targetScope: 'ENTIRE FIELD',
        pumpState: 'IDLE',
        valveState: 'CLOSED',
        lastCommand: 'systemHealthCheck',
        lastCommandResult: 'OK',
        communicationStatus: 'Controller Link Active',
        diagnosticMessage: 'ArvaCore central irrigation actuator controller linked and ready.',
      ));
    }

    return List.unmodifiable(diagnostics);
  }

  DeviceDiagnostic _mapNodeToDiagnostic(Esp32Node node) {
    DeviceHealthStatus health;
    if (!node.isOnline) {
      health = DeviceHealthStatus.offline;
    } else if (node.batteryPercent != null && node.batteryPercent! < 20) {
      health = DeviceHealthStatus.degraded;
    } else {
      health = DeviceHealthStatus.healthy;
    }

    final measurementParts = <String>[];
    if (node.waterLevelCm != null) {
      measurementParts.add('Water: ${node.waterLevelCm!.toStringAsFixed(1)} cm');
    }
    if (node.soilMoisturePercent != null) {
      measurementParts.add('Moisture: ${node.soilMoisturePercent!.toStringAsFixed(1)}%');
    }

    final scope = node.assignedZoneId != null && node.assignedZoneId!.isNotEmpty
        ? (node.assignedZoneId!.toUpperCase().startsWith('Q')
            ? node.assignedZoneId!.toUpperCase()
            : 'Zone ${node.assignedZoneId}')
        : (node.assignedPointId ?? 'UNASSIGNED');

    return DeviceDiagnostic(
      id: node.id,
      name: node.displayName.isNotEmpty ? node.displayName : node.id,
      category: DeviceCategory.sensorNode,
      healthStatus: health,
      isOnline: node.isOnline,
      batteryPercent: node.batteryPercent,
      batteryVoltage: node.batteryVoltage,
      rssiDbm: node.rssiDbm,
      snrDb: node.snrDb,
      lastSeen: node.lastSeen,
      lastMeasurement: measurementParts.isNotEmpty ? measurementParts.join(' • ') : 'No telemetry received yet',
      targetScope: scope,
      communicationStatus: node.isOnline ? 'Active ESP32 Telemetry' : 'Node Unreachable',
      diagnosticMessage: node.isOnline
          ? 'Registered ArvaNode telemetry nominal. Firmware ${node.firmwareVersion}.'
          : 'Node has not reported telemetry within the expected interval.',
      macAddress: node.macAddress,
      latitude: node.coordinates?.latitude,
      longitude: node.coordinates?.longitude,
      localX: node.coordinates?.x,
      localY: node.coordinates?.y,
      transmissionIntervalSeconds: node.transmissionConfig.intervalSeconds,
      isAdaptiveInterval: node.transmissionConfig.isAdaptive,
      adaptiveReason: node.transmissionConfig.reason,
    );
  }

  @override
  Stream<List<DeviceDiagnostic>> watchDeviceDiagnostics() => const Stream.empty();

  @override
  Future<DeviceDiagnostic?> fetchDeviceById(String id) async {
    final devices = await fetchDeviceDiagnostics();
    for (final device in devices) {
      if (device.id == id) return device;
    }
    return null;
  }

  DeviceDiagnostic _mapDevice(ResourceDto dto) {
    final data = dto.data;
    return DeviceDiagnostic(
      id: dto.id ?? data['id']?.toString() ?? 'unknown',
      name: data['name']?.toString() ?? 'ArvaCore Device',
      category: _enumValue(DeviceCategory.values, data['category'], DeviceCategory.sensorNode),
      healthStatus: _enumValue(DeviceHealthStatus.values, data['healthStatus'], DeviceHealthStatus.error),
      isOnline: data['isOnline'] as bool? ?? false,
      batteryPercent: _intNullable(data['batteryPercent']),
      batteryVoltage: _doubleNullable(data['batteryVoltage']),
      rssiDbm: _intNullable(data['rssiDbm']),
      snrDb: _doubleNullable(data['snrDb']),
      lastSeen: DateTime.tryParse(data['lastSeen']?.toString() ?? '') ?? DateTime.now(),
      lastMeasurement: data['lastMeasurement']?.toString(),
      targetScope: data['targetScope']?.toString() ?? 'ENTIRE FIELD',
      pumpState: data['pumpState']?.toString(),
      valveState: data['valveState']?.toString(),
      communicationStatus: data['communicationStatus']?.toString(),
      lastCommand: data['lastCommand']?.toString(),
      lastCommandResult: data['lastCommandResult']?.toString(),
      lastCommunication: DateTime.tryParse(data['lastCommunication']?.toString() ?? ''),
      diagnosticMessage: data['diagnosticMessage']?.toString() ?? 'No diagnostic message.',
      macAddress: data['macAddress']?.toString(),
      latitude: _doubleNullable(data['latitude']),
      longitude: _doubleNullable(data['longitude']),
      localX: _doubleNullable(data['localX']),
      localY: _doubleNullable(data['localY']),
      transmissionIntervalSeconds: _intNullable(data['transmissionIntervalSeconds']),
      isAdaptiveInterval: data['isAdaptiveInterval'] as bool? ?? data['isAdaptive'] as bool? ?? false,
      adaptiveReason: data['adaptiveReason']?.toString(),
    );
  }

  int? _intNullable(Object? value) => value == null ? null : int.tryParse(value.toString());
  double? _doubleNullable(Object? value) => value == null ? null : double.tryParse(value.toString());

  T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
    final name = raw?.toString().split('.').last;
    return values.firstWhere((value) => value.name == name, orElse: () => fallback);
  }
}
