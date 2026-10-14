import 'dart:async';
import '../../../../core/api/api_services.dart';
import '../../domain/models/models.dart';

abstract class AlertRepository {
  /// Fetch list of system alerts
  Future<List<SystemAlert>> fetchAlerts();

  /// Stream of active system alerts for real-time notification updates
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
        recommendedAction: 'Inspect field moisture level in Q4 and review central AWD reflood recommendation.',
      ),
      SystemAlert(
        id: 'ALT-002',
        title: 'AWD Reflood Recommended',
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
        recommendedAction: 'Check physical node power supply, LoRa antenna orientation, and battery in quadrant Q2.',
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

  ApiAlertRepository(this._apiService);

  @override
  Future<List<SystemAlert>> fetchAlerts() async {
    try {
      final res = await _apiService.listAlerts();
      final alerts = res.items.map((dto) {
        final data = dto.data;
        return SystemAlert(
          id: dto.id ?? data['id']?.toString() ?? 'ALT-${DateTime.now().millisecondsSinceEpoch}',
          title: data['title']?.toString() ?? 'System Notification',
          description: data['description']?.toString() ?? data['message']?.toString() ?? '',
          severity: _parseSeverity(data['severity']?.toString()),
          category: _parseCategory(data['category']?.toString()),
          source: _parseSource(data['source']?.toString()),
          timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now(),
          isRead: data['isRead'] as bool? ?? false,
          recommendedAction: data['recommendedAction']?.toString() ?? 'Review system status.',
        );
      }).toList();
      _localCache
        ..clear()
        ..addAll(alerts);
      _controller.add(List.unmodifiable(_localCache));
      return alerts;
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
  }

  @override
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _localCache.length; i++) {
      _localCache[i] = _localCache[i].copyWith(isRead: true);
    }
    _controller.add(List.unmodifiable(_localCache));
  }

  @override
  Future<void> deleteAlert(String alertId) async {
    _localCache.removeWhere((a) => a.id == alertId);
    _controller.add(List.unmodifiable(_localCache));
  }

  static AlertSeverity _parseSeverity(String? val) {
    switch (val?.toLowerCase()) {
      case 'critical':
        return AlertSeverity.critical;
      case 'warning':
        return AlertSeverity.warning;
      case 'info':
      default:
        return AlertSeverity.info;
    }
  }

  static AlertCategory _parseCategory(String? val) {
    switch (val?.toLowerCase()) {
      case 'agronomic':
        return AlertCategory.agronomic;
      case 'irrigation':
        return AlertCategory.irrigation;
      case 'connectivity':
        return AlertCategory.connectivity;
      case 'hardware':
      default:
        return AlertCategory.hardware;
    }
  }

  static AlertSource _parseSource(String? val) {
    if (val != null && val.contains('Q')) {
      return AlertSource.monitoringZone(val);
    }
    if (val != null && val.toLowerCase().contains('gateway')) {
      return AlertSource.gateway;
    }
    return AlertSource.centralIrrigation;
  }
}

