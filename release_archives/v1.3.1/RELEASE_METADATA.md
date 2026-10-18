# ArvaCore Production Release v1.3.1 Metadata

- **Release Version**: 1.3.1 (Build 1.0.0+1)
- **Target OS**: Android (minSdk 21, targetSdk 35, compileSdk 35)
- **Application ID**: `com.example.aquaflow_frontend`
- **Application Label**: `ArvaCore`
- **Build Mode**: Release (APK)
- **Build Date**: 2026-10-18T10:33:00+08:00
- **Flutter SDK**: 3.x (Dart 3.12.2+)
- **Production API URL**: `https://api-aquaflow.gladwindr.me`
- **Production WebSocket URL**: `wss://api-aquaflow.gladwindr.me/api/v1/telemetry/stream`

## Artifact Details
- **Filename**: `arvacore-v1.3.1-release.apk`
- **Size**: 56,278,702 bytes (53.67 MB)
- **SHA-256 Checksum**:
  `6a470148abe6bdb47d18a594ed10111f5004fde3b3f1544d1dc02ccbdb92120b`

## Summary of Changes in v1.3.1
1. **Resolved Monitoring Zone Removal Error (`ApiException`)**:
   - Sanitized zone identifier parsing: extracts numeric IDs to prevent Spring Boot controller `MethodArgumentTypeMismatchException` (400 Bad Request).
   - Field-scoped endpoint routing: calls `DELETE /api/v1/fields/{fieldId}/zones/{zoneId}` with graceful fallback to `/api/v1/zones/{zoneId}`.
   - Safe Node Unassignment: automatically unassigns physically bound ArvaNodes to the unassigned hardware pool (`monitoringZoneId: null`) prior to zone deletion to prevent foreign-key conflict errors and preserve node telemetry/pairing status.
   - Enhanced Error Presentation: user-friendly UI alerts mapping HTTP 403 (Administrator permissions required), 404 (already removed), 409 (conflict), and network failures.
2. **Dashboard Consistency & Research Metrics Integration**:
   - Validated real telemetry flow from active ESP32 nodes into Home dashboard, Farmland Designer, and Research Metrics.
   - Theming consistency ensured across dark and light modes.
