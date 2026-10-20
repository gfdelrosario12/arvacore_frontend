# ArvaCore Production Release v1.3.6 Metadata

- **Release Version**: 1.3.6 (Build 1.0.0+1)
- **Target OS**: Android (minSdk 21, targetSdk 35, compileSdk 35)
- **Application ID**: `com.example.aquaflow_frontend`
- **Application Label**: `ArvaCore`
- **Build Mode**: Release (APK)
- **Build Date**: 2026-10-20T17:22:00+08:00
- **Flutter SDK**: 3.44.8 (Dart 3.12.2+)
- **Production API URL**: `https://api-aquaflow.gladwindr.me`
- **Production WebSocket URL**: `wss://api-aquaflow.gladwindr.me/api/v1/telemetry/stream`

## Artifact Details
- **Filename**: `arvacore-v1.3.6-release.apk`
- **Size**: 56,524,754 bytes (56.5 MB)
- **SHA-256 Checksum**:
  `c8e8fcec14a1b24b11df17e909b002c6b1242e4e6778998ccaf108415cda9bc4`

## Summary of Changes in v1.3.6
1. **Durable API Connectivity & Dual-Stack Infrastructure Hardening**:
   - Resolved cross-origin preflight `OPTIONS` rejection in Spring Security backend by adopting origin pattern matching (`setAllowedOriginPatterns`) with credential support and explicit OPTIONS authorization.
   - Configured Nginx dual-stack reverse proxy listeners (`listen [::]:443 ssl;` and `listen [::]:80;`) on the HostHatch VPS to prevent IPv6/NAT64 mobile network requests from colliding with default VirtualHost SSL certificates.
   - Added bypass for HTTP `OPTIONS` requests in `RateLimitingFilter`, `WebhookAuthenticationFilter`, and `GatewayAuthenticationFilter`.
2. **Frontend UI Reliability & Controller Disposal Guards**:
   - Added `mounted` guards in `login_screen.dart` prior to disposing or clearing controllers during authentication transitions.
   - Hardened `dynamic_zone_grid_visualizer.dart` layout constraints and aspect ratio logic to prevent RenderFlex overflow across narrow screen widths (360px–400px).
3. **Rigorous Verification & Test Coverage**:
   - Backend test suites: 100% pass (including new `CorsConfigurationTest`).
   - Frontend test suite: **392 / 392 tests passed** (`flutter test`).
   - Android APK built and verified with SHA-256 checksum integrity.
