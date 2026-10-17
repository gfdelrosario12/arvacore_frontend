class TelemetryStreamSummary {
  final int totalTransmissions;
  final int recentTransmissionsCount;
  final int distinctNodesCount;
  final int failedOrRejectedCount;
  final DateTime? lastEventReceivedAt;
  final int activeConnectionsCount;

  const TelemetryStreamSummary({
    this.totalTransmissions = 0,
    this.recentTransmissionsCount = 0,
    this.distinctNodesCount = 0,
    this.failedOrRejectedCount = 0,
    this.lastEventReceivedAt,
    this.activeConnectionsCount = 0,
  });

  factory TelemetryStreamSummary.fromJson(Map<String, dynamic> json) {
    return TelemetryStreamSummary(
      totalTransmissions: _asInt(json['totalTransmissions']) ?? 0,
      recentTransmissionsCount: _asInt(json['recentTransmissionsCount']) ?? 0,
      distinctNodesCount: _asInt(json['distinctNodesCount']) ?? 0,
      failedOrRejectedCount: _asInt(json['failedOrRejectedCount']) ?? 0,
      lastEventReceivedAt: DateTime.tryParse(json['lastEventReceivedAt']?.toString() ?? ''),
      activeConnectionsCount: _asInt(json['activeConnectionsCount']) ?? 0,
    );
  }

  TelemetryStreamSummary copyWith({
    int? totalTransmissions,
    int? recentTransmissionsCount,
    int? distinctNodesCount,
    int? failedOrRejectedCount,
    DateTime? lastEventReceivedAt,
    int? activeConnectionsCount,
  }) {
    return TelemetryStreamSummary(
      totalTransmissions: totalTransmissions ?? this.totalTransmissions,
      recentTransmissionsCount: recentTransmissionsCount ?? this.recentTransmissionsCount,
      distinctNodesCount: distinctNodesCount ?? this.distinctNodesCount,
      failedOrRejectedCount: failedOrRejectedCount ?? this.failedOrRejectedCount,
      lastEventReceivedAt: lastEventReceivedAt ?? this.lastEventReceivedAt,
      activeConnectionsCount: activeConnectionsCount ?? this.activeConnectionsCount,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

