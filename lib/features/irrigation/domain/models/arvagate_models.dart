class ArvaGateModel {
  final int gateIndex;
  final String gateLabel;
  final String currentState; // OPEN, CLOSED, OPENING, CLOSING, STOPPED, FAULT
  final String requestedState;
  final bool physicalConfirmed;
  final DateTime? lastActuatedAt;
  final String? faultMessage;

  ArvaGateModel({
    required this.gateIndex,
    required this.gateLabel,
    required this.currentState,
    required this.requestedState,
    required this.physicalConfirmed,
    this.lastActuatedAt,
    this.faultMessage,
  });

  bool get isOpen => currentState.toUpperCase() == 'OPEN';
  bool get isClosed => currentState.toUpperCase() == 'CLOSED';
  bool get isActuating => currentState.toUpperCase() == 'OPENING' || currentState.toUpperCase() == 'CLOSING';

  factory ArvaGateModel.fromJson(Map<String, dynamic> json) {
    return ArvaGateModel(
      gateIndex: json['gateIndex'] as int? ?? 1,
      gateLabel: json['gateLabel'] as String? ?? 'Gate',
      currentState: json['currentState'] as String? ?? 'CLOSED',
      requestedState: json['requestedState'] as String? ?? 'CLOSED',
      physicalConfirmed: json['physicalConfirmed'] as bool? ?? false,
      lastActuatedAt: json['lastActuatedAt'] != null ? DateTime.tryParse(json['lastActuatedAt'] as String) : null,
      faultMessage: json['faultMessage'] as String?,
    );
  }
}

class ArvaGateEventModel {
  final int? gateIndex;
  final String eventType;
  final String? previousState;
  final String? newState;
  final String? details;
  final String actor;
  final DateTime createdAt;

  ArvaGateEventModel({
    this.gateIndex,
    required this.eventType,
    this.previousState,
    this.newState,
    this.details,
    required this.actor,
    required this.createdAt,
  });

  factory ArvaGateEventModel.fromJson(Map<String, dynamic> json) {
    return ArvaGateEventModel(
      gateIndex: json['gateIndex'] as int?,
      eventType: json['eventType'] as String? ?? 'EVENT',
      previousState: json['previousState'] as String?,
      newState: json['newState'] as String?,
      details: json['details'] as String?,
      actor: json['actor'] as String? ?? 'SYSTEM',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class ArvaGateSubsystemStatus {
  final String deviceId;
  final String displayName;
  final String connectivityStatus;
  final DateTime? lastSeenAt;
  final List<ArvaGateModel> gates;
  final List<ArvaGateEventModel> recentEvents;

  ArvaGateSubsystemStatus({
    required this.deviceId,
    required this.displayName,
    required this.connectivityStatus,
    this.lastSeenAt,
    required this.gates,
    required this.recentEvents,
  });

  bool get isOnline => connectivityStatus.toUpperCase() == 'ONLINE';

  factory ArvaGateSubsystemStatus.fromJson(Map<String, dynamic> json) {
    final dev = json['device'] as Map<String, dynamic>? ?? {};
    final gatesList = (json['gates'] as List<dynamic>? ?? [])
        .map((e) => ArvaGateModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final eventsList = (json['recentEvents'] as List<dynamic>? ?? [])
        .map((e) => ArvaGateEventModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ArvaGateSubsystemStatus(
      deviceId: dev['deviceId'] as String? ?? 'ARVAGATE-CTRL-01',
      displayName: dev['displayName'] as String? ?? 'ArvaGate Central Canal Controller',
      connectivityStatus: dev['connectivityStatus'] as String? ?? 'ONLINE',
      lastSeenAt: dev['lastSeenAt'] != null ? DateTime.tryParse(dev['lastSeenAt'] as String) : null,
      gates: gatesList,
      recentEvents: eventsList,
    );
  }
}

