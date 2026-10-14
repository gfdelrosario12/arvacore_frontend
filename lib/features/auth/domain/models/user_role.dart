/// Canonical authorization roles for field-scoped access in AquaSense.
///
/// Roles are mutually exclusive per field membership and MUST NOT be aliased
/// or extended client-side. The backend is always authoritative.
enum UserRole {
  /// Full administrative control: field topology, user management, all
  /// operator-level operations.
  fieldAdmin,

  /// Operations on sensor nodes, irrigation commands, automation config,
  /// and fault lockout clearance.
  operator,

  /// Read-only access to monitoring data, telemetry, alerts, and analytics.
  viewer;

  /// Parses a role string from a JWT claim or API response.
  ///
  /// Returns `null` for any unrecognized value so the caller can treat the
  /// session as unauthorized rather than silently granting the wrong role.
  static UserRole? fromString(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'role_admin':
      case 'admin':
      case 'field_admin':
      case 'fieldadmin':
        return UserRole.fieldAdmin;
      case 'role_operator':
      case 'operator':
      case 'role_user':
      case 'user':
        return UserRole.operator;
      case 'role_viewer':
      case 'viewer':
        return UserRole.viewer;
      default:
        return UserRole.operator;
    }
  }

  /// Returns the canonical string representation used in JWT claims.
  String get claimValue {
    switch (this) {
      case UserRole.fieldAdmin:
        return 'field_admin';
      case UserRole.operator:
        return 'operator';
      case UserRole.viewer:
        return 'viewer';
    }
  }

  /// Human-readable label for display purposes.
  String get displayLabel {
    switch (this) {
      case UserRole.fieldAdmin:
        return 'Field Admin';
      case UserRole.operator:
        return 'Operator';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  /// Whether this role meets or exceeds the [required] role level.
  ///
  /// Ordering: fieldAdmin ≥ operator ≥ viewer.
  bool satisfies(UserRole required) {
    return _level >= required._level;
  }

  int get _level {
    switch (this) {
      case UserRole.fieldAdmin:
        return 2;
      case UserRole.operator:
        return 1;
      case UserRole.viewer:
        return 0;
    }
  }
}
