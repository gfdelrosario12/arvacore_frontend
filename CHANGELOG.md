# ArvaCore Changelog & System Archive

All notable changes to the ArvaCore Frontend (`arvacore_arvanet_frontend`) and its integrated IoT & API subsystems are documented in this file.

---

## [1.3.8] - 2026-10-22

### User Interface & System Notifications
- **5-Second Floating Notification Banners**:
  - Implemented `GlobalAlertOverlay` in `app_shell.dart` wrapping the entire screen hierarchy.
  - Automatically displays incoming backend notifications as floating animated banners at the top of the viewport for exactly 5 seconds.
  - Features smooth slide-in and fade-out animations with `CurvedAnimation` and `Curves.easeOutCubic`.
  - Supports severity categorization with distinct styling: `CRITICAL` (crimson red), `WARNING` (amber), `INFO` (blue), and `SUCCESS` (green).
  - Built-in deduplication queue prevents overlapping banners and ignores pre-existing historical alerts on application boot.
  - Tapping a notification navigates directly to `AlertDetailScreen` while manual dismiss is available via close action.
  - Fully responsive on mobile (respecting `MediaQuery.padding.top` / `SafeArea`) and web.

## [1.3.7] - 2026-10-20

### Web Deployment & Platform Compatibility
- **Vercel Production Deployment**:
  - Deployed ArvaLink Flutter Web application to production on Vercel at `https://arvalink.gladwindr.me` (Project: `arvalink`, Project ID: `prj_f6RXtC8xJXxtEvCls9Q1uKdaVeYf`).
  - Added `vercel.json` and `.vercelignore` configuring SPA routing rewrites to root `/` while strictly preserving 404 behavior on non-existent static assets and setting long-term caching on assets and canvaskit.
  - Added `scripts/vercel-build.sh` and `package.json` for reproducible builds using pinned Flutter SDK 3.44.8 (stable).
  - Connected Vercel Git integration with repository `https://github.com/gfdelrosario12/arvacore_frontend`.
  - Configured custom domain `arvalink.gladwindr.me` with CNAME `f3587b00ce0bb08e.vercel-dns-017.com.`, automated TLS 1.3 certificate provisioning (Let's Encrypt), and HTTP-to-HTTPS 308 redirection.
  - Verified cross-origin preflight requests from `https://arvalink.gladwindr.me` to `https://api-aquaflow.gladwindr.me` return HTTP 200 with credentials support.
  - Fixed web platform incompatibility in `diagnostics_provider.dart` by adding `kIsWeb` check before accessing `Platform.environment`.
  - Updated web metadata, app title, and web manifest to `ArvaLink — Irrigation Monitoring & Management`.

### Security & Compliance
- **Cryptographic Release Signing**:
  - Eliminated Google Play Protect and antivirus false positives by replacing the default Android debug keystore with a dedicated 4096-bit RSA production keystore (`CN=ArvaLink Mobile, OU=Mobile Security, O=ArvaCore Project`).
  - Implemented dual-scheme signing with APK Signature Scheme v2 and v3.
- **Android Network Security & Sandboxing**:
  - Removed `android:usesCleartextTraffic="true"` and introduced `res/xml/network_security_config.xml` to enforce system CA trust and disallow cleartext communication across production networks.
  - Set `android:allowBackup="false"` in `AndroidManifest.xml` to prevent extraction of application credentials and cached tokens via Android debug bridge (adb).
  - Configured R8 code minification (`isMinifyEnabled = true`) and resource shrinking (`isShrinkResources = true`) with custom `proguard-rules.pro` keeping Flutter, JNI, and Secure Storage bindings.
- **iOS Platform Trust & Privacy Manifest**:
  - Added Apple Privacy Manifest (`PrivacyInfo.xcprivacy`) declaring `NSPrivacyAccessedAPITypeUserDefaults` under reason code `CA92.1` with zero tracking domains.
  - Aligned iOS bundle display name to `ArvaLink` in `ios/Runner/Info.plist`.

### Fixed
- **Mobile-First Layout & Horizontal Centering**:
  - Enforced horizontal center alignment for login branding header and operator card across mobile viewports.
  - Adapted zone telemetry coordinates and transmission frequency rows with responsive `Wrap` layouts.
- **E-Research Metrics Tab Responsive Layouts**:
  - Resolved `RenderFlex` overflows in **Missing Hardware** and **Calibration Requirements** sections on narrow viewports down to 320px (`Compact phone`).
  - Added adaptive `LayoutBuilder` in `IndicatorCard` to cleanly stack status badges and titles on small viewports while preserving horizontal layout on standard screens.
  - Added responsive `Flexible` and maximum constraint bounds in `_buildMetricItem` to prevent long numeric values and labels from overflowing.
  - Surfaced calibration notes and requirements with icon-accented callout containers.

### Changed
- **Production Android Release Packaging**:
  - Rebuilt production Android release APK (`arvacore-v1.3.7-release.apk`, 56.8 MB) with SHA-256 integrity verification (`3ffafafeb8e3b65e1ab4caf908892ff20c8ce481466fd11851ad3dc6d7c8574f`).
  - Archived release package, checksum manifest, and verification metadata in `release_archives/v1.3.7/`.
  - Verified 100% test pass rate across 404 tests (`flutter test`).

---

## [1.3.6] - 2026-10-20

### Fixed
- **Durable Cross-Origin & Preflight Connectivity**:
  - Resolved Spring Security preflight `OPTIONS` rejections by adopting `setAllowedOriginPatterns` with credential support and explicit OPTIONS permission.
  - Added bypass for HTTP `OPTIONS` requests in `RateLimitingFilter`, `WebhookAuthenticationFilter`, and `GatewayAuthenticationFilter`.
  - Configured Nginx dual-stack reverse proxy listeners (`listen [::]:443 ssl;` and `listen [::]:80;`) on the HostHatch VPS to prevent IPv6/NAT64 mobile network requests from colliding with default VirtualHost SSL certificates.
- **Login Disposal Safety & Layout Overflow**:
  - Added `mounted` guards in `login_screen.dart` to prevent disposal exceptions on unmounted text editing controllers.
  - Hardened `dynamic_zone_grid_visualizer.dart` layout constraints and aspect ratio logic across 360px–400px viewports.

### Changed
- **Production Android Release Packaging**:
  - Rebuilt production Android release APK (`arvacore-v1.3.6-release.apk`, 56.5 MB) with SHA-256 integrity verification.
  - Archived release package and checksum manifest in `release_archives/v1.3.6/`.

---

## [1.3.2] - 2026-10-18

### Fixed
- **Application-Wide UI State Synchronization & Cache Invalidation**:
  - **Immediate Local Mutation (Optimistic UI)**: Resolved systemic issue where removed monitoring zones and fields remained visible on screen. When a position is deleted or archived, it is immediately pruned from active collections (`_zones`, `_editableZones`, `_selectedZoneCode`, `_selectedZoneId`) in `setState`, guaranteeing the visual component vanishes instantly without waiting for network re-fetch.
  - **Eliminated Hardcoded Fallback Farmland**: Removed fallback object `'ArvaCore Demonstration Farmland'` in `FieldScreen` when backend returns empty or deleted field records. Replaced with dynamic `listFields()` lookup and a dedicated `No Active Farmland Configured` empty state with an "Add Farmland" action.
  - **Active Record Filtering**: Enhanced `ApiZoneRepository` and `ZoneRepositoryImpl` to explicitly exclude soft-deleted and archived records (`!isArchived && operationalStatus != 'ARCHIVED'`) from all field and zone queries.
  - **Farmland Deletion Support**: Implemented `deleteField(String id)` (`DELETE /api/v1/fields/{id}`) in `FieldApiService` and provided full "Delete Farmland" confirmation workflow in `FarmlandDesignerView` and `FieldScreen`, automatically releasing assigned nodes to the pool.
  - **Designer Resynchronization**: Updated `FarmlandDesignerView.didUpdateWidget` to detect changes in zone count and force re-initialization even when unsaved canvas layout flags are set, eliminating ghost canvas zones.

### Changed
- **Production Android Release Packaging**:
  - Rebuilt production Android release APK (`arvacore-v1.3.2-release.apk`, 56.34 MB) with SHA-256 verification.
  - Archived release package and checksum manifest in `release_archives/v1.3.2/`.

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

