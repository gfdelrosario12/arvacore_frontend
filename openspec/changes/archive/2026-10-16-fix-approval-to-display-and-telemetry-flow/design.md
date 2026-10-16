# Design: Frontend Approval-to-Display & Telemetry Flow

## Architecture & Component Interactions
1. **Node Approval Preservation**:
   - `field_screen.dart` forwards `req.nodeId` to `registerNode`, keeping the hardware MAC/node ID immutable regardless of custom display names.
2. **Resilient Zone-to-Node Association**:
   - `ApiMappers.esp32Node` and `monitoringZone` map backend field keys (`monitoringZoneId`, `fieldId`, `assignedNodes`).
   - Zone selection logic matches against `zone.assignedNodeIds.contains(node.id)`, `node.assignedZoneId == zone.id`, or matching zone codes.
3. **Spatial Placement Fallback**:
   - When nodes lack spatial coordinate configurations, `SpatialFieldNotifier` maps them to default offsets inside their assigned zone quadrant (Q1: top-left, Q2: top-right, Q3: bottom-left, Q4: bottom-right).
4. **Authoritative Hardware Metrics**:
   - Soil moisture (%) from capacitive sensor.
   - Pond water depth (cm) from ultrasonic transducer.
   - Battery level (%) from ADC voltage divider.
   - Signal RSSI (dBm).
   - Removed uninstalled ambient temperature and humidity metrics.

