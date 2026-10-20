# Telemetry Stream Responsive Audit & AWD to Irrigation Terminology Migration

## Overview

This audit documents the responsive UI overflow resolutions on the **ESP Telemetry Stream** and **E-Research Metrics** screens, as well as the transition from legacy **AWD** (Alternate Wetting and Drying) conceptual framing to **Irrigation** / **Hydrology** domain terminology.

---

## 1. ESP Telemetry Stream Overflows & Fixes

### 1.1 `TelemetryStreamScreen`
- **Issue**:
  - `AppBar` title with actions caused title truncation/collision on narrow devices (320px–360px).
  - Search box and node selection dropdown inside `_buildFilterBar` overflowed by 20–50px horizontally when side-by-side on devices ≤360px.
  - Quick event filter chip row forced horizontal expansion or clipped chips.
  - Ingestion rates summary header overflowed when title and timestamps competed for horizontal space.
- **Solution**:
  - Shortened `AppBar` title to `'ESP32 Telemetry'` wrapped in `Flexible` with `TextOverflow.ellipsis`.
  - Pause/Resume control converted to a compact `FilledButton.tonal` with responsive text/icon handling.
  - Filter bar wrapped in `LayoutBuilder`: stacks search and node dropdown vertically when `constraints.maxWidth < 360`, and displays side-by-side with `Expanded` widgets on wider screens.
  - Filter chips converted to `Wrap(spacing: 6, runSpacing: 6)` with horizontal padding, ensuring zero overflow on narrow viewports.
  - Ingestion rate header wrapped in `Wrap(alignment: WrapAlignment.spaceBetween)` with flexible subtitles.

### 1.2 `TelemetryStreamSummaryCard`
- **Issue**: Header row containing title and WebSocket connection status badge overflowed on 320px Compact phones.
- **Solution**:
  - Encapsulated header with `LayoutBuilder`: at `< 360px`, badge and stream title stack vertically; at `>= 360px`, they sit side-by-side with `Expanded` label text and ellipsis.

### 1.3 `TelemetryStreamEventCard`
- **Issue**:
  - Node ID tag, sequence number pill, and zone badge competed on the same row, triggering 5.4px to 108px overflows.
  - Sensor measurement chips with long numerical strings (e.g. `Water Depth: 45.2 cm`) overflowed card width.
  - Event payload accordion toggle header overflowed on narrow screens with long timestamps.
- **Solution**:
  - Top header row restructured with `Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center)` and constrained Node ID chip (`BoxConstraints(maxWidth: 180)`).
  - Measurement chips wrapped with `BoxConstraints(maxWidth: 240)` and text ellipsis.
  - Expanded JSON viewer row and timestamp lines wrapped in `Flexible` and `Expanded` with compact icon actions.

---

## 2. E-Research Metrics UI Fixes

- **Missing Hardware Section**: Alert callout title wrapped in `Expanded`, ensuring long device labels and warning descriptions wrap onto subsequent lines without clipping.
- **Calibration Requirements Section**: Callout descriptions and sensor badges constrained with `maxWidth: 260` and `TextOverflow.ellipsis`.
- **`IndicatorCard`**: Implemented `LayoutBuilder` breakpoint at `< 320px` to vertically align status badge and indicator title on compact smartphones.

---

## 3. AWD -> Irrigation Terminology Standardization

To eliminate outdated conceptual framing while safeguarding technical API and DTO contracts:
1. **User-Facing UI Elements**:
   - Screen AppBars: `ArvaCore Irrigation Analytics`.
   - Headers: `Field-Wide Irrigation Condition`, `Configurable Irrigation Threshold Rules`.
   - Buttons: `View Detailed Irrigation Analytics`, `Simulate Irrigation Telemetry States`.
   - Badges: Added `StatusBadge.hydrologyStatus()` (with backward compatibility alias `StatusBadge.awdStatus()`).
   - Audit logs: `System (Auto-Irrigation)` alongside operator manual triggers.
   - Designer warnings: `irrigation sensor telemetry`.
2. **Theme Colors**:
   - Added `AppColors.irrigationSafe`, `AppColors.irrigationRefluxNeeded`, `AppColors.irrigationFlooded`.
   - Preserved `awd*` color getters as deprecation-safe aliases.
3. **Internal DTOs & WebSockets**:
   - Preserved backend contract fields (`awdProfileId`, `awd_analysis_completed` events) to ensure zero network breakage against existing microservices.

---

## 4. Mobile Viewport Validation Matrix

All 6 required mobile device profiles passed with **0 layout overflows**:

| Viewport Profile | Resolution | Orientation | Status |
| :--- | :--- | :--- | :--- |
| **Compact phone** | 320 × 568 | Portrait | **PASS** (0 overflows) |
| **Narrow Android** | 360 × 640 | Portrait | **PASS** (0 overflows) |
| **Standard phone** | 360 × 800 | Portrait | **PASS** (0 overflows) |
| **Modern phone** | 390 × 844 | Portrait | **PASS** (0 overflows) |
| **Large phone** | 430 × 932 | Portrait | **PASS** (0 overflows) |
| **Landscape phone** | 844 × 390 | Landscape | **PASS** (0 overflows) |

