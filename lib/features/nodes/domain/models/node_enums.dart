/// Formal lifecycle states for physical IoT sensor nodes in AquaSense.
enum NodeLifecycleStatus {
  /// Node has broadcast join/discovery beacons but is not yet commissioned.
  discovered,

  /// Node has been claimed and is undergoing spatial/datum configuration.
  provisioning,

  /// Node has valid credentials and is ready for field deployment.
  provisioned,

  /// Node is fully commissioned, assigned to a point, and streaming valid telemetry.
  active,

  /// Node is undergoing calibration, battery swap, or physical repair.
  maintenance,

  /// Node has missed multiple expected heartbeats and is unreachable.
  offline,

  /// Node has been administratively disabled or suppressed due to malfunction.
  disabled,

  /// Node has been permanently replaced by a newer hardware device at this point.
  replaced,

  /// Node has been retired and permanently removed from field operations.
  decommissioned,

  /// Node has been unpaired or pairing has been revoked.
  unregistered;

  /// Validates whether transitioning from this lifecycle state to [target] is permitted.
  bool canTransitionTo(NodeLifecycleStatus target) {
    if (this == target) return true;
    switch (this) {
      case NodeLifecycleStatus.discovered:
        return target == NodeLifecycleStatus.provisioning ||
            target == NodeLifecycleStatus.provisioned ||
            target == NodeLifecycleStatus.decommissioned;
      case NodeLifecycleStatus.provisioning:
        return target == NodeLifecycleStatus.provisioned ||
            target == NodeLifecycleStatus.active ||
            target == NodeLifecycleStatus.disabled ||
            target == NodeLifecycleStatus.decommissioned;
      case NodeLifecycleStatus.provisioned:
        return target == NodeLifecycleStatus.active ||
            target == NodeLifecycleStatus.maintenance ||
            target == NodeLifecycleStatus.disabled ||
            target == NodeLifecycleStatus.decommissioned;
      case NodeLifecycleStatus.active:
        return target == NodeLifecycleStatus.maintenance ||
            target == NodeLifecycleStatus.offline ||
            target == NodeLifecycleStatus.disabled ||
            target == NodeLifecycleStatus.replaced ||
            target == NodeLifecycleStatus.decommissioned ||
            target == NodeLifecycleStatus.unregistered;
      case NodeLifecycleStatus.maintenance:
        return target == NodeLifecycleStatus.active ||
            target == NodeLifecycleStatus.disabled ||
            target == NodeLifecycleStatus.replaced ||
            target == NodeLifecycleStatus.decommissioned ||
            target == NodeLifecycleStatus.unregistered;
      case NodeLifecycleStatus.offline:
        return target == NodeLifecycleStatus.active ||
            target == NodeLifecycleStatus.maintenance ||
            target == NodeLifecycleStatus.disabled ||
            target == NodeLifecycleStatus.replaced ||
            target == NodeLifecycleStatus.decommissioned ||
            target == NodeLifecycleStatus.unregistered;
      case NodeLifecycleStatus.disabled:
        return target == NodeLifecycleStatus.active ||
            target == NodeLifecycleStatus.maintenance ||
            target == NodeLifecycleStatus.replaced ||
            target == NodeLifecycleStatus.decommissioned ||
            target == NodeLifecycleStatus.unregistered;
      case NodeLifecycleStatus.replaced:
        return target == NodeLifecycleStatus.decommissioned ||
            target == NodeLifecycleStatus.unregistered;
      case NodeLifecycleStatus.decommissioned:
        return false;
      case NodeLifecycleStatus.unregistered:
        return target == NodeLifecycleStatus.discovered ||
            target == NodeLifecycleStatus.provisioning ||
            target == NodeLifecycleStatus.provisioned ||
            target == NodeLifecycleStatus.active;
    }
  }

  /// Human-readable display label for UI representation.
  String get label {
    switch (this) {
      case NodeLifecycleStatus.discovered:
        return 'Discovered';
      case NodeLifecycleStatus.provisioning:
        return 'Provisioning';
      case NodeLifecycleStatus.provisioned:
        return 'Provisioned';
      case NodeLifecycleStatus.active:
        return 'Active';
      case NodeLifecycleStatus.maintenance:
        return 'Maintenance';
      case NodeLifecycleStatus.offline:
        return 'Offline';
      case NodeLifecycleStatus.disabled:
        return 'Disabled';
      case NodeLifecycleStatus.replaced:
        return 'Replaced';
      case NodeLifecycleStatus.decommissioned:
        return 'Decommissioned';
      case NodeLifecycleStatus.unregistered:
        return 'Unregistered';
    }
  }

  /// Asserts that transitioning to [target] is valid, throwing [StateError] otherwise.
  void validateTransition(NodeLifecycleStatus target) {
    if (!canTransitionTo(target)) {
      throw StateError(
        'Illegal node lifecycle transition from ${name.toUpperCase()} to ${target.name.toUpperCase()}',
      );
    }
  }

  /// Whether the node is in an operational state transmitting production telemetry.
  bool get isOperable => this == NodeLifecycleStatus.active;

  /// Whether the node is in an immutable terminal state.
  bool get isTerminal =>
      this == NodeLifecycleStatus.decommissioned ||
      this == NodeLifecycleStatus.unregistered;

  /// Whether the node is retired from active duty.
  bool get isRetired =>
      this == NodeLifecycleStatus.replaced ||
      this == NodeLifecycleStatus.decommissioned ||
      this == NodeLifecycleStatus.unregistered;
}

/// Backwards compatibility alias for `NodeLifecycleStatus`.
typedef NodeLifecycleState = NodeLifecycleStatus;

/// Transducer / sensing channel types supported by AquaSense sensor nodes.
enum SensorType {
  /// Ultrasonic or hydrostatic water depth inside field observation pipe (cm).
  waterLevelTube,

  /// Frequency domain / capacitive volumetric soil water content (%).
  soilMoistureCapacitive,

  /// Soil temperature sensor (°C).
  soilTemperature,

  /// Ambient air temperature and humidity sensor.
  ambientHumidity,

  /// Internal battery supply voltage monitor (V / mV).
  batteryVoltage,

  /// Soil/water electrical conductivity (salinity probe).
  waterSalinityEc,

  /// Soil reduction-oxidation potential probe (redox mV).
  soilRedox,
}

