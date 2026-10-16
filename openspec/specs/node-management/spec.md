# node-management Specification

## Purpose

Enables operator discovery, registration, field and zone assignment, transmission interval configuration, and adaptive rate tracking for dynamic ESP32 IoT sensor nodes.
## Requirements
### Requirement: Dynamic ESP32 node discovery and registration
The system SHALL support discovering uncommissioned ESP32 sensor nodes detected on the network and allow authorized operators to register them with a human-readable name, hardware identifier (MAC address or 64-bit LoRaWAN DevEUI), and target field/zone, dynamically expanding the active monitoring zones upon registration.

#### Scenario: Discovering and registering a new ESP32 node
- **WHEN** an authorized operator opens the node registration interface and selects an unassigned discovered ESP32 node
- **THEN** the system registers the node, assigns its display identifier, binds it to the target zone, and confirms successful commissioning without requiring app reloads.

#### Scenario: Registering a node to a new monitoring zone
- **WHEN** an operator registers a new node and assigns it to a newly created monitoring zone (such as "Zone 5 - East")
- **THEN** the system dynamically adds the new monitoring zone to the field monitoring state and updates overall field metrics without hardcoding quadrant limits.

### Requirement: Node field and irrigation zone assignment
The system SHALL permit operators to assign or reassign any registered sensor node (Wi-Fi/Bluetooth ESP32 or LoRaWAN RFM95W) to a specific agricultural field and monitoring/irrigation zone without hardcoding node identifiers or quadrant labels (Q1/Q2/Q3/Q4).

#### Scenario: Assigning a node to an irrigation zone
- **WHEN** the operator assigns a registered node to "Zone 1 (North Quadrant)" within "Field A"
- **THEN** the node telemetry is associated with that zone and appears in zone-level aggregated telemetry views.

#### Scenario: Dynamic zone mapping without hardcoded quadrant identifiers
- **WHEN** an operator assigns a newly provisioned LoRaWAN node with `devEui: 0004A30B001F9876` to a newly created monitoring zone "Zone 5 - East Field"
- **THEN** the system dynamically associates all incoming uplinks for that `devEui` with "Zone 5 - East Field" without requiring code changes or hardcoded quadrant identifiers.

### Requirement: Node transmission interval policy enforcement
The system SHALL display the active transmission interval (in seconds) for each node and enforce that the base transmission interval is locked to 3 seconds (`TELEMETRY_INTERVAL_MS = 3000`) by system policy during node commissioning. The UI SHALL present the 3-second transmission interval as a fixed policy value accompanied by an informational policy badge, preventing accidental deceleration of telemetry needed for AWD closed-loop decision making.

#### Scenario: Displaying fixed 3-second policy during commissioning
- **WHEN** an operator initiates node registration or views transmission parameters
- **THEN** the transmission interval field is locked to 3 seconds with a badge indicating "Fixed by system policy (3s)"

#### Scenario: Unauthorized viewer accesses transmission details
- **WHEN** an authenticated user with `viewer` role accesses node details
- **THEN** transmission configuration controls are read-only and command triggers are disabled


### Requirement: Real-time reflection of adaptive transmission changes
The system SHALL ingest backend-driven adaptive transmission interval updates over real-time event streams and immediately reflect the active interval and adaptation reason in the user interface.

#### Scenario: Backend automatically accelerates transmission during moisture dry-down
- **WHEN** the backend adjusts a node transmission interval from 300 seconds to 30 seconds due to rapid moisture depletion and publishes the event
- **THEN** the node's displayed interval updates to 30 seconds in real time with an adaptive indicator badge explaining the dry-down trigger.

### Requirement: Node lifecycle state machine and transitions
The system SHALL support and enforce formal lifecycle states for each sensor node: `discovered`, `provisioned`, `active`, `maintenance`, `disabled`, `replaced`, and `decommissioned`. The system MUST validate all state transitions and reject invalid transition attempts.

#### Scenario: Transitioning an active node to maintenance
- **WHEN** an authorized operator flags an active sensor node for maintenance or battery replacement
- **THEN** the system transitions the node lifecycle status to `maintenance`, marks its telemetry as under maintenance, and suspends threshold breach alerts originating from that node.

#### Scenario: Disabling a malfunctioning node
- **WHEN** an operator disables a malfunctioning node
- **THEN** the system transitions the node to `disabled` state, excludes its readings from zone-level aggregation, and displays a disabled badge in the UI.

### Requirement: Secure device identity verification and provisioning
The system SHALL verify physical sensor node identities during commissioning using a stable hardware identifier (MAC address or 64-bit LoRaWAN DevEUI) paired with a cryptographically verified provisioning secret, AppKey, or challenge token. Unverified or duplicate hardware identifiers MUST be rejected.

