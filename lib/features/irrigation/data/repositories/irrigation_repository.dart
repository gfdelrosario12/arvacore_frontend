import '../../../../core/api/api_mappers.dart';
import '../../../../core/api/api_services.dart';
import '../../../../core/api/api_dtos.dart';
import '../../domain/models/auto_irrigation_config.dart';
import '../../domain/models/auto_irrigation_status.dart';
import '../../domain/models/centralized_irrigation.dart';
import '../../domain/models/irrigation_execution_audit_log.dart';
import '../../domain/models/manual_irrigation_control.dart';
import '../datasources/irrigation_data_source.dart';


abstract class IrrigationRepository {
  Future<CentralizedIrrigation> fetchSystemStatus();
  Future<CentralizedIrrigation> toggleMainPump(bool active);
  Future<CentralizedIrrigation> updateSystemMode(SystemMode mode);

  Future<AutoIrrigationConfig> getAutoIrrigationConfig({String systemId = 'default'});
  Future<AutoIrrigationConfig> updateAutoIrrigationConfig(AutoIrrigationConfig config);
  Future<AutoIrrigationStatus> getAutoIrrigationStatus({String systemId = 'default'});
  Future<AutoIrrigationStatus> clearFaultLockout({
    String systemId = 'default',
    String? resolutionNote,
    String? clearedBy,
  });
  Future<List<IrrigationExecutionAuditLog>> getAuditLogs({
    String systemId = 'default',
    int limit = 50,
  });
  Future<void> logExecution(IrrigationExecutionAuditLog log);

  Future<bool> dispatchManualStart(ManualIrrigationCommand command);
  Future<bool> dispatchManualStop({required String operatorId, String? rationale});
  Future<bool> dispatchEmergencyStop({required String operatorId, String? rationale});
}

class IrrigationRepositoryImpl implements IrrigationRepository {
  final IrrigationDataSource _dataSource;
  final IrrigationApiService? _apiService;

  IrrigationRepositoryImpl({
    IrrigationDataSource? dataSource,
    IrrigationApiService? apiService,
  })  : _dataSource = dataSource ?? MockIrrigationDataSource(),
        _apiService = apiService;

  @override
  Future<CentralizedIrrigation> fetchSystemStatus() async {
    final apiService = _apiService;
    if (apiService != null) {
      try {
        final result = await apiService.status();
        final central = ApiMappers.centralTelemetry(
          ResourceDto(data: result.data),
        );
        return CentralizedIrrigation(
          id: central.controllerId,
          systemName: 'Main Field Central Pump Controller',
          mainPumpState: central.pumpStatus == PumpStatus.active
              ? PumpState.active
              : (central.pumpStatus == PumpStatus.cooldown
                  ? PumpState.cooldown
                  : PumpState.idle),
          distributionValveState: central.valveStatus == MainValveStatus.open
              ? ValveState.open
              : ValveState.closed,
          flowRateLitersPerMin: central.flowRateLitersPerMin,
          pressureBar: central.linePressureBar,
          mode: SystemMode.manual,
          activeDurationMinutes: central.durationMinutes ?? 0,
          lastStateChange: central.lastUpdated,
        );
      } catch (_) {
        // Fallback to local data source
      }
    }
    return _dataSource.getSystemStatus();
  }

  @override
  Future<CentralizedIrrigation> toggleMainPump(bool active) {
    return _dataSource.toggleMainPumpSimulated(active);
  }

  @override
  Future<CentralizedIrrigation> updateSystemMode(SystemMode mode) {
    return _dataSource.setSystemModeSimulated(mode);
  }

  @override
  Future<AutoIrrigationConfig> getAutoIrrigationConfig({
    String systemId = 'default',
  }) async {
    final apiService = _apiService;
    if (apiService != null) {
      final dto = await apiService.getAutoConfig(systemId: systemId);
      return ApiMappers.autoIrrigationConfig(dto);
    }
    return _dataSource.getAutoIrrigationConfig(systemId: systemId);
  }

