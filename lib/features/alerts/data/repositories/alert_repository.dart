import 'dart:async';
import '../../../../core/api/api_services.dart';
import '../../domain/models/models.dart';

abstract class AlertRepository {
  /// Fetch list of system alerts
  Future<List<SystemAlert>> fetchAlerts();

  /// Incremental cursor synchronization for lightweight polling
  Future<List<SystemAlert>> syncIncremental();

  /// Stream of active system alerts for notification updates
  Stream<List<SystemAlert>> watchAlerts();

  /// Mark a specific alert as read
  Future<void> markAsRead(String alertId);

  /// Mark all alerts as read
  Future<void> markAllAsRead();

  /// Delete/dismiss an alert entry
  Future<void> deleteAlert(String alertId);
}

class MockAlertRepository implements AlertRepository {
  final List<SystemAlert> _alerts;
  final _controller = StreamController<List<SystemAlert>>.broadcast();

  MockAlertRepository({List<SystemAlert>? initialAlerts})
      : _alerts = initialAlerts ?? _generateSeedAlerts();

  static List<SystemAlert> _generateSeedAlerts() {
    final now = DateTime.now();
    return [
      SystemAlert(
        id: 'ALT-001',
        title: 'Critical Dryness: Quadrant Q4',
        description: 'Water depth in Quadrant Q4 dropped to 0.5 cm, breaching safe threshold.',
        severity: AlertSeverity.critical,
        category: AlertCategory.agronomic,
        source: AlertSource.monitoringZone('Q4'),
        timestamp: now.subtract(const Duration(minutes: 15)),
        isRead: false,
        recommendedAction: 'Inspect field moisture level in Q4 and review central irrigation recommendation.',
      ),
      SystemAlert(
        id: 'ALT-002',
        title: 'Field Reflood Recommended',
        description: 'Aggregate field metrics indicate 2 of 4 monitoring points require reflooding. Centralized field irrigation suggested.',
        severity: AlertSeverity.warning,
        category: AlertCategory.irrigation,
        source: AlertSource.centralIrrigation,
        timestamp: now.subtract(const Duration(minutes: 40)),
        isRead: false,
        recommendedAction: 'Navigate to Central Control screen and tap "Start Field Irrigation" to reflood the entire field.',
      ),
      SystemAlert(
        id: 'ALT-003',
        title: 'Sensor Node Offline: Quadrant Q2',
        description: 'Telemetry heartbeat missed for over 25 minutes from Q2 node.',
        severity: AlertSeverity.warning,
        category: AlertCategory.hardware,
        source: AlertSource.monitoringZone('Q2'),
        timestamp: now.subtract(const Duration(hours: 1, minutes: 10)),
        isRead: false,
        recommendedAction: 'Check physical node power supply, antenna orientation, and battery in quadrant Q2.',
      ),
      SystemAlert(
        id: 'ALT-004',
        title: 'Low Battery Warning: Quadrant Q3',
        description: 'Node battery voltage dropped to 3.2V (15% remaining capacity).',
        severity: AlertSeverity.warning,
        category: AlertCategory.hardware,
        source: AlertSource.monitoringZone('Q3'),
        timestamp: now.subtract(const Duration(hours: 2, minutes: 30)),
        isRead: true,
        recommendedAction: 'Replace 18650 LiFePO4 battery pack or clean solar panel array for node Q3.',
      ),
      SystemAlert(
        id: 'ALT-005',
        title: 'Central Field Irrigation Started',
        description: 'Main pump activated and distribution valve opened for 45-minute scheduled run.',
        severity: AlertSeverity.info,
        category: AlertCategory.irrigation,
        source: AlertSource.centralIrrigation,
        timestamp: now.subtract(const Duration(hours: 4)),
        isRead: true,
        recommendedAction: 'Monitor central line pressure and main flow rate telemetry on the Control screen.',
      ),
      SystemAlert(
        id: 'ALT-006',
        title: 'Gateway Packet Loss Warning',
        description: 'Field LoRaWAN gateway experienced 12% packet retransmission over last 60 minutes.',
        severity: AlertSeverity.info,
        category: AlertCategory.connectivity,
        source: AlertSource.gateway,
        timestamp: now.subtract(const Duration(hours: 6)),
        isRead: true,
        recommendedAction: 'Verify gateway cellular backhaul signal quality and check gateway power supply.',
      ),
      SystemAlert(
        id: 'ALT-007',
        title: 'Rapid Infiltration Observation: Q1',
        description: 'Quadrant Q1 recorded abnormal water level drop rate (-1.8 cm/h).',
        severity: AlertSeverity.info,
        category: AlertCategory.agronomic,
        source: AlertSource.monitoringZone('Q1'),
        timestamp: now.subtract(const Duration(hours: 12)),
        isRead: true,
        recommendedAction: 'Inspect bund walls and drainage outlets near quadrant Q1 for seepage.',
      ),
    ];
  }

