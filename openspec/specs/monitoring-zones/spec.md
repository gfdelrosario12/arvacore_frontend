# monitoring-zones Specification

## Purpose
Defines domain structures, telemetry data models, and monitoring views for independent field monitoring quadrants Q1, Q2, Q3, and Q4.
## Requirements
### Requirement: Quadrant monitoring zones definition
The application MUST model monitoring zones as dynamically configurable observational zones within a field supporting arbitrary zone counts (such as 1, 2, 4, 6, 8, or more), providing soil moisture, water level, and environmental telemetry while strictly avoiding hardcoded quadrant limitations, and automatically expanding zone counts when new nodes and zones are provisioned.

#### Scenario: Displaying telemetry for monitoring zones
- **WHEN** the user views zone telemetry in the Field or Home screens
- **THEN** readings for all dynamically configured monitoring zones in the field are displayed independently with moisture and water level metrics, regardless of whether 1, 2, 4, 6, 8, or more zones are provisioned.

#### Scenario: Expanding monitoring zone count upon node registration
- **WHEN** a new sensor node is scanned and registered with a new zone assignment
- **THEN** the system dynamically instantiates the new monitoring zone, increments active zone count, and reflects the updated zone matrix in the Field and Home dashboards.

### Requirement: Strict prohibition of zone-level irrigation controls
The application MUST NOT present or permit zone-specific irrigation triggers or zone-level pump/valve control actions within monitoring zone models or views.

#### Scenario: Inspecting monitoring zone actions
- **WHEN** the user selects any monitoring zone (Q1, Q2, Q3, or Q4) in the UI
- **THEN** only read-only monitoring metrics and sensor diagnostic information are shown, with no zone-level activation controls present.

### Requirement: Detailed sensor telemetry and signal metrics
The system SHALL present detailed telemetry metrics for each monitoring zone including water level (cm), soil moisture (%), zone status/condition, sensor online/offline state, battery percentage, signal diagnostic metrics (RSSI in dBm and SNR in dB), and last measurement timestamp across any configured number of zones.

#### Scenario: Displaying telemetry and diagnostic signal metrics for a monitoring zone
- **WHEN** the user views a monitoring zone card or detailed inspector on the Field screen
- **THEN** water level, soil moisture, connection state (online/offline), battery percentage, RSSI, SNR, and last measurement timestamp are clearly displayed.

### Requirement: Truthful hardware telemetry representation
The application SHALL only display telemetry metrics confirmed and supported by installed field hardware (capacitive soil moisture, ultrasonic pond depth, battery percentage, and wireless signal strength). The application SHALL NOT display or simulate ambient temperature or humidity as active field readings.

#### Scenario: Inspecting telemetry on zone screens
- **WHEN** an operator views the zone detail bottom sheet or zone analysis screen
- **THEN** the interface renders soil moisture, water depth, battery level, and wireless signal metrics, cleanly excluding unequipped temperature and humidity sensors.

### Requirement: Field-level comparative zone visualization
The system SHALL provide an adaptive comparative layout displaying all dynamically provisioned monitoring zones simultaneously, enabling immediate field-level contrast of water levels and moisture conditions across arbitrary zone counts.

#### Scenario: Comparing field conditions across quadrants Q1 through Q4
- **WHEN** the user opens the Field Monitoring screen
- **THEN** all active monitoring zones returned by the backend are rendered in an adaptive comparative matrix or list displaying status badges, moisture levels, and water depths for side-by-side assessment across dynamic zones.

### Requirement: Zone selection read-only inspection
The system SHALL allow the user to select any monitoring zone to inspect detailed sensor telemetry in a dedicated sheet or view, while strictly excluding zone-level pump or valve activation controls.

#### Scenario: Selecting a monitoring zone for detailed telemetry inspection
- **WHEN** the user taps a monitoring zone card (Q1, Q2, Q3, or Q4)
- **THEN** a detailed telemetry inspection view opens displaying comprehensive sensor health, signal metrics, and historical depth readings without presenting any zone-level irrigation buttons or hardware triggers.

### Requirement: Field monitoring screen state handling
The system SHALL support loading, empty (no deployed nodes), stale (outdated measurements), unavailable (gateway connection lost), and error presentation states using reusable design-system widgets.

#### Scenario: Handling sensor telemetry connection error or gateway unavailability
- **WHEN** loading monitoring zone telemetry fails or gateway connection is lost
- **THEN** a standardized error state component or unavailable banner is rendered with retry instructions.

### Requirement: Dedicated quarter monitoring zone analysis view
The system SHALL provide a dedicated analysis screen/view for any selected monitoring zone in the field, displaying real-time water level depth, soil moisture percentage, sensor online/offline status, battery level, RSSI, SNR, and the last update timestamp, while routing dashboard zone interactions directly to the Field tab.

#### Scenario: Navigating to individual quarter zone analysis
- **WHEN** the user selects any monitoring zone from the Field Monitoring screen
- **THEN** the application opens the Zone Analysis screen displaying detailed telemetry, hardware diagnostics, and historical performance for that specific zone.

