import '../../../nodes/domain/models/models.dart';
import '../../../zones/domain/models/monitoring_zone.dart';
import '../../domain/models/field.dart';

/// Aggregated graph of field topology containing zones, monitoring points, and active nodes.
class FieldTopology {
  final Field field;
  final List<MonitoringZone> zones;
  final List<MonitoringPoint> points;
  final List<Esp32Node> nodes;

  const FieldTopology({
    required this.field,
    required this.zones,
    required this.points,
    required this.nodes,
  });

  /// Finds a monitoring point by ID.
  MonitoringPoint? findPoint(String pointId) {
    for (final p in points) {
      if (p.id == pointId) return p;
    }
    return null;
  }

  /// Finds the physical node mounted at a given monitoring point.
  Esp32Node? findNodeForPoint(String pointId) {
    final point = findPoint(pointId);
    if (point == null || point.assignedNodeId == null) return null;
    for (final n in nodes) {
      if (n.id == point.assignedNodeId) return n;
    }
    return null;
  }
}

/// Abstract contract for retrieving and managing field topology.
abstract class FieldRepository {
  Future<Field> fetchField(String fieldId);

  Future<FieldTopology> fetchFieldTopology(String fieldId);

  Future<List<MonitoringPoint>> fetchMonitoringPoints(String fieldId);

  Future<MonitoringPoint> assignNodeToPoint({
    required String pointId,
    required String nodeId,
  });

  Future<MonitoringPoint> replaceNodeAtPoint({
    required String pointId,
    required String oldNodeId,
    required String newNodeId,
  });
}

/// Mock in-memory implementation supporting 2-point, 4-point, and 8-point field topology presets.
class MockFieldRepository implements FieldRepository {
  final String activePreset; // '2-point', '4-point', '8-point'
  late Field _field;
  late List<MonitoringZone> _zones;
  late List<MonitoringPoint> _points;
  late List<Esp32Node> _nodes;

  MockFieldRepository({this.activePreset = '4-point'}) {
    _initializePreset(activePreset);
  }

