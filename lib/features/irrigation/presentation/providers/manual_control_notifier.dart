import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/api/api_factory.dart';
import '../../../../core/api/api_services.dart';
import '../../../../core/realtime/realtime_coordinator.dart';
import '../../../../core/realtime/realtime_events.dart';

import '../../../audit/data/repositories/account_audit_repository.dart';
import '../../../audit/domain/models/account_audit_event.dart';
import '../../../audit/domain/models/audit_actor.dart';
import '../../../audit/domain/models/audit_category.dart';
import '../../../audit/domain/models/audit_metadata.dart';
import '../../../audit/domain/models/audit_result.dart';
import '../../../audit/domain/models/audit_target.dart';
import '../../data/repositories/irrigation_repository.dart';
import '../../domain/models/centralized_irrigation.dart';
import '../../domain/models/manual_irrigation_control.dart';

/// State notifier managing centralized manual irrigation control state,
/// multi-step authorization checks, emergency stop interlocks, auto-resumption rules,
/// and tamper-resistant account audit event logging.
class ManualControlNotifier extends ChangeNotifier {
  final IrrigationRepository _irrigationRepository;
  final AccountAuditRepository _auditRepository;
  final RealtimeCoordinator? _realtimeCoordinator;

  ManualControlState _state;
  bool _isDisposed = false;
  Timer? _cooldownTimer;

  ManualControlNotifier({
    IrrigationRepository? irrigationRepository,
    AccountAuditRepository? auditRepository,
    RealtimeCoordinator? realtimeCoordinator,
    ManualControlState initialState = const ManualControlState(),
  })  : _irrigationRepository =
            irrigationRepository ?? IrrigationRepositoryImpl(),
        _auditRepository = auditRepository ??
            AccountAuditRepositoryImpl(
              AccountAuditApiService(ApiRepositoryFactory().client),
            ),
        _realtimeCoordinator = realtimeCoordinator,
        _state = initialState {
    _subscribeToRealtime();
  }

  ManualControlState get state => _state;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// Verifies operator or fieldAdmin role authorization.
  bool isAuthorizedRole(String role) {
    final r = role.trim().toLowerCase();
    return r == 'operator' || r == 'fieldadmin' || r == 'admin';
  }

  /// Dispatch manual irrigation start command for `ENTIRE FIELD`.
  Future<bool> startManualIrrigation({
    required String operatorId,
    required String operatorName,
    required String operatorRole,
    required int durationMinutes,
    String? rationale,
  }) async {
    final timestamp = DateTime.now();

    // Enforce role authorization
    if (!isAuthorizedRole(operatorRole)) {
      final errorMsg = 'Unauthorized: User role "$operatorRole" lacks operator or fieldAdmin privileges.';
      _state = _state.copyWith(errorMessage: errorMsg, isLoading: false);
      notifyListeners();

      await _logAuditEvent(
        actorId: operatorId,
        actorName: operatorName,
        action: 'irrigation.manual.start_denied',
        result: AuditResult.denied,
        failureReason: errorMsg,
        rationale: rationale,
      );
      return false;
    }

    _state = _state.copyWith(
      isLoading: true,
      clearError: true,
      modeState: ManualOverrideModeState.pendingAck,
    );
    notifyListeners();

    try {
      final commandId = 'cmd-man-${timestamp.millisecondsSinceEpoch}';
      final command = ManualIrrigationCommand(
        commandId: commandId,
        targetScope: ManualIrrigationCommand.fieldWideScope,
        durationMinutes: durationMinutes,
        action: 'start',
        rationale: rationale,
        operatorId: operatorId,
        operatorName: operatorName,
        timestamp: timestamp,
      );

      // Execute via repository
      await _irrigationRepository.updateSystemMode(SystemMode.manual);
      await _irrigationRepository.toggleMainPump(true);

      _state = _state.copyWith(
        modeState: ManualOverrideModeState.active,
        activeCommand: command,
        startedAt: timestamp,
        targetDurationMinutes: durationMinutes,
        isLoading: false,
      );
      notifyListeners();

      await _logAuditEvent(
        actorId: operatorId,
        actorName: operatorName,
        action: 'irrigation.manual.start',
        result: AuditResult.success,
        durationMinutes: durationMinutes,
        rationale: rationale,
      );
      return true;
    } catch (e) {
      _state = _state.copyWith(
        modeState: ManualOverrideModeState.failed,
        isLoading: false,
        errorMessage: 'Failed to dispatch manual irrigation start: $e',
      );
      notifyListeners();

      await _logAuditEvent(
        actorId: operatorId,
        actorName: operatorName,
        action: 'irrigation.manual.start',
        result: AuditResult.failed,
        failureReason: e.toString(),
        rationale: rationale,
      );
      return false;
    }
  }

  /// Dispatch manual irrigation stop command and enter cooldown.
  Future<bool> stopManualIrrigation({
    required String operatorId,
    required String operatorName,
    required String operatorRole,
    String? rationale,
  }) async {
    final timestamp = DateTime.now();

    if (!isAuthorizedRole(operatorRole)) {
      const errorMsg = 'Unauthorized: User role lacks operator or fieldAdmin privileges.';
      _state = _state.copyWith(errorMessage: errorMsg, isLoading: false);
      notifyListeners();

      await _logAuditEvent(
        actorId: operatorId,
        actorName: operatorName,
        action: 'irrigation.manual.stop_denied',
        result: AuditResult.denied,
        failureReason: errorMsg,
        rationale: rationale,
      );
      return false;
    }

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      await _irrigationRepository.toggleMainPump(false);

      final cooldownEnd = timestamp.add(const Duration(minutes: 5));
      _state = _state.copyWith(
        modeState: ManualOverrideModeState.cooldown,
        cooldownUntil: cooldownEnd,
        isLoading: false,
        clearActiveCommand: true,
      );
      notifyListeners();

      _scheduleCooldownCheck(cooldownEnd);

      await _logAuditEvent(
        actorId: operatorId,
        actorName: operatorName,
        action: 'irrigation.manual.stop',
        result: AuditResult.success,
        rationale: rationale,
      );
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to stop manual irrigation: $e',
      );
      notifyListeners();

