# ArvaCore / ArvaLink Mobile Production Release v1.3.8 Metadata

- **Release Version**: 1.3.8 (Build 1.3.8+8)
- **Target OS**: Android (minSdk 24, targetSdk 36, compileSdk 36)
- **Application ID**: `com.example.aquaflow_frontend`
- **Application Label**: `ArvaLink`
- **Build Mode**: Release (APK)
- **Build Date**: 2026-10-22T20:44:00+08:00
- **Flutter SDK**: 3.44.8 (Dart 3.12.2+)
- **Production API URL**: `https://api-aquaflow.gladwindr.me`
- **Transport**: REST polling only (no WebSocket telemetry channel)

## Artifact Details
- **Filename**: `arvacore-v1.3.8-release.apk`
- **Size**: 56,968,893 bytes (54.3 MiB / 57.0 MB)
- **SHA-256 Checksum**:
  `0de3a0576cf960aadaea4f883bc7d0811367c9897b8ac4cba21c723e5763c898`

## Headline Change: Real-Time Home Dashboard Telemetry
- **5-Second Centralized Dashboard Poll**:
  - The Home Dashboard now owns the only telemetry poll in the application. It requests the
    newest reading of every node from the batched backend endpoint
    `GET /api/v1/nodes/telemetry/latest` every 5 seconds while the dashboard is visible.
  - The poll never overlaps with itself, is cancelled when the dashboard is disposed, is
    paused while the Home tab is hidden or the application is inactive, and refreshes
    immediately when the user returns to the dashboard.
  - Bounded exponential backoff (2s → 30s) is applied while the backend is unreachable and
    the normal 5-second interval resumes automatically after the first successful poll.
- **No Flicker**:
  - A refresh keeps the previously rendered readings on screen while the request is in
    flight; only the changed values are swapped in when the response arrives.
- **Stale Handling**:
  - When the backend is temporarily unavailable the last received readings are retained and
    the dashboard shows an explicit "showing last known readings" warning plus the stale
    telemetry badge instead of blanking the screen.
- **Correct Value Semantics**:
  - A reported numeric `0` is rendered as `0.0%` / `0.0 cm`; a measurement that was never
    reported renders as `--` so a missing value is never confused with a zero.
  - Sensor health badges are rendered independently from the measurements, and pairing and
    zone-assignment state stay independent from the telemetry state.
  - The last telemetry timestamp of every node is displayed on the node card.

## Security Remediation & Integrity Audit (carried forward from v1.3.7)
1. **Cryptographic Release Signing**:
   - ArvaLink production keystore (`CN=ArvaLink Mobile, OU=Mobile Security, O=ArvaCore Project`).
   - 4096-bit RSA key with SHA-384 with RSA signature.
   - Dual-scheme signing active: APK Signature Scheme v2 (`true`) and v3 (`true`).
2. **Network Security Configuration**:
   - `res/xml/network_security_config.xml` enforces system CA trust and disallows global
     cleartext traffic; only local development loopback addresses are exempted.
3. **Application Sandboxing & Backup Protection**:
   - `android:allowBackup="false"` prevents adb backup extraction of auth tokens.
   - Dynamic receivers are protected by `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.
4. **Bytecode Minification & Obfuscation**:
   - R8 minification (`isMinifyEnabled = true`) and resource shrinking (`isShrinkResources = true`)
     with `proguard-rules.pro` preserving the Flutter embedding and Secure Storage bindings.
5. **iOS App Store & Privacy Manifest Compliance**:
   - Apple Privacy Manifest (`ios/Runner/PrivacyInfo.plist` → `PrivacyInfo.xcprivacy`)
     declaring `NSPrivacyAccessedAPICategoryFileTimestamp` / user defaults usage.
   - Zero tracking domains.
6. **Full Test Regression Suite**:
   - **423 / 423 tests passed** (`flutter test`), including the new
     `test/dashboard_polling_test.dart` and `test/dashboard_telemetry_refresh_test.dart`
     suites covering the 5-second cycle, request de-duplication, backoff, zero-versus-missing
     rendering and stale retention.