  @override
  Future<List<SystemAlert>> fetchAlerts() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_alerts);
  }

  @override
  Future<List<SystemAlert>> syncIncremental() async {
    return List.unmodifiable(_alerts);
  }

  @override
  Stream<List<SystemAlert>> watchAlerts() {
    return _controller.stream;
  }

  @override
  Future<void> markAsRead(String alertId) async {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(isRead: true);
      _notify();
    }
  }

  @override
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _alerts.length; i++) {
      _alerts[i] = _alerts[i].copyWith(isRead: true);
    }
    _notify();
  }

  @override
  Future<void> deleteAlert(String alertId) async {
    _alerts.removeWhere((a) => a.id == alertId);
    _notify();
  }

  void _notify() {
    _controller.add(List.unmodifiable(_alerts));
  }
}

class ApiAlertRepository implements AlertRepository {
  final AlertApiService _apiService;
  final List<SystemAlert> _localCache = [];
  final _controller = StreamController<List<SystemAlert>>.broadcast();
  int _latestSyncedId = 0;

  ApiAlertRepository(this._apiService);

  SystemAlert _mapAlertData(Map<String, dynamic> data, {String? fallbackId}) {
    final rawId = fallbackId ?? data['id']?.toString() ?? 'ALT-${DateTime.now().millisecondsSinceEpoch}';
    final parsedIntId = int.tryParse(rawId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (parsedIntId > _latestSyncedId) {
      _latestSyncedId = parsedIntId;
    }

    final isReadVal = data['isRead'] as bool? ?? data['acknowledged'] as bool? ?? false;
    final timestampStr = data['timestamp']?.toString() ?? data['createdAt']?.toString() ?? '';
    final sourceStr = data['source']?.toString() ??
        data['zoneCode']?.toString() ??
        data['nodeId']?.toString() ??
        data['deviceId']?.toString();
    final targetScope = data['targetScope']?.toString();

    return SystemAlert(
      id: rawId,
      title: data['title']?.toString() ?? 'System Notification',
      description: data['description']?.toString() ?? data['message']?.toString() ?? '',
      severity: _parseSeverity(data['severity']?.toString() ?? data['alertLevel']?.toString()),
      category: _parseCategory(data['category']?.toString() ?? data['alertType']?.toString()),
      source: _parseSource(
        sourceStr,
        zoneCode: data['zoneCode']?.toString(),
        nodeId: data['nodeId']?.toString() ?? data['deviceId']?.toString(),
        targetScope: targetScope,
      ),
      timestamp: DateTime.tryParse(timestampStr) ?? DateTime.now(),
      isRead: isReadVal,
      recommendedAction: data['recommendedAction']?.toString() ?? 'Review system status.',
      metadata: {
        if (data['nodeId'] != null || data['deviceId'] != null)
          'nodeId': (data['nodeId'] ?? data['deviceId']).toString(),
        if (data['zoneId'] != null) 'zoneId': data['zoneId'].toString(),
        if (data['zoneCode'] != null) 'zoneCode': data['zoneCode'].toString(),
        if (data['fieldId'] != null) 'fieldId': data['fieldId'].toString(),
        if (data['eventType'] != null) 'eventType': data['eventType'].toString(),
      },
    );
  }

  @override
  Future<List<SystemAlert>> fetchAlerts() async {
    try {
      final res = await _apiService.listAlerts();
      final alerts = res.items
          .map((dto) => _mapAlertData(dto.data, fallbackId: dto.id))
          .toList();
      _localCache
        ..clear()
        ..addAll(alerts);
      _controller.add(List.unmodifiable(_localCache));
      return List.unmodifiable(_localCache);
    } catch (_) {
      return List.unmodifiable(_localCache);
    }
  }

  @override
  Future<List<SystemAlert>> syncIncremental() async {
    try {
      if (_localCache.isEmpty) {
        return await fetchAlerts();
      }
      final res = await _apiService.syncAlerts(sinceId: _latestSyncedId);
      final rawItems = res['items'] ?? res['notifications'];
      if (rawItems is List && rawItems.isNotEmpty) {
        final newAlerts = <SystemAlert>[];
        for (final item in rawItems) {
          if (item is Map<String, dynamic>) {
            newAlerts.add(_mapAlertData(item));
          } else if (item is Map) {
            newAlerts.add(_mapAlertData(item.cast<String, dynamic>()));
          }
        }
        if (newAlerts.isNotEmpty) {
          final existingIds = _localCache.map((a) => a.id).toSet();
          final uniqueNew = newAlerts.where((a) => !existingIds.contains(a.id)).toList();
          if (uniqueNew.isNotEmpty) {
            _localCache.insertAll(0, uniqueNew);
            _controller.add(List.unmodifiable(_localCache));
          }
        }
      }
      return List.unmodifiable(_localCache);
    } catch (_) {
      return List.unmodifiable(_localCache);
    }
  }

  @override
  Stream<List<SystemAlert>> watchAlerts() => _controller.stream;

  @override
  Future<void> markAsRead(String alertId) async {
    final idx = _localCache.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      _localCache[idx] = _localCache[idx].copyWith(isRead: true);
      _controller.add(List.unmodifiable(_localCache));
    }
    try {
      await _apiService.markAsRead(alertId);
    } catch (_) {}
  }

