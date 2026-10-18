# ArvaCore Production Release v1.3.2 Metadata

- **Release Version**: 1.3.2 (Build 1.0.0+1)
- **Target OS**: Android (minSdk 21, targetSdk 35, compileSdk 35)
- **Application ID**: `com.example.aquaflow_frontend`
- **Application Label**: `ArvaCore`
- **Build Mode**: Release (APK)
- **Build Date**: 2026-10-18T12:25:00+08:00
- **Flutter SDK**: 3.x (Dart 3.12.2+)
- **Production API URL**: `https://api-aquaflow.gladwindr.me`
- **Production WebSocket URL**: `wss://api-aquaflow.gladwindr.me/api/v1/telemetry/stream`

## Artifact Details
- **Filename**: `arvacore-v1.3.2-release.apk`
- **Size**: 56,344,290 bytes (53.73 MB)
- **SHA-256 Checksum**:
  `acdcc6d75c85800592fa0c80ee0073d670554aa43868c98a6411a2b01ed2bd11`

## Summary of Changes in v1.3.2
1. **Application-Wide UI State Synchronization & Cache Coherence**:
   - **Immediate Local Mutation (Optimistic UI)**: When a monitoring zone or farmland is removed/archived, the frontend immediately prunes the item from local reactive collections (`_zones`, `_editableZones`, `_selectedZoneId`, `_selectedZoneCode`) before waiting for the network re-fetch to complete. This prevents ghost components from remaining on screen.
   - **Dynamic Field Fetching & Elimination of Hardcoded Fallback**: Replaced hardcoded fallback field `'ArvaCore Demonstration Farmland'` in `FieldScreen` with dynamic querying via `listFields()`. When a farmland is deleted or unconfigured, the UI accurately renders `No Active Farmland Configured` empty-state view rather than fabricating a phantom farm.
   - **Archived Zone Filtering**: Filtered out soft-deleted and archived records (`!isArchived && operationalStatus != 'ARCHIVED'`) in `ApiZoneRepository` and `ZoneRepositoryImpl` across all field endpoints.
   - **Farmland Deletion Support**: Implemented `deleteField(fieldId)` in `FieldApiService` (`DELETE /api/v1/fields/{id}`) and added interactive "Delete Farmland" confirmation workflow with automatic node unassignment and clean empty state transition.
   - **Designer Grid Resynchronization**: Updated `FarmlandDesignerView.didUpdateWidget` to detect zone list removals even when local layout edits were pending, ensuring deleted zones vanish instantly from the visual design canvas.