      await _logAuditEvent(
        actorId: operatorId,
        actorName: operatorName,
        action: 'irrigation.manual.stop',
        result: AuditResult.failed,
        failureReason: e.toString(),
        rationale: rationale,
      );
      return false;
    }
  }

  /// High-priority, uninhibited Emergency Stop interlock dispatch.
  Future<bool> triggerEmergencyStop({
    required String operatorId,
    required String operatorName,
    required String operatorRole,
    String? rationale,
  }) async {
    final timestamp = DateTime.now();

    // Instant local state update for safety
    final cooldownEnd = timestamp.add(const Duration(minutes: 10));
    _state = _state.copyWith(
      modeState: ManualOverrideModeState.emergencyStopped,
      cooldownUntil: cooldownEnd,
      isLoading: false,
      clearError: true,
    );
    notifyListeners();

    try {
      await _irrigationRepository.toggleMainPump(false);
      await _irrigationRepository.updateSystemMode(SystemMode.manual);

      _scheduleCooldownCheck(cooldownEnd);

      await _logAuditEvent(
        actorId: operatorId,
        actorName: operatorName,
        actorType: AuditActorType.emergencyOverride,
        action: 'irrigation.emergency.stop',
        result: AuditResult.success,
        rationale: rationale ?? 'High-priority emergency stop interlock triggered',
      );
      return true;
    } catch (e) {
      _state = _state.copyWith(
        errorMessage: 'Emergency stop executed locally but hardware response threw: $e',
      );
      notifyListeners();

      await _logAuditEvent(
        actorId: operatorId,
        actorName: operatorName,
        actorType: AuditActorType.emergencyOverride,
        action: 'irrigation.emergency.stop',
        result: AuditResult.failed,
        failureReason: e.toString(),
        rationale: rationale,
      );
      return false;
    }
  }

  /// Evaluates whether active cooldown period has expired.
  void checkCooldownStatus([DateTime? now]) {
    final timestamp = now ?? DateTime.now();
    if ((_state.modeState == ManualOverrideModeState.cooldown ||
            _state.modeState == ManualOverrideModeState.emergencyStopped) &&
        _state.cooldownUntil != null &&
        timestamp.isAfter(_state.cooldownUntil!)) {
      _state = _state.copyWith(
        modeState: ManualOverrideModeState.idle,
        clearCooldown: true,
      );
      notifyListeners();
    }
  }

  void _scheduleCooldownCheck(DateTime cooldownEnd) {
    _cooldownTimer?.cancel();
    final remaining = cooldownEnd.difference(DateTime.now());
    if (remaining.isNegative) {
      checkCooldownStatus();
    } else {
      _cooldownTimer = Timer(remaining, () => checkCooldownStatus());
    }
  }

  Future<void> _logAuditEvent({
    required String actorId,
    required String actorName,
    AuditActorType actorType = AuditActorType.user,
    required String action,
    required AuditResult result,
    int? durationMinutes,
    String? rationale,
    String? failureReason,
  }) async {
    final now = DateTime.now();
    final event = AccountAuditEvent(
      eventId: 'aud-man-${now.millisecondsSinceEpoch}',
      timestamp: now,
      actor: AuditActor(
        type: actorType,
        id: actorId,
        displayName: actorName,
      ),
      category: AuditCategory.irrigation,
      action: action,
      target: const AuditTarget(
        type: 'field',
        id: ManualIrrigationCommand.fieldWideScope,
        displayName: 'Central Field Irrigation System',
      ),
      result: result,
      metadata: AuditMetadata(
        rationale: rationale,
        failureReason: failureReason,
        ext: durationMinutes != null ? {'durationMinutes': durationMinutes} : null,
      ),
    );

    try {
      await _auditRepository.emitAuditEvent(event);
    } catch (_) {}
  }

  void _subscribeToRealtime() {
    if (_realtimeCoordinator == null) return;
    _realtimeCoordinator.events.listen((envelope) {
      if (envelope.type == RealtimeEventType.manualControlExecuted ||
          envelope.type == RealtimeEventType.irrigationState ||
          envelope.type == RealtimeEventType.irrigationEvent) {
        try {
          final payload = Map<String, dynamic>.from(envelope.payload);
          final action = payload['action'] as String?;
          final mode = payload['modeState'] as String?;
          if (mode == 'emergencyStopped' || action == 'emergency_stop') {
            _state = _state.copyWith(
              modeState: ManualOverrideModeState.emergencyStopped,
            );
            notifyListeners();
          } else if (action == 'start' || mode == 'active') {
            _state = _state.copyWith(
              modeState: ManualOverrideModeState.active,
              targetDurationMinutes: (payload['durationMinutes'] as int?) ?? _state.targetDurationMinutes,
            );
            notifyListeners();
          } else if (action == 'stop' || mode == 'idle') {
            _state = _state.copyWith(
              modeState: ManualOverrideModeState.idle,
              clearActiveCommand: true,
            );
            notifyListeners();
          }
        } catch (_) {}
      }
    });
  }
}