  @override
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _localCache.length; i++) {
      _localCache[i] = _localCache[i].copyWith(isRead: true);
    }
    _controller.add(List.unmodifiable(_localCache));
    try {
      await _apiService.markAllAsRead();
    } catch (_) {}
  }

  @override
  Future<void> deleteAlert(String alertId) async {
    _localCache.removeWhere((a) => a.id == alertId);
    _controller.add(List.unmodifiable(_localCache));
    try {
      await _apiService.deleteAlert(alertId);
    } catch (_) {}
  }

  static AlertSeverity _parseSeverity(String? val) {
    switch (val?.toLowerCase()) {
      case 'critical':
      case 'error':
      case 'danger':
        return AlertSeverity.critical;
      case 'warning':
      case 'warn':
        return AlertSeverity.warning;
      case 'info':
      default:
        return AlertSeverity.info;
    }
  }

  static AlertCategory _parseCategory(String? val) {
    final lower = val?.toLowerCase() ?? '';
    if (lower.contains('agronomic') || lower.contains('zone') || lower.contains('field') || lower.contains('moisture')) {
      return AlertCategory.agronomic;
    }
    if (lower.contains('irrigation') || lower.contains('pump') || lower.contains('valve') || lower.contains('schedule')) {
      return AlertCategory.irrigation;
    }
    if (lower.contains('connect') || lower.contains('offline') || lower.contains('online') || lower.contains('gateway')) {
      return AlertCategory.connectivity;
    }
    return AlertCategory.hardware;
  }

  static AlertSource _parseSource(
    String? val, {
    String? zoneCode,
    String? nodeId,
    String? targetScope,
  }) {
    if (zoneCode != null && zoneCode.isNotEmpty) {
      return AlertSource(
        id: 'SRC-ZONE-$zoneCode',
        name: val ?? 'Monitoring Zone $zoneCode',
        type: AlertSourceType.monitoringZone,
        targetScope: targetScope ?? zoneCode,
      );
    }
    if (nodeId != null && nodeId.isNotEmpty) {
      return AlertSource(
        id: 'SRC-NODE-$nodeId',
        name: val ?? 'Node $nodeId',
        type: AlertSourceType.monitoringZone,
        targetScope: targetScope ?? nodeId,
      );
    }
    if (val != null && val.contains('Q')) {
      return AlertSource.monitoringZone(val);
    }
    if (val != null && val.toLowerCase().contains('gateway')) {
      return AlertSource.gateway;
    }
    if (val != null && val.isNotEmpty) {
      return AlertSource(
        id: 'SRC-SYS',
        name: val,
        type: AlertSourceType.centralIrrigation,
        targetScope: targetScope ?? 'SYSTEM',
      );
    }
    return AlertSource.centralIrrigation;
  }
}
