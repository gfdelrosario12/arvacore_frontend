# Tasks: Fix Approval-to-Display and Telemetry Rendering Flow

- [x] Fix `ApiMappers.esp32Node` and `monitoringZone` to parse `monitoringZoneId`, `fieldId`, and assigned nodes
- [x] Fix `field_screen.dart` approval handlers to preserve physical `nodeId` and broaden zone matching
- [x] Add quadrant-based fallback in `SpatialFieldNotifier.getNormalizedPosition`
- [x] Enrich `FieldDashboardRepositoryImpl.fetchDashboardSummary` with live node readings via `ApiNodeRepository`
- [x] Replace unequipped temperature and humidity widgets in `zone_detail_bottom_sheet.dart` and `zone_analysis_screen.dart` with battery and signal tiles
- [x] Verify static analysis with `dart analyze` (0 errors)