  void _initializePreset(String preset) {
    final now = DateTime.now();
    _field = Field(
      id: 'field-maligaya-01',
      name: 'Maligaya Demonstration Paddy Lot 4',
      description: 'Continuous AWD trial field with precision water level monitoring',
      areaSquareMeters: 12500.0,
      soilType: 'Clay Loam',
      activeCropStage: CropStage.vegetativeTillering,
      awdProfileId: 'awd_standard_vegetative',
      centralControllerId: 'ctrl-pump-01',
      boundaryCoordinates: const [
        {'latitude': 15.6710, 'longitude': 120.8910},
        {'latitude': 15.6730, 'longitude': 120.8912},
        {'latitude': 15.6728, 'longitude': 120.8935},
        {'latitude': 15.6708, 'longitude': 120.8932},
      ],
      createdAt: now.subtract(const Duration(days: 45)),
      updatedAt: now,
    );

    if (preset == '2-point') {
      _zones = [
        MonitoringZone(
          id: 'zone-01',
          fieldId: _field.id,
          code: 'Z1',
          name: 'North Inflow Zone',
          spatialWeight: 0.5,
          soilMoisturePercent: 44.2,
          waterLevelCm: 2.5,
          temperatureCelsius: 28.5,
          humidityPercent: 78.0,
          batteryPercent: 92,
          status: ZoneStatus.optimal,
          lastUpdated: now,
          assignedNodeIds: const ['node-01'],
          monitoringPointIds: const ['point-01'],
        ),
        MonitoringZone(
          id: 'zone-02',
          fieldId: _field.id,
          code: 'Z2',
          name: 'South Drainage Basin',
          spatialWeight: 0.5,
          soilMoisturePercent: 38.6,
          waterLevelCm: -5.0,
          temperatureCelsius: 29.1,
          humidityPercent: 75.0,
          batteryPercent: 88,
          status: ZoneStatus.optimal,
          lastUpdated: now,
          assignedNodeIds: const ['node-02'],
          monitoringPointIds: const ['point-02'],
        ),
      ];

      _points = [
        MonitoringPoint(
          id: 'point-01',
          fieldId: _field.id,
          zoneId: 'zone-01',
          code: 'P01',
          label: 'Inflow Station Alpha',
          coordinates: const SpatialCoordinates(
            latitude: 15.6715,
            longitude: 120.8918,
            localX: 25.0,
            localY: 30.0,
          ),
          relativeElevationCm: 1.5,
          tubeDatumOffsetCm: 18.0,
          assignedNodeId: 'node-01',
        ),
        MonitoringPoint(
          id: 'point-02',
          fieldId: _field.id,
          zoneId: 'zone-02',
          code: 'P02',
          label: 'Drain Basin Station Beta',
          coordinates: const SpatialCoordinates(
            latitude: 15.6725,
            longitude: 120.8928,
            localX: 95.0,
            localY: 75.0,
          ),
          relativeElevationCm: -1.0,
          tubeDatumOffsetCm: 18.0,
          assignedNodeId: 'node-02',
        ),
      ];

      _nodes = [
        Esp32Node(
          id: 'node-01',
          macAddress: '78:E3:6D:11:22:33',
          displayName: 'ArvaNode #01',
          assignedFieldId: _field.id,
          assignedZoneId: 'zone-01',
          assignedPointId: 'point-01',
          transmissionConfig: TransmissionConfig(
            intervalSeconds: 300,
            lastConfiguredAt: now,
          ),
          isOnline: true,
          batteryPercent: 92,
          lastSeen: now,
          waterLevelCm: 2.5,
          soilMoisturePercent: 44.2,
        ),
        Esp32Node(
          id: 'node-02',
          macAddress: '78:E3:6D:44:55:66',
          displayName: 'ArvaNode #02',
          assignedFieldId: _field.id,
          assignedZoneId: 'zone-02',
          assignedPointId: 'point-02',
          transmissionConfig: TransmissionConfig(
            intervalSeconds: 300,
            lastConfiguredAt: now,
          ),
          isOnline: true,
          batteryPercent: 88,
          lastSeen: now,
          waterLevelCm: -5.0,
          soilMoisturePercent: 38.6,
        ),
      ];
    } else if (preset == '8-point') {
      _zones = List.generate(4, (i) {
        final code = 'Z${i + 1}';
        return MonitoringZone(
          id: 'zone-0${i + 1}',
          fieldId: _field.id,
          code: code,
          name: 'Management Zone $code',
          spatialWeight: 0.25,
          soilMoisturePercent: 40.0 - (i * 2.0),
          waterLevelCm: 2.0 - (i * 3.5),
          temperatureCelsius: 28.0 + (i * 0.4),
          humidityPercent: 78.0,
          batteryPercent: 95 - (i * 3),
          status: i == 3 ? ZoneStatus.warning : ZoneStatus.optimal,
          lastUpdated: now,
          assignedNodeIds: ['node-0${i * 2 + 1}', 'node-0${i * 2 + 2}'],
          monitoringPointIds: ['point-0${i * 2 + 1}', 'point-0${i * 2 + 2}'],
        );
      });

      _points = List.generate(8, (i) {
        final pIdx = i + 1;
        final zIdx = (i ~/ 2) + 1;
        final x = 20.0 + (i % 4) * 25.0;
        final y = 20.0 + (i ~/ 4) * 45.0;
        return MonitoringPoint(
          id: 'point-0$pIdx',
          fieldId: _field.id,
          zoneId: 'zone-0$zIdx',
          code: 'P${pIdx.toString().padLeft(2, '0')}',
          label: 'Station $pIdx',
          coordinates: SpatialCoordinates(
            latitude: 15.6710 + (i * 0.0003),
            longitude: 120.8910 + (i * 0.0004),
            localX: x,
            localY: y,
          ),
          relativeElevationCm: (i % 2 == 0) ? 0.8 : -0.8,
          tubeDatumOffsetCm: 18.0,
          assignedNodeId: 'node-0$pIdx',
        );
      });

      _nodes = List.generate(8, (i) {
        final pIdx = i + 1;
        final zIdx = (i ~/ 2) + 1;
        final depth = 4.0 - (i * 2.2);
        final moist = 45.0 - (i * 2.0);
        return Esp32Node(
          id: 'node-0$pIdx',
          macAddress: '78:E3:6D:88:99:${pIdx.toString().padLeft(2, '0')}',
          displayName: 'ArvaNode #$pIdx',
          assignedFieldId: _field.id,
          assignedZoneId: 'zone-0$zIdx',
          assignedPointId: 'point-0$pIdx',
          transmissionConfig: TransmissionConfig(
            intervalSeconds: 300,
            lastConfiguredAt: now,
          ),
          isOnline: true,
          batteryPercent: 95 - (i * 3),
          lastSeen: now,
          waterLevelCm: depth,
          soilMoisturePercent: moist,
        );
      });
    } else {
      // 4-point preset (Standard)
      _zones = [
        MonitoringZone(
          id: 'zone-q1',
          fieldId: _field.id,
          code: 'Q1',
          name: 'North-West Inflow',
          spatialWeight: 0.25,
          soilMoisturePercent: 44.8,
          waterLevelCm: 5.1,
          temperatureCelsius: 27.8,
          humidityPercent: 78.0,
          batteryPercent: 92,
          status: ZoneStatus.optimal,
          lastUpdated: now,
          assignedNodeIds: const ['node-01'],
          monitoringPointIds: const ['point-01'],
        ),
        MonitoringZone(
          id: 'zone-q2',
          fieldId: _field.id,
          code: 'Q2',
          name: 'North-East Upper Bench',
          spatialWeight: 0.25,
          soilMoisturePercent: 41.2,
          waterLevelCm: 1.5,
          temperatureCelsius: 28.3,
          humidityPercent: 76.0,
          batteryPercent: 88,
          status: ZoneStatus.optimal,
          lastUpdated: now,
          assignedNodeIds: const ['node-02'],
          monitoringPointIds: const ['point-02'],
        ),
        MonitoringZone(
          id: 'zone-q3',
          fieldId: _field.id,
          code: 'Q3',
          name: 'South-West Central',
          spatialWeight: 0.25,
          soilMoisturePercent: 37.5,
          waterLevelCm: -3.2,
          temperatureCelsius: 29.0,
          humidityPercent: 74.0,
          batteryPercent: 85,
          status: ZoneStatus.optimal,
          lastUpdated: now,
          assignedNodeIds: const ['node-03'],
          monitoringPointIds: const ['point-03'],
        ),
        MonitoringZone(
          id: 'zone-q4',
          fieldId: _field.id,
          code: 'Q4',
          name: 'South-East Drainage Lowland',
          spatialWeight: 0.25,
          soilMoisturePercent: 33.1,
          waterLevelCm: -8.5,
          temperatureCelsius: 29.7,
          humidityPercent: 72.0,
          batteryPercent: 79,
          status: ZoneStatus.warning,
          lastUpdated: now,
          assignedNodeIds: const ['node-04'],
          monitoringPointIds: const ['point-04'],
        ),
      ];

      _points = [
        MonitoringPoint(
          id: 'point-01',
          fieldId: _field.id,
          zoneId: 'zone-q1',
          code: 'Q1',
          label: 'Observation Point Q1',
          coordinates: const SpatialCoordinates(
            latitude: 15.6712,
            longitude: 120.8915,
            localX: 25.0,
            localY: 30.0,
          ),
          relativeElevationCm: 1.0,
          tubeDatumOffsetCm: 18.0,
          assignedNodeId: 'node-01',
        ),
        MonitoringPoint(
          id: 'point-02',
          fieldId: _field.id,
          zoneId: 'zone-q2',
          code: 'Q2',
          label: 'Observation Point Q2',
          coordinates: const SpatialCoordinates(
            latitude: 15.6715,
            longitude: 120.8930,
            localX: 85.0,
            localY: 30.0,
          ),
          relativeElevationCm: 0.5,
          tubeDatumOffsetCm: 18.0,
          assignedNodeId: 'node-02',
        ),
        MonitoringPoint(
          id: 'point-03',
          fieldId: _field.id,
          zoneId: 'zone-q3',
          code: 'Q3',
          label: 'Observation Point Q3',
          coordinates: const SpatialCoordinates(
            latitude: 15.6725,
            longitude: 120.8916,
            localX: 25.0,
            localY: 75.0,
          ),
          relativeElevationCm: -0.5,
          tubeDatumOffsetCm: 18.0,
          assignedNodeId: 'node-03',
        ),
        MonitoringPoint(
          id: 'point-04',
          fieldId: _field.id,
          zoneId: 'zone-q4',
          code: 'Q4',
          label: 'Observation Point Q4',
          coordinates: const SpatialCoordinates(
            latitude: 15.6728,
            longitude: 120.8932,
            localX: 85.0,
            localY: 75.0,
          ),
          relativeElevationCm: -1.0,
          tubeDatumOffsetCm: 18.0,
          assignedNodeId: 'node-04',
        ),
      ];

      _nodes = [
        Esp32Node(
          id: 'node-01',
          macAddress: '78:E3:6D:12:34:01',
          displayName: 'Node Q1 (Inflow)',
          assignedFieldId: _field.id,
          assignedZoneId: 'zone-q1',
          assignedPointId: 'point-01',
          transmissionConfig: TransmissionConfig(
            intervalSeconds: 300,
            lastConfiguredAt: now,
          ),
          isOnline: true,
          batteryPercent: 92,
          lastSeen: now,
          waterLevelCm: 5.1,
          soilMoisturePercent: 44.8,
        ),
        Esp32Node(
          id: 'node-02',
          macAddress: '78:E3:6D:12:34:02',
          displayName: 'Node Q2 (Upper)',
          assignedFieldId: _field.id,
          assignedZoneId: 'zone-q2',
          assignedPointId: 'point-02',
          transmissionConfig: TransmissionConfig(
            intervalSeconds: 300,
            lastConfiguredAt: now,
          ),
          isOnline: true,
          batteryPercent: 88,
          lastSeen: now,
          waterLevelCm: 1.5,
          soilMoisturePercent: 41.2,
        ),
        Esp32Node(
          id: 'node-03',
          macAddress: '78:E3:6D:12:34:03',
          displayName: 'Node Q3 (Central)',
          assignedFieldId: _field.id,
          assignedZoneId: 'zone-q3',
          assignedPointId: 'point-03',
          transmissionConfig: TransmissionConfig(
            intervalSeconds: 300,
            lastConfiguredAt: now,
          ),
          isOnline: true,
          batteryPercent: 85,
          lastSeen: now,
          waterLevelCm: -3.2,
          soilMoisturePercent: 37.5,
        ),
        Esp32Node(
          id: 'node-04',
          macAddress: '78:E3:6D:12:34:04',
          displayName: 'Node Q4 (Drainage)',
          assignedFieldId: _field.id,
          assignedZoneId: 'zone-q4',
          assignedPointId: 'point-04',
          transmissionConfig: TransmissionConfig(
            intervalSeconds: 300,
            lastConfiguredAt: now,
          ),
          isOnline: true,
          batteryPercent: 79,
          lastSeen: now,
          waterLevelCm: -8.5,
          soilMoisturePercent: 33.1,
        ),
      ];
    }
  }

