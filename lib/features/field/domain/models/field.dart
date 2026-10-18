/// Phenological growth stages of rice determining active AWD threshold tolerance.
enum CropStage {
  /// Land preparation, soaking, and leveling phase (saturated).
  landPrep,

  /// Seedling nursery or direct seeded emergence.
  seedling,

  /// Early tillering and vegetative growth (optimal for AWD drying cycles).
  vegetativeTillering,

  /// Panicle initiation to booting (critical sensitivity: no severe drying).
  panicleInitiation,

  /// Flowering, pollination, and heading (standing water required).
  floweringHeading,

  /// Grain filling and milk-to-dough stage (safe AWD drying).
  grainFilling,

  /// Terminal drainage prior to harvest (drying field for combine harvesters).
  ripeningHarvest,
}

/// Represents the top-level agricultural field / paddy deployment boundary.
class Field {
  final String id;
  final String name;
  final String? description;
  final double areaSquareMeters;
  final double? lengthMeters;
  final double? widthMeters;
  final double? totalArea;
  final String areaUnit; // 'hectares', 'sqm', 'acres'
  final String shapeType; // 'RECTANGULAR', 'IRREGULAR', 'POLYGON'
  final String operationalStatus; // 'DRAFT', 'INCOMPLETE', 'READY', 'MONITORING', 'DEGRADED', 'INACTIVE'
  final String? locationAddress;
  final String? ownerUsername;
  final String soilType;
  final CropStage activeCropStage;
  final String awdProfileId;
  final String? centralControllerId;
  final List<Map<String, double>> boundaryCoordinates;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  const Field({
    required this.id,
    required this.name,
    this.description,
    this.areaSquareMeters = 10000.0,
    this.lengthMeters,
    this.widthMeters,
    this.totalArea,
    this.areaUnit = 'hectares',
    this.shapeType = 'RECTANGULAR',
    this.operationalStatus = 'READY',
    this.locationAddress,
    this.ownerUsername,
    this.soilType = 'Clay Loam',
    this.activeCropStage = CropStage.vegetativeTillering,
    this.awdProfileId = 'awd_standard_vegetative',
    this.centralControllerId,
    this.boundaryCoordinates = const [],
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  Field copyWith({
    String? id,
    String? name,
    String? description,
    double? areaSquareMeters,
    double? lengthMeters,
    double? widthMeters,
    double? totalArea,
    String? areaUnit,
    String? shapeType,
    String? operationalStatus,
    String? locationAddress,
    String? ownerUsername,
    String? soilType,
    CropStage? activeCropStage,
    String? awdProfileId,
    String? centralControllerId,
    List<Map<String, double>>? boundaryCoordinates,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Field(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      areaSquareMeters: areaSquareMeters ?? this.areaSquareMeters,
      soilType: soilType ?? this.soilType,
      activeCropStage: activeCropStage ?? this.activeCropStage,
      awdProfileId: awdProfileId ?? this.awdProfileId,
      centralControllerId: centralControllerId ?? this.centralControllerId,
      boundaryCoordinates: boundaryCoordinates ?? this.boundaryCoordinates,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      lengthMeters: lengthMeters ?? this.lengthMeters,
      widthMeters: widthMeters ?? this.widthMeters,
      totalArea: totalArea ?? this.totalArea,
      areaUnit: areaUnit ?? this.areaUnit,
      shapeType: shapeType ?? this.shapeType,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      locationAddress: locationAddress ?? this.locationAddress,
      ownerUsername: ownerUsername ?? this.ownerUsername,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'areaSquareMeters': areaSquareMeters,
        if (lengthMeters != null) 'lengthMeters': lengthMeters,
        if (widthMeters != null) 'widthMeters': widthMeters,
        if (totalArea != null) 'totalArea': totalArea,
        'areaUnit': areaUnit,
        'shapeType': shapeType,
        'operationalStatus': operationalStatus,
        if (locationAddress != null) 'locationAddress': locationAddress,
        if (ownerUsername != null) 'ownerUsername': ownerUsername,
        'soilType': soilType,
        'activeCropStage': activeCropStage.name,
        'awdProfileId': awdProfileId,
        if (centralControllerId != null)
          'centralControllerId': centralControllerId,
        'boundaryCoordinates': boundaryCoordinates,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  factory Field.fromJson(Map<String, dynamic> json) {
    return Field(
      id: json['id']?.toString() ?? '1',
      name: json['name'] as String? ?? 'Farm',
      description: json['description'] as String?,
      areaSquareMeters:
          (json['areaSquareMeters'] as num?)?.toDouble() ??
          ((json['totalArea'] as num?)?.toDouble() != null ? (json['totalArea'] as num).toDouble() * 10000.0 : 10000.0),
      lengthMeters: (json['lengthMeters'] as num?)?.toDouble() ?? (json['length_meters'] as num?)?.toDouble(),
      widthMeters: (json['widthMeters'] as num?)?.toDouble() ?? (json['width_meters'] as num?)?.toDouble(),
      totalArea: (json['totalArea'] as num?)?.toDouble() ?? (json['total_area'] as num?)?.toDouble() ?? (json['areaHectares'] as num?)?.toDouble(),
      areaUnit: json['areaUnit'] as String? ?? json['area_unit'] as String? ?? 'hectares',
      shapeType: json['shapeType'] as String? ?? json['shape_type'] as String? ?? 'RECTANGULAR',
      operationalStatus: json['operationalStatus'] as String? ?? json['operational_status'] as String? ?? 'READY',
      locationAddress: json['locationAddress'] as String? ?? json['location_address'] as String?,
      ownerUsername: json['ownerUsername'] as String? ?? json['owner_username'] as String?,
      soilType: json['soilType'] as String? ?? 'Clay Loam',
      activeCropStage: CropStage.values.firstWhere(
        (e) => e.name == json['activeCropStage'],
        orElse: () => CropStage.vegetativeTillering,
      ),
      awdProfileId: json['awdProfileId'] as String? ?? 'awd_standard_vegetative',
      centralControllerId: json['centralControllerId'] as String?,
      boundaryCoordinates: (json['boundaryCoordinates'] as List<dynamic>?)
              ?.map((item) => (item as Map<String, dynamic>)
                  .map((k, v) => MapEntry(k, (v as num).toDouble())))
              .toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

