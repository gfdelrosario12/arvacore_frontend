/// Canonical authorization roles for field-scoped access in AquaSense / ArvaCore.
///
/// Roles are mutually exclusive per field membership and MUST NOT be silently
/// elevated client-side. The backend is always authoritative.
enum UserRole {
  /// Full administrative control: field topology, user management, audit logs,
  /// and all operator-level operations.
  fieldAdmin,

  /// Supervisory oversight: system monitoring, master state, telemetry stream,
  /// and read-only diagnostics without pump manipulation.
  supervisor,

  /// Operations on sensor nodes, irrigation commands, automation config,
  /// and fault lockout clearance.
  operator,

  /// Farmer / end-user role with access to own field telemetry and zones.
  user,

  /// Read-only access to monitoring data, telemetry, alerts, and analytics.
  viewer;

  /// Alias for administrative access.
  static const UserRole admin = UserRole.fieldAdmin;

  /// Parses a role string from a JWT claim or API response.
  ///
  /// Returns `null` for any unrecognized value so the caller can treat the
  /// session as unauthorized rather than silently granting the wrong role.
  static UserRole? fromString(String? value) {
    if (value == null) return null;
    switch (value.trim().toLowerCase()) {
      case 'role_admin':
      case 'admin':
      case 'field_admin':
      case 'fieldadmin':
        return UserRole.fieldAdmin;
      case 'role_supervisor':
      case 'supervisor':
        return UserRole.supervisor;
      case 'role_operator':
      case 'operator':
        return UserRole.operator;
      case 'role_user':
      case 'user':
      case 'farmer':
        return UserRole.user;
      case 'role_viewer':
      case 'viewer':
        return UserRole.viewer;
      default:
        return null;
    }
  }

  /// Returns the canonical string representation used in JWT claims.
  String get claimValue {
    switch (this) {
      case UserRole.fieldAdmin:
        return 'field_admin';
      case UserRole.supervisor:
        return 'supervisor';
      case UserRole.operator:
        return 'operator';
      case UserRole.user:
        return 'user';
      case UserRole.viewer:
        return 'viewer';
    }
  }

  /// Human-readable label for display purposes.
  String get displayLabel {
    switch (this) {
      case UserRole.fieldAdmin:
        return 'Admin';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.operator:
        return 'Operator';
      case UserRole.user:
        return 'Farmer';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  /// Whether this role meets or exceeds the [required] role level.
  ///
  /// Enforces least-privilege role boundaries:
  /// - fieldAdmin satisfies all required roles.
  /// - supervisor satisfies supervisor, user, and viewer (cannot operate pumps or admin).
  /// - operator satisfies operator, user, and viewer (cannot admin or access supervisor-only tasks).
  /// - user satisfies user and viewer.
  /// - viewer satisfies viewer only.
  bool satisfies(UserRole required) {
    if (this == required) return true;
    if (this == UserRole.fieldAdmin) return true;
    if (required == UserRole.viewer) return true;
    if (this == UserRole.supervisor && required == UserRole.user) return true;
    if (this == UserRole.operator && required == UserRole.user) return true;
    return false;
  }

  bool get canControlIrrigation => this == UserRole.fieldAdmin || this == UserRole.operator;
  bool get canManageUsers => this == UserRole.fieldAdmin;
  bool get canViewAuditLogs => this == UserRole.fieldAdmin;
  bool get canAccessTelemetryStream =>
      this == UserRole.fieldAdmin || this == UserRole.operator || this == UserRole.supervisor;
  bool get canAccessMasterState =>
      this == UserRole.fieldAdmin || this == UserRole.operator || this == UserRole.supervisor;
}
