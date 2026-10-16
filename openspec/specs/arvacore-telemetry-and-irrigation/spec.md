# arvacore-telemetry-and-irrigation Specification

## Purpose
Defines ArvaLink frontend integration with ArvaCore physical telemetry, node commissioning workflows, closed-loop irrigation verification views, locked 3-second telemetry interval policy enforcement, farm field selection, and 30-minute pairing request expiration indicators.

## Requirements
### Requirement: System SHALL ingest truthful field telemetry without fabricated defaults
The system SHALL ingest physical node telemetry from ArvaNodes through gateway endpoints (`POST /api/v1/telemetry/uplink/{nodeId}`), validate physical sensor bounds (ultrasonic distance 20–450 cm, soil moisture 0–100%, battery voltage 2.5–5.0V), reject implausible measurements, and never inject synthetic default sensor readings.

#### Scenario: Ingest valid physical sensor telemetry
- **WHEN** an ArvaNode transmits valid distance, water level, and soil moisture measurements with valid gateway credentials
- **THEN** the system decodes the payload, validates physical sensor plausibility, persists `TelemetryReading` entities, and returns HTTP 200

#### Scenario: Reject out-of-bounds telemetry measurements
- **WHEN** an uplink contains soil moisture < 0% or > 100%, or ultrasonic distance < 20 cm or > 450 cm
- **THEN** the system rejects the implausible measurement channel without fabricating fallback readings

### Requirement: ArvaLink SHALL lock node transmission interval to 3-second policy
The application SHALL enforce that the base transmission interval is locked to 3 seconds (`TELEMETRY_INTERVAL_MS = 3000`) across all node registration and configuration interfaces. The transmission interval control SHALL be displayed as a fixed, read-only policy value with an informative badge, preventing operators from configuring arbitrary or slow intervals that degrade real-time AWD closed-loop control.

#### Scenario: Registering node displays fixed 3-second policy
- **WHEN** an operator opens the Node Registration Dialog to pair or register a discovered node
- **THEN** the Transmission Interval field is locked to 3 seconds with a badge explaining that high-frequency telemetry is enforced by system policy

### Requirement: ArvaLink SHALL manage farm field selection and monitoring zone assignment
The application SHALL provide field-aware node registration and commissioning controls. Operators SHALL be able to select the target Farm Field from an active field dropdown, which dynamically filters the selectable monitoring zones belonging to that field.

#### Scenario: Selecting farm field during node registration
- **WHEN** an operator opens the node registration dialog for a discovered or pairing node
- **THEN** the dialog displays a Farm Field selector loaded from the fields catalog, dynamically populating the available monitoring zones for the selected field

### Requirement: ArvaLink SHALL detect and visually indicate 30-minute expired node pairing requests
The application SHALL evaluate the expiration timestamp (`expiresAt` or 30 minutes from `requestedAt`) of discovered node pairing requests. If a request is older than 30 minutes, the application SHALL display a clear `EXPIRED` badge and disable the pairing approval button to prevent failed API submissions.

#### Scenario: Displaying expired pairing request in modal
- **WHEN** an operator views the Discovered Nodes / Pairing Requests modal and a request's `expiresAt` is in the past
- **THEN** the node card renders an `EXPIRED` status chip, hides or disables the "Pair Node" action button, and prompts the operator to re-trigger hardware pairing on the physical node

### Requirement: System SHALL authenticate gateway telemetry via constant-time key validation
The system SHALL enforce gateway token authentication using the `X-ArvaCore-Gateway-Key` header on all telemetry endpoints (`/api/v1/telemetry/**`).

#### Scenario: Accept uplink with valid gateway key
- **WHEN** a client POSTs telemetry with header `X-ArvaCore-Gateway-Key: arvacore-gateway-sec-key-2026`
- **THEN** the system validates the key in constant time and allows telemetry ingestion

#### Scenario: Reject uplink with missing or invalid gateway key
- **WHEN** a client POSTs telemetry with an incorrect or missing `X-ArvaCore-Gateway-Key` header
- **THEN** the system rejects the request with HTTP 401 Unauthorized

### Requirement: System SHALL enforce closed-loop flow delivery verification for central irrigation
The system SHALL orchestrate irrigation commands exclusively for the centralized pump and solenoid valve, verifying water delivery through the inline flow sensor.

#### Scenario: Distinguish pump activation from physical water delivery
- **WHEN** central pump is commanded ON and inline flow sensor confirms water flow $\ge 5.0\,\text{L/min}$
- **THEN** the system marks the command outcome as physically verified

#### Scenario: Detect dry-run or pump blockage
- **WHEN** central pump is commanded ON but inline flow sensor indicates $0.0\,\text{L/min}$ after the verification window
- **THEN** the system flags an operational fault and raises a dry-run anomaly alert


