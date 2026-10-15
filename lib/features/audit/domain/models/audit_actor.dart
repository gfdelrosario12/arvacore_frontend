enum AuditActorType { user, system, emergencyOverride }

class AuditActor {
  final AuditActorType type;
  final String id;
  final String displayName;

  const AuditActor({
    required this.type,
    required this.id,
    required this.displayName,
  });

  factory AuditActor.user(String id, String displayName) {
    return AuditActor(
      type: AuditActorType.user,
      id: id,
      displayName: displayName,
    );
  }

  factory AuditActor.system([String id = 'system-auto', String displayName = 'ArvaCore System']) {
    return AuditActor(
      type: AuditActorType.system,
      id: id,
      displayName: displayName,
    );
  }

  factory AuditActor.emergencyOverride(String id, String displayName) {
    return AuditActor(
      type: AuditActorType.emergencyOverride,
      id: id,
      displayName: displayName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'id': id,
      'displayName': displayName,
    };
  }

  factory AuditActor.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'system';
    final actorType = AuditActorType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => AuditActorType.system,
    );

    return AuditActor(
      type: actorType,
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuditActor &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id &&
          displayName == other.displayName;

  @override
  int get hashCode => type.hashCode ^ id.hashCode ^ displayName.hashCode;
}

