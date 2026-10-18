import '../../../../core/api/api_mappers.dart';
import '../../../../core/api/api_services.dart';
import '../datasources/zone_data_source.dart';
import '../../domain/models/monitoring_zone.dart';
import 'zone_repository.dart';

class ApiZoneRepository implements ZoneRepository {
  final FieldApiService api;

  ApiZoneRepository(this.api);

  @override
  Future<List<MonitoringZone>> fetchMonitoringZones({
    ZoneMockState mockState = ZoneMockState.normal,
    String? fieldId,
  }) async {
    final response = await api.listQuarters(fieldId: fieldId);
    return response.items
        .map(ApiMappers.monitoringZone)
        .where((z) => !z.isArchived && z.operationalStatus.toUpperCase() != 'ARCHIVED')
        .toList(growable: false);
  }

  @override
  Future<MonitoringZone?> fetchZoneDetails(
    String code, {
    ZoneMockState mockState = ZoneMockState.normal,
  }) async {
    final response = await api.getQuarter(code);
    return ApiMappers.monitoringZone(response);
  }

  @override
  Future<MonitoringZone?> fetchZoneById(
    String zoneId, {
    ZoneMockState mockState = ZoneMockState.normal,
  }) async {
    final zones = await fetchMonitoringZones(mockState: mockState);
    for (final z in zones) {
      if (z.id == zoneId) return z;
    }
    return null;
  }

  @override
  Future<MonitoringZone> createZone({
    required String name,
    required double area,
    required String cropType,
    double? waterAllocationLimit,
  }) async {
    final response = await api.createZone(
      name: name,
      area: area,
      cropType: cropType,
      waterAllocationLimit: waterAllocationLimit,
    );
    return ApiMappers.monitoringZone(response);
  }

  @override
  Future<void> deleteZone(String id, {String? fieldId}) async {
    await api.deleteZone(id, fieldId: fieldId);
  }
}