#### Scenario: Provisioning a verified node
- **WHEN** an operator provisions a discovered node with its valid factory secret or provisioning token
- **THEN** the system validates device identity, assigns cryptographic session credentials, and transitions the node from `discovered` to `provisioned` state.

#### Scenario: Rejecting duplicate or unauthorized device registration
- **WHEN** a registration request arrives with a hardware MAC address or DevEUI already commissioned or an invalid authorization token
- **THEN** the system rejects the registration with a validation error and prevents unauthorized telemetry ingestion.

#### Scenario: Provisioning a LoRaWAN ESP32 sensor node with DevEUI and AppKey
- **WHEN** an authorized operator registers an ESP32 LoRaWAN sensor node by providing its 64-bit `devEui`, `joinEui`, and `appKey`
- **THEN** the backend registers the node credentials with the LoRaWAN Network Server, verifies uniqueness, and binds the node to its assigned monitoring zone.

### Requirement: Atomic physical node replacement with measurement preservation
The system SHALL provide an atomic node replacement workflow allowing an operator to replace an existing physical sensor node assigned to a monitoring zone with a newly provisioned sensor node. The replacement MUST bind the new node to the target monitoring zone and monitoring point while strictly preserving historical moisture and water level records, and logging an immutable replacement audit event.

#### Scenario: Replacing a physical node at a monitoring zone
- **WHEN** an authorized operator executes a replacement command swapping an old node with a new node for "Zone 1"
- **THEN** the system marks the old node as `replaced`, assigns the new node to "Zone 1", immediately associates new telemetry uplinks with "Zone 1", and retains all prior historical depth and moisture records under "Zone 1".

### Requirement: Sensor node decommissioning and unassignment
The system SHALL allow authorized operators to decommission or unassign a sensor node from a monitoring zone. Decommissioning MUST permanently retire the physical node from active operations while preserving its historical event logs and retaining the continuity of the parent monitoring zone.

#### Scenario: Decommissioning a retired sensor node
- **WHEN** an authorized operator decommissions a damaged or obsolete node
- **THEN** the system transitions the node to `decommissioned` state, clears its zone assignment, and preserves its historical transmission records for auditing.

### Requirement: Sensor node renaming and metadata configuration
The system SHALL allow authorized operators to update a node's human-readable display label, notes, and installation coordinates without altering its immutable hardware identity (MAC / DevEUI).

#### Scenario: Renaming a sensor node
- **WHEN** an operator renames node "ESP32-9F42" to "North Boundary Tube 1"
- **THEN** the system updates and persists the display label across all field and diagnostic views.

### Requirement: Dynamic node synchronization without application rebuild
The system SHALL synchronize sensor nodes dynamically from backend REST endpoints and real-time events, allowing newly added, reassigned, or modified nodes to become immediately available and interactive in the Flutter application without requiring an application update or rebuild.

#### Scenario: Ingesting a newly provisioned node at runtime
- **WHEN** a new node is provisioned on the backend while the mobile application is active
- **THEN** the application ingests the node metadata dynamically and displays it in the field and diagnostics interfaces without requiring an app reload.

### Requirement: Role-based authorization for node lifecycle operations
The system MUST enforce role-based access control on all node lifecycle operations. Only authenticated users with `admin` or `operator` roles SHALL be permitted to register, provision, assign, reassign, rename, toggle maintenance, replace, or decommission nodes. Users with `viewer` role MUST NOT have access to lifecycle mutation actions.

#### Scenario: Unauthorized viewer attempts node lifecycle operation
- **WHEN** a user authenticated with `viewer` role attempts to decommission or replace a node
- **THEN** the system hides or disables mutation controls, blocks unauthorized requests at the API boundary, and displays an authorization error if invoked.

### Requirement: Hardware-activated node pairing mode discovery
The system SHALL support detecting physical sensor nodes that have entered discoverable pairing mode via a physical button press on the node hardware, enabling rapid pairing and assignment to dynamic monitoring zones without manual DevEUI or MAC entry.

#### Scenario: Discovering node activated by hardware pairing button
- **WHEN** an operator presses the physical pairing button on a sensor node and initiates discovery in the application
- **THEN** the application detects the node's broadcasted hardware identifier and presents a pairing confirmation dialog with dynamic zone assignment options.

#### Scenario: Enforcing 30-minute pairing request expiration
- **WHEN** a pairing request in the discovery queue exceeds the authoritative 30-minute window
- **THEN** the application flags the request as expired, presents an EXPIRED visual indicator, disables pairing confirmation, and prompts the operator to press the physical pairing button on the node again.


