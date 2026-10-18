# ArvaCore Production Release v1.3.3 Metadata

- **Release Version**: 1.3.3 (Build 1.0.0+1)
- **Target OS**: Android (minSdk 21, targetSdk 35, compileSdk 35)
- **Application ID**: `com.example.aquaflow_frontend`
- **Application Label**: `ArvaCore`
- **Build Mode**: Release (APK)
- **Build Date**: 2026-10-19T04:05:00+08:00
- **Flutter SDK**: 3.x (Dart 3.12.2+)
- **Production API URL**: `https://api-aquaflow.gladwindr.me`
- **Production WebSocket URL**: `wss://api-aquaflow.gladwindr.me/api/v1/telemetry/stream`

## Artifact Details
- **Filename**: `arvacore-v1.3.3-release.apk`
- **Size**: 56,393,682 bytes (53.78 MB)
- **SHA-256 Checksum**:
  `48c6630fa06f1da526c0f112df814a41d11a83e0e8a79e4b3fe676594575c99f`

## Summary of Changes in v1.3.3
1. **Node Lifecycle & Pairing Reset Integration**:
   - Integrated full backend pairing reset (`POST /api/v1/nodes/pairing/reset`) with reset scopes (`UNASSIGNED_ONLY`, `ALL_PAIRED`, `FACTORY_ALL`).
   - Implemented dedicated node detachment API (`DELETE /api/v1/nodes/{id}/field-assignment`) distinct from hardware unpairing (`POST /api/v1/nodes/unpair`).
   - Added interactive `NodeUnpairDialog` with field detachment option vs factory hardware unpairing.
2. **Dynamic Farmland & Zone Designer Refinement**:
   - Resolved visual overflow in `FarmlandDesignerView` on compact mobile widths (threshold adapted to 950px with responsive Wrap header).
   - Synchronized zone unassignment, deletion, and reactive card updates across `DynamicZoneGridVisualizer` and `FieldHeaderOverviewCard`.
3. **Frontend & Backend Test Suite Verification (100% Pass)**:
   - Frontend: 391/391 tests passing (`flutter test --no-pub`).
   - Backend: 254/254 tests passing (`mvn test`).
   - Fixed mock state handlers, URL prefix normalizations, and responsive view tests.