  @override
  Future<Field> fetchField(String fieldId) async {
    await Future.delayed(const Duration(milliseconds: 40));
    return _field;
  }

  @override
  Future<FieldTopology> fetchFieldTopology(String fieldId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return FieldTopology(
      field: _field,
      zones: List.unmodifiable(_zones),
      points: List.unmodifiable(_points),
      nodes: List.unmodifiable(_nodes),
    );
  }

  @override
  Future<List<MonitoringPoint>> fetchMonitoringPoints(String fieldId) async {
    await Future.delayed(const Duration(milliseconds: 30));
    return List.unmodifiable(_points);
  }

  @override
  Future<MonitoringPoint> assignNodeToPoint({
    required String pointId,
    required String nodeId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 40));
    final idx = _points.indexWhere((p) => p.id == pointId);
    if (idx < 0) throw Exception('MonitoringPoint not found: $pointId');

    final updatedPoint = _points[idx].copyWith(assignedNodeId: nodeId);
    _points[idx] = updatedPoint;

    // Update node assignedPointId as well
    final nodeIdx = _nodes.indexWhere((n) => n.id == nodeId);
    if (nodeIdx >= 0) {
      _nodes[nodeIdx] = _nodes[nodeIdx].copyWith(assignedPointId: pointId);
    }

    return updatedPoint;
  }

  @override
  Future<MonitoringPoint> replaceNodeAtPoint({
    required String pointId,
    required String oldNodeId,
    required String newNodeId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final idx = _points.indexWhere((p) => p.id == pointId);
    if (idx < 0) throw Exception('MonitoringPoint not found: $pointId');

    // Mark old node as replaced
    final oldIdx = _nodes.indexWhere((n) => n.id == oldNodeId);
    if (oldIdx >= 0) {
      _nodes[oldIdx] = _nodes[oldIdx].copyWith(
        assignedPointId: null,
        lifecycleState: NodeLifecycleState.replaced,
      );
    }

    // Assign new node to the point
    final updatedPoint = _points[idx].copyWith(assignedNodeId: newNodeId);
    _points[idx] = updatedPoint;

    final newIdx = _nodes.indexWhere((n) => n.id == newNodeId);
    if (newIdx >= 0) {
      _nodes[newIdx] = _nodes[newIdx].copyWith(
        assignedPointId: pointId,
        lifecycleState: NodeLifecycleState.active,
      );
    }

    return updatedPoint;
  }
}
