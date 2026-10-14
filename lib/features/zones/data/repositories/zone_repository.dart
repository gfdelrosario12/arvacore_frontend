import '../../../../core/api/api_services.dart';
import '../../domain/models/monitoring_zone.dart';
import '../datasources/zone_data_source.dart';
import 'api_zone_repository.dart';

abstract class ZoneRepository {
  Future<List<MonitoringZone>> fetchMonitoringZones({
    ZoneMockState mockState = ZoneMockState.normal,
  });
  Future<MonitoringZone?> fetchZoneDetails(
    String code, {
    ZoneMockState mockState = ZoneMockState.normal,
  });
  Future<MonitoringZone?> fetchZoneById(
    String id, {
    ZoneMockState mockState = ZoneMockState.normal,
  });
}

class ZoneRepositoryImpl implements ZoneRepository {
  final ZoneDataSource _dataSource;
  final ApiZoneRepository? _apiRepository;

  ZoneRepositoryImpl({
    ZoneDataSource? dataSource,
    FieldApiService? fieldApiService,
  })  : _dataSource = dataSource ?? MockZoneDataSource(),
        _apiRepository = fieldApiService != null ? ApiZoneRepository(fieldApiService) : null;

  @override
  Future<List<MonitoringZone>> fetchMonitoringZones({
    ZoneMockState mockState = ZoneMockState.normal,
  }) async {
    if (_apiRepository != null && mockState == ZoneMockState.normal) {
      try {
        final zones = await _apiRepository.fetchMonitoringZones(mockState: mockState);
        if (zones.isNotEmpty) return zones;
      } catch (_) {
        // Fall back to local mock data
      }
    }
    return _dataSource.getMonitoringZones(mockState: mockState);
  }

  @override
  Future<MonitoringZone?> fetchZoneDetails(
    String code, {
    ZoneMockState mockState = ZoneMockState.normal,
  }) {
    return _dataSource.getZoneByCode(code, mockState: mockState);
  }

  @override
  Future<MonitoringZone?> fetchZoneById(
    String id, {
    ZoneMockState mockState = ZoneMockState.normal,
  }) async {
    final zones = await _dataSource.getMonitoringZones(mockState: mockState);
    try {
      return zones.firstWhere((z) => z.id == id);
    } catch (_) {
      return null;
    }
  }
}