#### Scenario: Interacting with dashboard zone cards
- **WHEN** the user selects any monitoring zone card from the Home Dashboard screen
- **THEN** the application routes directly to the main Field tab to present overall field context across dynamic zones.

### Requirement: Telemetry trend direction and rate analysis
The system SHALL compute and display a trend direction indicator for the selected monitoring zone, explicitly stating whether the quadrant is becoming "wetter" (increasing water level) or "drier" (decreasing water level) alongside the estimated rate of change over time.

#### Scenario: Displaying trend direction and rate indicator
- **WHEN** the user inspects the trend card on the zone analysis screen
- **THEN** the system displays a clear visual badge and text indicator showing whether the zone is becoming "Wetter" or "Drier" (e.g., "Wetter (+1.8 cm/h)" or "Drier (-1.2 cm/h)") calculated from historical measurements.

### Requirement: Multi-timeframe historical trend visualization
The system SHALL render interactive or multi-range historical trend charts (e.g., 24-hour and 7-day timeframes) allowing users to visually inspect and compare historical water depth and moisture behavior for the selected quadrant.

#### Scenario: Switching timeframes on the historical trend chart
- **WHEN** the user selects a different historical timeframe filter (e.g., 24h or 7d) on the zone analysis chart
- **THEN** the historical telemetry chart updates to display data points corresponding to the selected time window.

### Requirement: Read-only AWD and centralized irrigation redirection
The system MUST NOT provide zone-level Start Irrigation, Stop Irrigation, pump controls, or valve triggers on the zone analysis screen. If the user requires irrigation action based on quadrant trends, the screen MUST display an explicit read-only notice directing the user toward field-level AWD analysis and centralized irrigation.

#### Scenario: Verifying read-only guardrails and centralized irrigation redirection
- **WHEN** the user views the zone analysis screen for any quadrant
- **THEN** no pump or valve control triggers are present, and a prominent redirection banner is displayed guiding the user to the centralized irrigation and field AWD controller for any watering actions.

### Requirement: Multi-node dynamic zone aggregation
The system SHALL support aggregating telemetry from one or more dynamically assigned ESP32 sensor nodes within a monitoring zone, computing composite zone water level and soil moisture metrics while displaying individual node breakdowns.

#### Scenario: Displaying zone with multiple assigned nodes
- **WHEN** a monitoring zone contains multiple assigned ESP32 sensor nodes
- **THEN** the zone displays composite moisture and water level readings along with the count and health status of all member nodes.

### Requirement: Spatial view toggle on field monitoring screen
The system SHALL provide a view mode toggle on the Field Monitoring screen allowing users to switch seamlessly between the matrix/grid view and the spatial 2D field visualization.

#### Scenario: Toggling from matrix view to spatial field view
- **WHEN** the user taps the spatial view toggle button on the Field Monitoring screen
- **THEN** the layout transitions from the quadrant matrix cards to the interactive 2D spatial field visualizer.

### Requirement: Dynamic responsive monitoring zone layout
The system SHALL dynamically render monitoring zones using an adaptive responsive layout that automatically adjusts column counts, card dimensions, and aspect ratios based on viewport width (single-column on narrow mobile, two-column on standard mobile, multi-column on tablet and desktop web) and the total number of configured zones, supporting arbitrary practical zone deployments (such as 1, 2, 4, 6, 8, or more zones).

#### Scenario: Rendering field monitoring on standard mobile screen
- **WHEN** the user opens the Field Monitoring screen on a mobile device with 360–600px width
- **THEN** the monitoring zones are rendered in an adaptive 2-column or 1-column scrollable grid with proportional card dimensions without RenderFlex overflow.

#### Scenario: Rendering field monitoring on tablet or desktop web
- **WHEN** the user opens the Field Monitoring screen on a device with width exceeding 720px
- **THEN** the monitoring zones expand into a multi-column responsive grid (3 or 4 columns) optimizing whitespace and card readability.

#### Scenario: Rendering odd or arbitrary numbers of zones
- **WHEN** a field is configured with 1, 3, 5, or 7 monitoring zones
- **THEN** the layout renders all configured zones cleanly without placeholder gaps, layout clipping, or assumed fixed pairs.

### Requirement: Configuration-driven zone labels and headers
The system SHALL derive all monitoring zone headers, section titles, card labels, and navigation titles dynamically from field configuration returned by the backend, strictly avoiding hardcoded quadrant nomenclature.

#### Scenario: Displaying dynamic field monitoring title and counts
- **WHEN** the field monitoring screen renders active monitoring zones
- **THEN** the section header displays dynamic counts and configured zone names (e.g., "Field Monitoring Zones (6 Active)") without referencing fixed Q1–Q4 quadrants.

### Requirement: Telemetry freshness and data quality tracking
The system SHALL evaluate each monitoring zone's telemetry for freshness (time elapsed since last measurement), data reliability status (valid, stale, outlier, or uncalibrated), and effective spatial weight in field-wide AWD analysis.

#### Scenario: Visualizing zone data quality in zone details
- **WHEN** a monitoring zone's sensor node has not reported within the freshness timeout or is identified as an outlier
- **THEN** the zone details view displays an amber or warning badge indicating degraded telemetry quality and whether the zone is excluded from the active field average.

