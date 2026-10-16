# OpenSpec Proposal: Fix Approval-to-Display and Telemetry Rendering Flow

## 1. Problem Statement
In ArvaLink, approved nodes failed to appear in their assigned fields and quadrants, and real-time telemetry was missing from the Home dashboard.
Investigation identified four client-side root causes:
1. `ApiMappers.esp32Node` looked for `data['assignedZoneId']` and `data['assignedFieldId']`, which the backend returns as `monitoringZoneId` and `fieldId`. This caused `assignedZoneId` to evaluate to `null`, detaching the node from the field view.
2. In `field_screen.dart`, approving a node sent `registerReq.displayName` as the `nodeId`. This overwrote the physical hardware ID (`NODE-xxxx`), breaking lookup for all subsequent telemetry transmissions.
3. In `FieldDashboardRepositoryImpl`, `fetchDashboardSummary` called `fetchMonitoringZones` but did not enrich the zones with live node-level sensor readings, leaving Home metrics at zero or default values.
4. UI screens displayed unequipped and simulated metrics (temperature and humidity) rather than truthful supported hardware metrics (battery level and wireless signal strength).

## 2. Proposed Changes
- In `ApiMappers`, extract zone and field IDs flexibly from `monitoringZoneId ?? assignedZoneId ?? zoneId` and `fieldId ?? assignedFieldId`.
- In `field_screen.dart`, preserve hardware `req.nodeId` during approval and widen node-to-zone matching to check `zone.assignedNodeIds`, zone codes, and zone IDs.
- In `spatial_field_notifier.dart`, add quadrant-based fallback coordinates so nodes without GPS coordinates render visibly within their assigned zone quadrant.
- In `FieldDashboardRepositoryImpl`, inject `ApiNodeRepository` and enrich `MonitoringZone` models with live node readings (`soilMoisturePercent`, `waterLevelCm`, `batteryPercent`).
- In `zone_detail_bottom_sheet.dart` and `zone_analysis_screen.dart`, replace unequipped temperature and humidity widgets with actual supported battery level and signal strength.

## 3. Verification & Compliance
- Ensure `dart analyze` passes with 0 errors across all modified files.
- Verify that only supported sensors (capacitive soil moisture, ultrasonic water depth, battery ADC, signal RSSI) are rendered.

