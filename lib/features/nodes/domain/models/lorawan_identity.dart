/// Network link quality metrics for a LoRaWAN RF reception.
class LoRaWANLinkQuality {
  final double rssiDbm;
  final double snrDb;
  final String? gatewayId;
  final int? frequencyHz;
  final String? spreadingFactor;

  const LoRaWANLinkQuality({
    required this.rssiDbm,
    required this.snrDb,
    this.gatewayId,
    this.frequencyHz,
    this.spreadingFactor,
  });

  Map<String, dynamic> toJson() => {
        'rssiDbm': rssiDbm,
        'snrDb': snrDb,
        if (gatewayId != null) 'gatewayId': gatewayId,
        if (frequencyHz != null) 'frequencyHz': frequencyHz,
        if (spreadingFactor != null) 'spreadingFactor': spreadingFactor,
      };

  factory LoRaWANLinkQuality.fromJson(Map<String, dynamic> json) {
    return LoRaWANLinkQuality(
      rssiDbm: (json['rssiDbm'] as num).toDouble(),
      snrDb: (json['snrDb'] as num).toDouble(),
      gatewayId: json['gatewayId'] as String?,
      frequencyHz: json['frequencyHz'] as int?,
      spreadingFactor: json['spreadingFactor'] as String?,
    );
  }
}

/// Hardware identity credentials and frame session state for a LoRaWAN end-device node.
class LoRaWANIdentity {
  final String devEui;
  final String joinEui;
  final String? appKey;
  final String? devAddr;
  final int fCntUp;
  final int fCntDown;
  final LoRaWANLinkQuality? linkQuality;
  final String? lastGatewayId;
  final DateTime? lastSeen;
  final String? downlinkStatus;

  const LoRaWANIdentity({
    required this.devEui,
    required this.joinEui,
    this.appKey,
    this.devAddr,
    this.fCntUp = 0,
    this.fCntDown = 0,
    this.linkQuality,
    this.lastGatewayId,
    this.lastSeen,
    this.downlinkStatus,
  });

  LoRaWANIdentity copyWith({
    String? devEui,
    String? joinEui,
    String? appKey,
    String? devAddr,
    int? fCntUp,
    int? fCntDown,
    LoRaWANLinkQuality? linkQuality,
    String? lastGatewayId,
    DateTime? lastSeen,
    String? downlinkStatus,
  }) {
    return LoRaWANIdentity(
      devEui: devEui ?? this.devEui,
      joinEui: joinEui ?? this.joinEui,
      appKey: appKey ?? this.appKey,
      devAddr: devAddr ?? this.devAddr,
      fCntUp: fCntUp ?? this.fCntUp,
      fCntDown: fCntDown ?? this.fCntDown,
      linkQuality: linkQuality ?? this.linkQuality,
      lastGatewayId: lastGatewayId ?? this.lastGatewayId,
      lastSeen: lastSeen ?? this.lastSeen,
      downlinkStatus: downlinkStatus ?? this.downlinkStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'devEui': devEui,
        'joinEui': joinEui,
        if (appKey != null) 'appKey': appKey,
        if (devAddr != null) 'devAddr': devAddr,
        'fCntUp': fCntUp,
        'fCntDown': fCntDown,
        if (linkQuality != null) 'linkQuality': linkQuality!.toJson(),
        if (lastGatewayId != null) 'lastGatewayId': lastGatewayId,
        if (lastSeen != null) 'lastSeen': lastSeen!.toIso8601String(),
        if (downlinkStatus != null) 'downlinkStatus': downlinkStatus,
      };

  factory LoRaWANIdentity.fromJson(Map<String, dynamic> json) {
    return LoRaWANIdentity(
      devEui: json['devEui'] as String,
      joinEui: json['joinEui'] as String? ?? json['appEui'] as String? ?? '0000000000000000',
      appKey: json['appKey'] as String?,
      devAddr: json['devAddr'] as String?,
      fCntUp: json['fCntUp'] as int? ?? 0,
      fCntDown: json['fCntDown'] as int? ?? 0,
      linkQuality: json['linkQuality'] != null
          ? LoRaWANLinkQuality.fromJson(
              json['linkQuality'] as Map<String, dynamic>,
            )
          : null,
      lastGatewayId: json['lastGatewayId'] as String?,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
      downlinkStatus: json['downlinkStatus'] as String?,
    );
  }
}

