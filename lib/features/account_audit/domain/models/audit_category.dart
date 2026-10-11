enum AuditCategory {
  authentication,
  authorization,
  fieldConfig,
  nodeManagement,
  sensorConfig,
  irrigation,
  security,
  system,
}

extension AuditCategoryExtension on AuditCategory {
  String get displayName {
    switch (this) {
      case AuditCategory.authentication:
        return 'Authentication';
      case AuditCategory.authorization:
        return 'Authorization';
      case AuditCategory.fieldConfig:
        return 'Field Configuration';
      case AuditCategory.nodeManagement:
        return 'Node Management';
      case AuditCategory.sensorConfig:
        return 'Sensor Configuration';
      case AuditCategory.irrigation:
        return 'Irrigation';
      case AuditCategory.security:
        return 'Security';
      case AuditCategory.system:
        return 'System';
    }
  }

  static AuditCategory? fromString(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'authentication':
        return AuditCategory.authentication;
      case 'authorization':
        return AuditCategory.authorization;
      case 'fieldconfig':
      case 'field-config':
        return AuditCategory.fieldConfig;
      case 'nodemanagement':
      case 'node-management':
        return AuditCategory.nodeManagement;
      case 'sensormetric':
      case 'sensor-config':
        return AuditCategory.sensorConfig;
      case 'irrigation':
        return AuditCategory.irrigation;
      case 'security':
        return AuditCategory.security;
      case 'system':
        return AuditCategory.system;
      default:
        return null;
    }
  }
}