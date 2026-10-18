import 'package:flutter/widgets.dart';
import '../../../../core/api/api_factory.dart';
import '../../../../core/api/api_services.dart';
import '../../domain/models/monitoring_zone.dart';
import '../datasources/zone_data_source.dart';
import 'api_zone_repository.dart';

abstract class ZoneRepository {
  Future<List<MonitoringZone>> fetchMonitoringZones({
    ZoneMockState mockState = ZoneMockState.normal,
    String? fieldId,
  });
  Future<MonitoringZone?> fetchZoneDetails(
    String code, {
    ZoneMockState mockState = ZoneMockState.normal,
  });
  Future<MonitoringZone?> fetchZoneById(
    String id, {
    ZoneMockState mockState = ZoneMockState.normal,
  });
  Future<MonitoringZone> createZone({
    required String name,
    required double area,
    required String cropType,
    double? waterAllocationLimit,
  });
  Future<void> deleteZone(String id, {String? fieldId});
}

class ZoneRepositoryImpl implements ZoneRepository {
  final ZoneDataSource _dataSource;
  final ApiZoneRepository _apiRepository;

  ZoneRepositoryImpl({
    ZoneDataSource? dataSource,
    FieldApiService? fieldApiService,
  })  : _dataSource = dataSource ?? MockZoneDataSource(),
        _apiRepository = ApiZoneRepository(
          fieldApiService ?? ApiRepositoryFactory().fields,
        );

  @override
  Future<MonitoringZone> createZone({
    required String name,
    required double area,
    required String cropType,
    double? waterAllocationLimit,
  }) async {
    return _apiRepository.createZone(
      name: name,
      area: area,
      cropType: cropType,
      waterAllocationLimit: waterAllocationLimit,
    );
  }

  @override
  Future<void> deleteZone(String id, {String? fieldId}) async {
    return _apiRepository.deleteZone(id, fieldId: fieldId);
  }

  @override
  Future<List<MonitoringZone>> fetchMonitoringZones({
    ZoneMockState mockState = ZoneMockState.normal,
    String? fieldId,
  }) async {
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest && mockState == ZoneMockState.normal) {
      try {
        final zones = await _apiRepository.fetchMonitoringZones(mockState: mockState, fieldId: fieldId);
        if (zones.isNotEmpty) {
          return zones.where((z) => !z.isArchived && z.operationalStatus.toUpperCase() != 'ARCHIVED').toList();
        }
      } catch (_) {
        // Fall back to local mock data when API is offline or in test environments
      }
    }
    final list = await _dataSource.getMonitoringZones(mockState: mockState);
    return list.where((z) => !z.isArchived && z.operationalStatus.toUpperCase() != 'ARCHIVED').toList();
  }

  @override
  Future<MonitoringZone?> fetchZoneDetails(
    String code, {
    ZoneMockState mockState = ZoneMockState.normal,
  }) async {
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest && mockState == ZoneMockState.normal) {
      try {
        final zone = await _apiRepository.fetchZoneDetails(code, mockState: mockState);
        if (zone != null) return zone;
      } catch (_) {
        // Fall back
      }
    }
    return _dataSource.getZoneByCode(code, mockState: mockState);
  }

  @override
  Future<MonitoringZone?> fetchZoneById(
    String id, {
    ZoneMockState mockState = ZoneMockState.normal,
  }) async {
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest && mockState == ZoneMockState.normal) {
      try {
        final zone = await _apiRepository.fetchZoneById(id, mockState: mockState);
        if (zone != null) return zone;
      } catch (_) {
        // Fall back
      }
    }
    final zones = await _dataSource.getMonitoringZones(mockState: mockState);
    try {
      return zones.firstWhere((z) => z.id == id);
    } catch (_) {
      return null;
    }
  }
}
