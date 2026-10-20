# ArvaCore Production Release v1.3.5 Metadata

- **Release Version**: 1.3.5 (Build 1.0.0+1)
- **Target OS**: Android (minSdk 21, targetSdk 35, compileSdk 35)
- **Application ID**: `com.example.aquaflow_frontend`
- **Application Label**: `ArvaCore`
- **Build Mode**: Release (APK)
- **Build Date**: 2026-10-20T12:30:00+08:00
- **Flutter SDK**: 3.x (Dart 3.12.2+)
- **Production API URL**: `https://api-aquaflow.gladwindr.me`
- **Production WebSocket URL**: `wss://api-aquaflow.gladwindr.me/api/v1/telemetry/stream`

## Artifact Details
- **Filename**: `arvacore-v1.3.5-release.apk`
- **Size**: 59,240,612 bytes (56.5 MB)
- **SHA-256 Checksum**:
  `57a09a980b5758e437567a701daeed874ab6d27444eb833955f377240aa0c0a9`

## Summary of Changes in v1.3.5
1. **Full System-Wide Pairing Reset & Unpairing Synchronization**:
   - Resolved the issue where resetting pairings removed nodes from Home Dashboard but left lingering assigned nodes or chips in Field Dashboard zones.
   - Updated backend `ZoneServiceImpl`, `FieldTopologyServiceImpl`, and `FarmlandValidationServiceImpl` to strictly filter out `UNREGISTERED` and `DECOMMISSIONED` nodes from zone assigned node responses and topology calculations.
   - Enhanced `NodePairingServiceImpl.resetPairing` to clear monitoring zone associations, point bindings, revoke pending pairing requests, close active node assignment histories, and trigger farmland readiness recalculations.
2. **Contextual Unpairing and Reset UX Across Field Management Views**:
   - Integrated `NodeUnpairConfirmationDialog` and dedicated "Unpair" action buttons in `FieldScreen` unassigned nodes card, `ZoneDetailBottomSheet`, `FarmlandDesignerView`, and `ConnectedNodesCard`.
   - Wired administrative `Reset Pairings` button with confirmation into `FieldHeaderOverviewCard`.
   - Sanitized frontend zone enrichment in `field_dashboard_repository.dart` and `field_screen.dart` to purge stale assigned node identifiers whenever active matching nodes are absent.
3. **Rigorous Verification & Test Coverage**:
   - Frontend test suite: **391 / 391 tests passed** (`flutter test --no-pub`).
   - Backend test suite: **256 / 256 tests passed** (`mvn test`).
   - Zero compilation errors and zero static analysis warnings.

