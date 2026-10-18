# ArvaCore Changelog & System Archive

All notable changes to the ArvaCore Frontend (`arvacore_arvanet_frontend`) and its integrated IoT & API subsystems are documented in this file.

---

## [1.3.1] - 2026-10-18

### Fixed
- **Monitoring Position (Zone) Removal Error Resolution**:
  - Sanitized zone identifier parsing by extracting numeric values (`int64`), preventing Spring Boot controller type-mismatch errors (`MethodArgumentTypeMismatchException` / HTTP 400 Bad Request).
  - Aligned endpoint routing with backend architecture: targets field-scoped deletion endpoint `DELETE /api/v1/fields/{fieldId}/zones/{zoneId}` with automatic fallback to `/api/v1/zones/{zoneId}`.
  - Implemented safe hardware node preservation: automatically unassigns physically bound `Esp32Node`s back to the unassigned pool (`monitoringZoneId: null`) prior to zone deletion. Eliminates foreign-key constraint conflicts while preserving device telemetry, pairing status, and hardware records.
  - Replaced raw `ApiException` string rendering with human-readable error feedback mapping HTTP 403 (Administrator permissions required), 404 (already removed), 409 (conflict), and connection errors.

### Changed
- **Release Deliverables & Packaging**:
  - Rebuilt production Android release APK (`arvacore-v1.3.1-release.apk`, 56.3 MB) using Gradle 9.1 and Android SDK target 35.
  - Archived release deliverables with SHA-256 integrity checksum manifest.

---

## [1.3.0] - 2026-10-17

### Added
- **Dedicated Real-Time ESP32 Telemetry Notification Stream**:
  - Implemented persistent Telemetry Stream navigation item and dashboard screen (`TelemetryStreamScreen`) in `AppShell`.
  - Chronological, uncollapsed audit trail of every received ArvaNode ESP32 uplink with sequence numbers, RSSI, battery voltage/percentage, soil moisture, and ultrasonic water level.
  - Multi-transport real-time updates via WebSocket (`wss://api-aquaflow.gladwindr.me/api/v1/telemetry/stream`) and fallback REST pagination.
  - Quick-glance active uplink indicator on the Home dashboard (`ConnectedNodesCard`) with direct navigation to the telemetry stream.
- **Production Asset Suite**:
  - Official high-resolution circular/square ArvaCore icons for web favicon (`favicon.ico`, `favicon.png`, `apple-touch-icon.png`) and PWA web manifest.
  - Full set of Android launcher icons across `mipmap-mdpi`, `mipmap-hdpi`, `mipmap-xhdpi`, `mipmap-xxhdpi`, and `mipmap-xxxhdpi`.

### Changed
- **Branding & Identity Standardization**:
  - Set browser tab title to `ArvaCore — Irrigation Monitoring & Management`.
  - Updated web manifest metadata (`name: "ArvaCore — Irrigation Monitoring & Management"`, `short_name: "ArvaCore"`).
  - Updated Android application label to `ArvaCore` while maintaining package name `com.example.aquaflow_frontend` and signing configuration.
  - Updated `AppStrings.appTitle` constant.
- **Production Endpoint Enforcement**:
  - Configured canonical base URL `https://api-aquaflow.gladwindr.me`.
  - Configured canonical real-time WebSocket URL `wss://api-aquaflow.gladwindr.me/api/v1/telemetry/stream`.
  - Enforced HTTPS/WSS in production environments with zero mock telemetry.

---

## [1.2.0] - 2026-10-17

### Added
- **Configurable Dynamic Field Positions ($N \ge 0$ Monitoring Zones)**:
  - Dynamically configurable monitoring positions (Q1, Q2, ..., QN) replacing legacy fixed quadrant constraints.
  - Interactive grid and positioning visualizer (`DynamicZoneGridVisualizer`) dynamically rendered from live backend data.
  - Position creation and deletion workflows (`FieldScreen._showCreateZoneDialog`, `deleteZone`) with immediate real-time UI refresh.
- **Node Assignment, Deassignment & Reassignment Workflows**:
  - Full assignment lifecycle modal (`NodeAssignmentDialog`) supporting assigning unassigned physical ESP32 ArvaNodes to zones, reassigning existing nodes across zones with conflict confirmation, and explicit deassignment back to the unassigned hardware pool (`monitoringZoneId: null`).
  - Added dedicated **Deassign** and **Change Assignment** action buttons directly on `ZoneDetailBottomSheet`.
  - Immediate removal of telemetry from former zones upon deassignment to prevent ghost data leakage.
