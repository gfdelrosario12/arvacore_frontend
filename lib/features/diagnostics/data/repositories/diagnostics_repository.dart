import 'dart:async';
import '../../domain/models/models.dart';

abstract class DiagnosticsRepository {
  /// Fetch diagnostic health telemetry for all deployed hardware
  Future<List<DeviceDiagnostic>> fetchDeviceDiagnostics();

  /// Stream of device health telemetry updates
  Stream<List<DeviceDiagnostic>> watchDeviceDiagnostics();

  /// Fetch single device diagnostic entry by ID
  Future<DeviceDiagnostic?> fetchDeviceById(String id);
}

class MockDiagnosticsRepository implements DiagnosticsRepository {
  final List<DeviceDiagnostic> _devices;
  final _controller = StreamController<List<DeviceDiagnostic>>.broadcast();

  MockDiagnosticsRepository({List<DeviceDiagnostic>? initialDevices})
      : _devices = initialDevices ?? _generateSeedDiagnostics();

  static List<DeviceDiagnostic> _generateSeedDiagnostics() {
    final now = DateTime.now();
    return [
      DeviceDiagnostic(
        id: 'NODE-Q1',
        name: 'Quadrant Q1 Sensor Node',
        category: DeviceCategory.sensorNode,
        healthStatus: DeviceHealthStatus.healthy,
        isOnline: true,
        batteryPercent: 92,
        batteryVoltage: 4.12,
        rssiDbm: -85,
        snrDb: 8.5,
        lastSeen: now.subtract(const Duration(minutes: 2)),
        lastMeasurement: 'Water Depth: 5.2 cm • Moisture: 48%',
        targetScope: 'Q1',
        diagnosticMessage: 'RF link strong. Solar charging active. Telemetry nominal.',
        macAddress: 'A4:CF:12:89:33:01',
        latitude: 14.1524,
        longitude: 121.2431,
        localX: 25.0,
        localY: 75.0,
        transmissionIntervalSeconds: 300,
        isAdaptiveInterval: false,
      ),
      DeviceDiagnostic(
        id: 'NODE-Q2',
        name: 'Quadrant Q2 Sensor Node',
        category: DeviceCategory.sensorNode,
        healthStatus: DeviceHealthStatus.degraded,
        isOnline: true,
        batteryPercent: 68,
        batteryVoltage: 3.82,
        rssiDbm: -108,
        snrDb: 3.2,
        lastSeen: now.subtract(const Duration(minutes: 18)),
        lastMeasurement: 'Water Depth: 3.8 cm • Moisture: 35%',
        targetScope: 'Q2',
        diagnosticMessage: 'Degraded RF link quality (RSSI -108 dBm). Missed 2 heartbeats.',
        macAddress: 'A4:CF:12:89:33:02',
        latitude: 14.1538,
        longitude: 121.2415,
        localX: 75.0,
        localY: 75.0,
        transmissionIntervalSeconds: 60,
        isAdaptiveInterval: true,
        adaptiveReason: 'RF signal degraded, reporting fallback',
      ),
      DeviceDiagnostic(
        id: 'NODE-Q3',
        name: 'Quadrant Q3 Sensor Node',
        category: DeviceCategory.sensorNode,
        healthStatus: DeviceHealthStatus.degraded,
        isOnline: true,
        batteryPercent: 15,
        batteryVoltage: 3.24,
        rssiDbm: -92,
        snrDb: 7.1,
        lastSeen: now.subtract(const Duration(minutes: 5)),
        lastMeasurement: 'Water Depth: 4.1 cm • Moisture: 41%',
        targetScope: 'Q3',
        diagnosticMessage: 'Low battery warning (15% / 3.24V). Recharge or replacement required.',
        macAddress: 'A4:CF:12:89:33:03',
        latitude: 14.1508,
        longitude: 121.2428,
        localX: 25.0,
        localY: 25.0,
        transmissionIntervalSeconds: 900,
        isAdaptiveInterval: true,
        adaptiveReason: 'Battery conservation mode active (<20%)',
      ),
      DeviceDiagnostic(
        id: 'NODE-Q4',
        name: 'Quadrant Q4 Sensor Node',
        category: DeviceCategory.sensorNode,
        healthStatus: DeviceHealthStatus.healthy,
        isOnline: true,
        batteryPercent: 88,
        batteryVoltage: 4.02,
        rssiDbm: -88,
        snrDb: 8.0,
        lastSeen: now.subtract(const Duration(minutes: 3)),
        lastMeasurement: 'Water Depth: 0.5 cm • Moisture: 22%',
        targetScope: 'Q4',
        diagnosticMessage: 'RF link healthy. Low water level reported (0.5 cm).',
        macAddress: 'A4:CF:12:89:33:04',
        latitude: 14.1512,
        longitude: 121.2445,
        localX: 75.0,
        localY: 25.0,
        transmissionIntervalSeconds: 30,
        isAdaptiveInterval: true,
        adaptiveReason: 'Critical moisture threshold drop triggered rapid reporting',
      ),
      DeviceDiagnostic(
        id: 'GW-CENTRAL',
        name: 'Field LoRaWAN Gateway',
        category: DeviceCategory.gateway,
        healthStatus: DeviceHealthStatus.healthy,
        isOnline: true,
        rssiDbm: -72,
        snrDb: 12.0,
        lastSeen: now.subtract(const Duration(seconds: 45)),
        lastCommunication: now.subtract(const Duration(seconds: 45)),
        lastMeasurement: 'Uplink: 99.4% • Cellular LTE Active',
        communicationStatus: 'Connected',
        uplinkStatus: '99.4% delivered',
        downlinkStatus: '98.9% delivered',
        backhaulStatus: 'Cellular LTE active',
        packetRetransmissionRate: 0.6,
        targetScope: 'ENTIRE FIELD',
        diagnosticMessage: 'Gateway operational. 4 nodes & 1 controller connected.',
      ),
      DeviceDiagnostic(
        id: 'CTRL-FIELD-01',
        name: 'ArvaCore ESP32 Central Pump Controller',
        category: DeviceCategory.centralController,
        healthStatus: DeviceHealthStatus.healthy,
        isOnline: true,
        lastSeen: now.subtract(const Duration(minutes: 1)),
        lastCommunication: now.subtract(const Duration(minutes: 1)),
        lastMeasurement: 'Main Line Pressure: 1.2 bar • Flow: 0.0 L/min',
        communicationStatus: 'Connected',
        targetScope: 'ENTIRE FIELD',
        pumpState: 'OFF',
        valveState: 'CLOSED',
        lastCommand: 'stopIrrigation',
        lastCommandResult: 'stopIrrigation (COMPLETED)',
        diagnosticMessage: 'Controller online. Relays ready. Central control scope: ENTIRE FIELD.',
      ),
    ];
  }

  @override
  Future<List<DeviceDiagnostic>> fetchDeviceDiagnostics() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_devices);
  }

  @override
  Stream<List<DeviceDiagnostic>> watchDeviceDiagnostics() {
    return _controller.stream;
  }

  @override
  Future<DeviceDiagnostic?> fetchDeviceById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _devices.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  void updateDeviceForTesting(DeviceDiagnostic updated) {
    final index = _devices.indexWhere((d) => d.id == updated.id);
    if (index != -1) {
      _devices[index] = updated;
      _controller.add(List.unmodifiable(_devices));
    }
  }
}
