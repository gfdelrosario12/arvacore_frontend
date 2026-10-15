class NodeDiscoveryInfo {
  final String id;
  final String macAddress;
  final String hardwareModel;
  final String firmwareVersion;
  final int rssiDbm;
  final DateTime detectedAt;

  final int? pairingRequestId;
  final bool recognized;
  final String pairingStatus;
  final String? existingLifecycleState;
  final int? existingZoneId;
  final String? existingZoneName;
  final String? expiresAt;
  final bool isExpired;

  const NodeDiscoveryInfo({
    required this.id,
    required this.macAddress,
    required this.hardwareModel,
    required this.firmwareVersion,
    required this.rssiDbm,
    required this.detectedAt,
    this.pairingRequestId,
    this.recognized = false,
    this.pairingStatus = 'PENDING',
    this.existingLifecycleState,
    this.existingZoneId,
    this.existingZoneName,
    this.expiresAt,
    this.isExpired = false,
  });

  factory NodeDiscoveryInfo.fromJson(Map<String, dynamic> json) {
    return NodeDiscoveryInfo(
      id: json['id']?.toString() ?? '',
      macAddress: json['macAddress']?.toString() ?? '',
      hardwareModel: json['hardwareModel']?.toString() ?? 'ESP32 Wi-Fi Node',
      firmwareVersion: json['firmwareVersion']?.toString() ?? '1.0.0',
      rssiDbm: int.tryParse(json['rssiDbm']?.toString() ?? '') ?? -70,
      detectedAt:
          DateTime.tryParse(json['detectedAt']?.toString() ?? '') ?? DateTime.now(),
      pairingRequestId: json['pairingRequestId'] is int
          ? json['pairingRequestId'] as int
          : int.tryParse(json['pairingRequestId']?.toString() ?? ''),
      recognized: json['recognized'] == true,
      pairingStatus: json['pairingStatus']?.toString() ?? 'PENDING',
      existingLifecycleState: json['existingLifecycleState']?.toString(),
      existingZoneId: json['existingZoneId'] is int
          ? json['existingZoneId'] as int
          : int.tryParse(json['existingZoneId']?.toString() ?? ''),
      existingZoneName: json['existingZoneName']?.toString(),
      expiresAt: json['expiresAt']?.toString(),
      isExpired: json['isExpired'] == true ||
          json['expired'] == true ||
          json['pairingStatus']?.toString().toUpperCase() == 'EXPIRED',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'macAddress': macAddress,
        'hardwareModel': hardwareModel,
        'firmwareVersion': firmwareVersion,
        'rssiDbm': rssiDbm,
        'detectedAt': detectedAt.toIso8601String(),
      };
}