- **Dedicated Research Metrics Tab (Persistent Navigation)**:
  - Permanent 4th navigation item (`Research Metrics`, `Icons.science_outlined`) hosted directly in `AppShell`.
  - Quantitative Research Dashboard (`SystemEvaluationDashboardScreen`) computing and visualizing 6 core system performance indicators:
    1. **Water-Level Monitoring Accuracy**: $\max(0, 1 - \text{MAE}/91.44) \times 100$, initialized to 0% ("Not yet evaluated").
    2. **Soil-Moisture Monitoring Accuracy**: $\max(0, 1 - \text{MAE}/100) \times 100$, initialized to 0% ("Not yet evaluated").
    3. **Irrigation Activation Accuracy**: Initialized to 0% ("Awaiting test data").
    4. **Irrigation Deactivation Accuracy**: Initialized to 0% ("Awaiting test data").
    5. **Irrigation Response Time**: Initialized to 0 ms ("Awaiting events").
    6. **Water Consumption Monitoring**: Initialized to 0 L (0.0 L/min flow rate, "Awaiting measurement data" with explicit missing hardware disclaimer).
  - Ground-truth reference input dialog enabling on-site physical calibration and MAE recalculation.
  - Non-blocking layout: Metric cards remain visible with inline alerts even during server downtime or API disconnects.
- **Ultrasonic Water-Level Calculation & Interactive Visualizer**:
  - Floating ball ultrasonic formula: $\text{Water Level} = \text{Calibrated Sensor-to-Bottom} - \text{Measured Sensor-to-Ball Distance}$, clamped to $[0, 91.44\text{ cm}]$ (36 inches).
  - Cross-section diagram (`UltrasonicWaterLevelDiagram`) showing the vertical tube, floating ball, reference datum, echo cone, and metric/imperial toggles.
- **Connected ArvaNodes Overview Card**:
  - Dashboard widget (`ConnectedNodesCard`) displaying active physical ESP32 devices, Wi-Fi RSSI, battery voltage, and firmware status.

### Changed
- **Operational Dashboard Telemetry Retention & Freshness Guidance**:
  - Distinguishes valid zero readings ($0\%$, $0\text{ cm}$) from missing/disconnected telemetry.
  - Retains latest valid telemetry when live connection drops, actively flagging readings older than 15 minutes as **Outdated** with contextual troubleshooting instructions (ESP32 power, LoRaWAN/Wi-Fi gateway, firmware uplink).
- **System Branding & Terminology Standardization**:
  - Systematically renamed legacy AWD and "AquaFlow/AquaSense" terms to official ArvaCore nomenclature:
    - *ArvaCore*: Automated Irrigation & Pump Controller.
    - *ArvaNode*: Solar/battery-powered LoRaWAN/Wi-Fi telemetry sensor node.
    - *ArvaNet*: Centralized telemetry dashboard and management interface.
- **Release Signing Configuration**:
  - Updated `android/app/build.gradle.kts` to support safe `key.properties` keystore loading for production release APKs with debug fallback.
  - Added `key.properties` and `*.keystore` / `*.jks` to `.gitignore`.

### Fixed
- **API Page Compatibility**:
  - Fixed `ResourceListDto` and audit log parsers to handle Spring Boot Page JSON representations containing nested `content` or `data` arrays.
- **Telemetry Data Flow & Pairing Integration**:
  - Fixed pairing approval handler in `FieldScreen` to cleanly link pending node hardware to dynamic monitoring positions.

---

## Archival Verification & Environment Details
- **Archival Date**: 2026-10-17
- **Target Remote**: `git@github.com:gfdelrosario12/arvacore_frontend.git` (branch: `main`)
- **API Base URL**: `https://api-aquaflow.gladwindr.me/api/v1`
- **Validation Execution**:
  - `flutter analyze lib/ --no-fatal-infos`: Passed with 0 errors (35 deprecation/style warnings).
  - `flutter test test/unit/ultrasonic_water_level_test.dart test/unit/domain_and_mappers_test.dart`: 36/36 tests passed.

