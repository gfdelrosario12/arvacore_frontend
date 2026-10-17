/// Enum representing the operational state of manual irrigation override.
enum ManualOverrideModeState {
  idle,
  pendingConfirmation,
  pendingAck,
  active,
  cooldown,
  emergencyStopped,
  failed,
}

/// Represents a manual irrigation command with strict field-wide target scope.
class ManualIrrigationCommand {
  static const String fieldWideScope = 'ENTIRE FIELD';

  final String commandId;
  final String targetScope;
  final int durationMinutes;
  final String action; // 'start', 'stop', 'override', 'emergency_stop'
  final String? rationale;
  final String operatorId;
  final String operatorName;
  final DateTime timestamp;
  final double? targetWaterDepthCm;
  final bool overridePolicy;

  ManualIrrigationCommand({
    required this.commandId,
    this.targetScope = fieldWideScope,
    required this.durationMinutes,
    required this.action,
    this.rationale,
    required this.operatorId,
    required this.operatorName,
    DateTime? timestamp,
    this.targetWaterDepthCm,
    this.overridePolicy = false,
  }) : timestamp = timestamp ?? DateTime.now() {
    if (!_isFieldWideTarget(targetScope)) {
      throw ArgumentError(
        'Manual irrigation strictly targets ENTIRE FIELD. Zone/quadrant scope "$targetScope" is rejected.',
      );
    }
  }

  static bool _isFieldWideTarget(String scope) {
    final normalized = scope.trim().toUpperCase();
    return normalized == 'ENTIRE FIELD' || normalized == 'ENTIRE_FIELD' || normalized == 'FIELD';
  }

  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'targetScope': fieldWideScope,
      'durationMinutes': durationMinutes,
      'action': action,
      'rationale': rationale,
      'operatorId': operatorId,
      'operatorName': operatorName,
      'timestamp': timestamp.toIso8601String(),
      if (targetWaterDepthCm != null) 'targetWaterDepthCm': targetWaterDepthCm,
      'overridePolicy': overridePolicy,
    };
  }

  factory ManualIrrigationCommand.fromJson(Map<String, dynamic> json) {
    return ManualIrrigationCommand(
      commandId: json['commandId'] as String? ?? '',
      targetScope: json['targetScope'] as String? ?? fieldWideScope,
      durationMinutes: json['durationMinutes'] as int? ?? 30,
      action: json['action'] as String? ?? 'start',
      rationale: json['rationale'] as String?,
      operatorId: json['operatorId'] as String? ?? 'unknown',
      operatorName: json['operatorName'] as String? ?? 'Operator',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      targetWaterDepthCm: (json['targetWaterDepthCm'] as num?)?.toDouble(),
      overridePolicy: json['overridePolicy'] as bool? ?? false,
    );
  }
}

/// State container for the centralized manual control interface.
class ManualControlState {
  final ManualOverrideModeState modeState;
  final ManualIrrigationCommand? activeCommand;
  final DateTime? startedAt;
  final int? targetDurationMinutes;
  final DateTime? cooldownUntil;
  final bool isLoading;
  final String? errorMessage;
  final String targetScope;

  const ManualControlState({
    this.modeState = ManualOverrideModeState.idle,
    this.activeCommand,
    this.startedAt,
    this.targetDurationMinutes,
    this.cooldownUntil,
    this.isLoading = false,
    this.errorMessage,
    this.targetScope = ManualIrrigationCommand.fieldWideScope,
  });

  bool get isManualActive => modeState == ManualOverrideModeState.active;
  bool get isPumpRunning => modeState == ManualOverrideModeState.active;
  bool get isPendingAck => modeState == ManualOverrideModeState.pendingAck;
  bool get isInCooldown => modeState == ManualOverrideModeState.cooldown;
  bool get isEmergencyStopped => modeState == ManualOverrideModeState.emergencyStopped;
  bool get canDispatchCommand =>
      !isLoading && modeState != ManualOverrideModeState.pendingAck;

  ManualControlState copyWith({
    ManualOverrideModeState? modeState,
    ManualIrrigationCommand? activeCommand,
    DateTime? startedAt,
    int? targetDurationMinutes,
    DateTime? cooldownUntil,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearActiveCommand = false,
    bool clearCooldown = false,
  }) {
    return ManualControlState(
      modeState: modeState ?? this.modeState,
      activeCommand: clearActiveCommand ? null : (activeCommand ?? this.activeCommand),
      startedAt: startedAt ?? this.startedAt,
      targetDurationMinutes: targetDurationMinutes ?? this.targetDurationMinutes,
      cooldownUntil: clearCooldown ? null : (cooldownUntil ?? this.cooldownUntil),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      targetScope: ManualIrrigationCommand.fieldWideScope,
    );
  }
}

