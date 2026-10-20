# ArvaCore / ArvaLink Mobile Production Release v1.3.7 Metadata

- **Release Version**: 1.3.7 (Build 1.3.7+7)
- **Target OS**: Android (minSdk 24, targetSdk 36, compileSdk 36)
- **Application ID**: `com.example.aquaflow_frontend`
- **Application Label**: `ArvaLink`
- **Build Mode**: Release (APK)
- **Build Date**: 2026-10-20T22:29:00+08:00
- **Flutter SDK**: 3.44.8 (Dart 3.12.2+)
- **Production API URL**: `https://api-aquaflow.gladwindr.me`
- **Production WebSocket URL**: `wss://api-aquaflow.gladwindr.me/api/v1/telemetry/stream`

## Artifact Details
- **Filename**: `arvacore-v1.3.7-release.apk`
- **Size**: 56,755,850 bytes (56.8 MB)
- **SHA-256 Checksum**:
  `3ffafafeb8e3b65e1ab4caf908892ff20c8ce481466fd11851ad3dc6d7c8574f`

## Security Remediation & Integrity Audit
1. **Cryptographic Release Signing**:
   - Replaced default Android Debug keystore (`CN=Android Debug`) with dedicated ArvaLink production keystore (`CN=ArvaLink Mobile, OU=Mobile Security, O=ArvaCore Project, L=Manila, ST=Metro Manila, C=PH`).
   - Signing Key: 4096-bit RSA key with SHA-384 with RSA signature.
   - Dual-scheme signing active: APK Signature Scheme v2 (`true`) and APK Signature Scheme v3 (`true`).
   - Verified via `apksigner verify --verbose --print-certs`.
2. **Network Security Configuration**:
   - Eliminated `android:usesCleartextTraffic="true"`.
   - Introduced `res/xml/network_security_config.xml` enforcing system CA trust and disallowing global cleartext traffic.
   - Constrained unencrypted HTTP traffic strictly to local development loopback addresses (`10.0.2.2`, `localhost`, `127.0.0.1`).
3. **Application Sandboxing & Backup Protection**:
   - Hardened `AndroidManifest.xml` with `android:allowBackup="false"` to prevent adb backup extraction of auth tokens and local cache.
   - Enforced signature protection on dynamic receivers (`DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`).
4. **Bytecode Minification & Obfuscation**:
   - Enabled R8 minification (`isMinifyEnabled = true`) and resource shrinking (`isShrinkResources = true`).
   - Added `proguard-rules.pro` preserving Flutter embedding, JNI hooks, and AndroidX Security Crypto / Secure Storage bindings while stripping unreferenced classes and debug metadata.
5. **iOS App Store & Privacy Manifest Compliance**:
   - Added Apple Privacy Manifest (`ios/Runner/PrivacyInfo.xcprivacy`) declaring `NSPrivacyAccessedAPITypeUserDefaults` under approved reason code `CA92.1`.
   - Declared zero tracking domains and zero third-party fingerprinting collectors.
   - Aligned iOS bundle display name to `ArvaLink` in `ios/Runner/Info.plist`.
6. **Full Test Regression Suite**:
   - **404 / 404 tests passed** (`flutter test`).
