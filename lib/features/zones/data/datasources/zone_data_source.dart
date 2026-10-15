import '../../domain/models/monitoring_zone.dart';
import '../../../nodes/domain/models/spatial_coordinates.dart';
import '../../../nodes/domain/models/transmission_config.dart';

enum ZoneMockState { normal, empty, stale, unavailable, error }

abstract class ZoneDataSource {
  Future<List<MonitoringZone>> getMonitoringZones({
    ZoneMockState mockState = ZoneMockState.normal,
  });
  Future<MonitoringZone?> getZoneByCode(
    String code, {
    ZoneMockState mockState = ZoneMockState.normal,
  });
}

class MockZoneDataSource implements ZoneDataSource {
  static final List<MonitoringZone> _customZones = [];

  static void addCustomZone(MonitoringZone zone) {
    if (!_customZones.any((z) => z.id == zone.id || z.code == zone.code)) {
      _customZones.add(zone);
    }
  }

  List<MonitoringZone> _getMockZones(DateTime now, {bool isStale = false}) {
    final updatedTime = isStale
        ? now.subtract(const Duration(hours: 3))
        : now.subtract(const Duration(minutes: 4));

    return [
      MonitoringZone(
        id: 'zone-q1',
        code: 'Q1',
        name: 'North-East Field Quadrant',
        soilMoisturePercent: 42.5,
        waterLevelCm: 5.2,
        temperatureCelsius: 28.4,
        humidityPercent: 78.0,
        batteryPercent: 94,
        status: ZoneStatus.optimal,
        lastUpdated: updatedTime,
        isOnline: true,
        rssiDbm: -78,
        snrDb: 10.4,
        hardwareModel: 'ArvaNode LoRa Node v2',
        firmwareVersion: 'v1.4.2',
        waterLevelHistory: const [4.2, 4.5, 4.8, 5.0, 5.2],
        waterLevelHistory24h: const [
          3.8, 4.0, 4.1, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 5.0, 5.1, 5.2
        ],
        waterLevelHistory7d: const [2.5, 3.0, 3.8, 4.2, 4.5, 5.0, 5.2],
        assignedNodeIds: const ['NODE-01', 'NODE-Q1'],
        coordinates: const SpatialCoordinates(
          latitude: 14.1524,
          longitude: 121.2431,
          localX: 25.0,
          localY: 75.0,
        ),
        transmissionConfig: TransmissionConfig(
          intervalSeconds: 300,
          isAdaptive: false,
          lastConfiguredAt: now.subtract(const Duration(days: 2)),
        ),
      ),
      MonitoringZone(
        id: 'zone-q2',
        code: 'Q2',
        name: 'North-West Field Quadrant',
        soilMoisturePercent: 24.1,
        waterLevelCm: 2.1,
        temperatureCelsius: 30.1,
        humidityPercent: 65.0,
        batteryPercent: 88,
        status: ZoneStatus.warning,
        lastUpdated: isStale
            ? now.subtract(const Duration(hours: 3, minutes: 12))
            : now.subtract(const Duration(minutes: 8)),
        isOnline: true,
        rssiDbm: -92,
        snrDb: 7.1,
        hardwareModel: 'ArvaNode LoRa Node v2',
        firmwareVersion: 'v1.4.2',
        waterLevelHistory: const [3.5, 3.1, 2.7, 2.4, 2.1],
        waterLevelHistory24h: const [
          3.8, 3.6, 3.4, 3.2, 3.0, 2.8, 2.6, 2.5, 2.4, 2.3, 2.2, 2.1
        ],
        waterLevelHistory7d: const [5.5, 4.8, 4.2, 3.5, 2.9, 2.4, 2.1],
        assignedNodeIds: const ['NODE-Q2'],
        coordinates: const SpatialCoordinates(
          latitude: 14.1538,
          longitude: 121.2415,
          localX: 75.0,
          localY: 75.0,
        ),
        transmissionConfig: TransmissionConfig(
          intervalSeconds: 60,
          isAdaptive: true,
          adaptiveReason: 'RF signal degraded, reporting fallback',
          lastConfiguredAt: now.subtract(const Duration(hours: 4)),
        ),
      ),
      MonitoringZone(
        id: 'zone-q3',
        code: 'Q3',
        name: 'South-East Field Quadrant',
        soilMoisturePercent: 55.0,
        waterLevelCm: 7.8,
        temperatureCelsius: 27.2,
        humidityPercent: 82.5,
        batteryPercent: 91,
        status: ZoneStatus.optimal,
        lastUpdated: isStale
            ? now.subtract(const Duration(hours: 3, minutes: 5))
            : now.subtract(const Duration(minutes: 3)),
        isOnline: true,
        rssiDbm: -72,
        snrDb: 11.8,
        hardwareModel: 'ArvaNode LoRa Node v2',
        firmwareVersion: 'v1.4.2',
        waterLevelHistory: const [6.8, 7.1, 7.4, 7.6, 7.8],
        waterLevelHistory24h: const [
          6.0, 6.2, 6.4, 6.6, 6.8, 7.0, 7.2, 7.4, 7.5, 7.6, 7.7, 7.8
        ],
        waterLevelHistory7d: const [4.0, 4.8, 5.5, 6.2, 7.0, 7.4, 7.8],
        assignedNodeIds: const ['NODE-Q3'],
        coordinates: const SpatialCoordinates(
          latitude: 14.1508,
          longitude: 121.2428,
          localX: 25.0,
          localY: 25.0,
        ),
        transmissionConfig: TransmissionConfig(
          intervalSeconds: 900,
          isAdaptive: true,
          adaptiveReason: 'Battery conservation mode active (<20%)',
          lastConfiguredAt: now.subtract(const Duration(hours: 1)),
        ),
      ),
      MonitoringZone(
        id: 'zone-q4',
        code: 'Q4',
        name: 'South-West Field Quadrant',
        soilMoisturePercent: 14.8,
        waterLevelCm: 0.5,
        temperatureCelsius: 31.8,
        humidityPercent: 58.0,
        batteryPercent: 18,
        status: ZoneStatus.critical,
        lastUpdated: isStale
            ? now.subtract(const Duration(hours: 5))
            : now.subtract(const Duration(minutes: 25)),
        isOnline: false,
        rssiDbm: -115,
        snrDb: 2.1,
        hardwareModel: 'ArvaNode LoRa Node v1.8',
        firmwareVersion: 'v1.3.0',
        waterLevelHistory: const [1.8, 1.4, 1.0, 0.7, 0.5],
        waterLevelHistory24h: const [
          2.2, 2.0, 1.8, 1.5, 1.3, 1.1, 0.9, 0.8, 0.7, 0.6, 0.5
        ],
        waterLevelHistory7d: const [4.5, 3.8, 3.0, 2.2, 1.4, 0.8, 0.5],
        assignedNodeIds: const ['NODE-Q4'],
        coordinates: const SpatialCoordinates(
          latitude: 14.1512,
          longitude: 121.2445,
          localX: 75.0,
          localY: 25.0,
        ),
        transmissionConfig: TransmissionConfig(
          intervalSeconds: 30,
          isAdaptive: true,
          adaptiveReason:
              'Critical moisture threshold drop triggered rapid reporting',
          lastConfiguredAt: now.subtract(const Duration(minutes: 30)),
        ),
      ),
    ];
  }

  @override
  Future<List<MonitoringZone>> getMonitoringZones({
    ZoneMockState mockState = ZoneMockState.normal,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (mockState == ZoneMockState.error) {
      throw Exception(
        'Telemetry Gateway Error: Unable to establish LoRaWAN telemetry uplink.',
      );
    }

    if (mockState == ZoneMockState.unavailable) {
      throw Exception(
        'Gateway Unavailable: Field Gateway node (GW-01) is offline.',
      );
    }

    if (mockState == ZoneMockState.empty) {
      return const [];
    }

    final now = DateTime.now();
    final defaultZones = _getMockZones(now, isStale: mockState == ZoneMockState.stale);
    return [...defaultZones, ..._customZones];
  }

  @override
  Future<MonitoringZone?> getZoneByCode(
    String code, {
    ZoneMockState mockState = ZoneMockState.normal,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final zones = await getMonitoringZones(mockState: mockState);
    try {
      return zones.firstWhere(
        (z) => z.code.toUpperCase() == code.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
