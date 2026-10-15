import 'dart:async';

import '../../../../core/api/api_dtos.dart';
import '../../../../core/api/api_services.dart';
import '../../../diagnostics/domain/models/models.dart';
import 'diagnostics_repository.dart';

class ApiDiagnosticsRepository implements DiagnosticsRepository {
  final DeviceApiService api;

  ApiDiagnosticsRepository(this.api);

  @override
  Future<List<DeviceDiagnostic>> fetchDeviceDiagnostics() async {
    final response = await api.listDevices();
    return response.items.map(_mapDevice).toList(growable: false);
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
