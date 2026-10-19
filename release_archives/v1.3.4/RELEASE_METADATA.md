# ArvaCore Production Release v1.3.4 Metadata

- **Release Version**: 1.3.4 (Build 1.0.0+1)
- **Target OS**: Android (minSdk 21, targetSdk 35, compileSdk 35)
- **Application ID**: `com.example.aquaflow_frontend`
- **Application Label**: `ArvaCore`
- **Build Mode**: Release (APK)
- **Build Date**: 2026-10-20T03:54:00+08:00
- **Flutter SDK**: 3.x (Dart 3.12.2+)
- **Production API URL**: `https://api-aquaflow.gladwindr.me`
- **Production WebSocket URL**: `wss://api-aquaflow.gladwindr.me/api/v1/telemetry/stream`

## Artifact Details
- **Filename**: `arvacore-v1.3.4-release.apk`
- **Size**: 56,393,682 bytes (53.78 MB)
- **SHA-256 Checksum**:
  `a9dd8900a1b05f12e90b98bd0674be8d1c0fab096d8931f84b4727f56720b741`

## Summary of Changes in v1.3.4
1. **Mandatory Manual Unpair Node Button & Confirmation**:
   - Implemented dedicated **Unpair Node** button on each connected node card in `ConnectedNodesCard` (`HomeScreen`) and `DeviceDetailDialog` (`DeviceDiagnosticsScreen`).
   - Enhanced `NodeUnpairConfirmationDialog` with explicit confirmation message: *"Are you sure you want to unpair this node? This will revoke its association with ArvaCore. You will need to pair it again before it can resume normal authorized operation."*
   - Supported offline unpairing: Backend processes revocation immediately regardless of whether the physical ESP32 node is online or offline.
2. **Backend Unpairing API & Re-Pairing Lifecycle**:
   - Supported both standard `DELETE /api/v1/nodes/{nodeId}/pairing` and POST action alias `POST /api/v1/nodes/{nodeId}/unpair`.
   - Verified that unpairing immediately revokes credentials, transitions edge nodes to `UNREGISTERED`, disassociates monitoring points, clears telemetry frame caches, and logs system audit records.
   - Tested full re-pairing workflow: Unpaired nodes successfully submit fresh pairing requests (`POST /api/v1/pairing/request`), receive operator approval, regain `ACTIVE` status, and resume telemetry transmission without firmware reflash.
3. **Full System Verification**:
   - Frontend test suite: **391 / 391 tests passed** (`flutter test --no-pub`).
   - Backend test suite: **255 / 255 tests passed** (`mvn test`).