  @override
  Future<AutoIrrigationConfig> updateAutoIrrigationConfig(
    AutoIrrigationConfig config,
  ) async {
    final apiService = _apiService;
    if (apiService != null) {
      final dto = ApiMappers.autoIrrigationConfigDto(config);
      final resultDto = await apiService.updateAutoConfig(dto);
      return ApiMappers.autoIrrigationConfig(resultDto);
    }
    return _dataSource.saveAutoIrrigationConfig(config);
  }

  @override
  Future<AutoIrrigationStatus> getAutoIrrigationStatus({
    String systemId = 'default',
  }) async {
    final apiService = _apiService;
    if (apiService != null) {
      final dto = await apiService.getAutoState(systemId: systemId);
      return ApiMappers.autoIrrigationStatus(dto);
    }
    return _dataSource.getAutoIrrigationStatus(systemId: systemId);
  }

  @override
  Future<AutoIrrigationStatus> clearFaultLockout({
    String systemId = 'default',
    String? resolutionNote,
    String? clearedBy,
  }) async {
    final apiService = _apiService;
    if (apiService != null) {
      final request = ClearLockoutRequestDto(
        systemId: systemId,
        resolutionNote: resolutionNote,
        clearedBy: clearedBy,
      );
      final resultDto = await apiService.clearLockout(request);
      return ApiMappers.autoIrrigationStatus(resultDto);
    }
    return _dataSource.clearFaultLockout(
      systemId: systemId,
      resolutionNote: resolutionNote,
      clearedBy: clearedBy,
    );
  }

  @override
  Future<List<IrrigationExecutionAuditLog>> getAuditLogs({
    String systemId = 'default',
    int limit = 50,
  }) async {
    final apiService = _apiService;
    if (apiService != null) {
      final dtoList = await apiService.getAuditLogs(
        systemId: systemId,
        limit: limit,
      );
      return dtoList.items
          .map(ApiMappers.irrigationExecutionAuditLog)
          .toList(growable: false);
    }
    return _dataSource.getAuditLogs(systemId: systemId, limit: limit);
  }

  @override
  Future<void> logExecution(IrrigationExecutionAuditLog log) async {
    return _dataSource.addAuditLog(log);
  }

  @override
  Future<bool> dispatchManualStart(ManualIrrigationCommand command) async {
    final apiService = _apiService;
    if (apiService != null) {
      try {
        await apiService.startManual(
          operatorId: command.operatorId,
          rationale: command.rationale ?? 'Manual irrigation dispatch',
          durationMinutes: command.durationMinutes,
          targetWaterDepthCm: command.targetWaterDepthCm,
          overridePolicy: command.overridePolicy,
        );
      } catch (_) {
        // Fall back to legacy start if needed
        await apiService.start(durationMinutes: command.durationMinutes);
      }
    }
    await updateSystemMode(SystemMode.manual);
    await toggleMainPump(true);
    return true;
  }

  @override
  Future<bool> dispatchManualStop({required String operatorId, String? rationale}) async {
    final apiService = _apiService;
    if (apiService != null) {
      try {
        await apiService.stopManual(
          operatorId: operatorId,
          rationale: rationale ?? 'Manual stop command',
        );
      } catch (_) {
        await apiService.stop();
      }
    }
    await toggleMainPump(false);
    return true;
  }

  @override
  Future<bool> dispatchEmergencyStop({required String operatorId, String? rationale}) async {
    final apiService = _apiService;
    if (apiService != null) {
      try {
        await apiService.emergencyStop(
          operatorId: operatorId,
          reason: rationale ?? 'Emergency stop engaged',
        );
      } catch (_) {
        await apiService.stop();
      }
    }
    await toggleMainPump(false);
    await updateSystemMode(SystemMode.manual);
    return true;
  }
}
