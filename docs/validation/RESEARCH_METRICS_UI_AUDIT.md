# ArvaCore Mobile UI Audit Report: E-Research Metrics Overflow Fixes

**Date**: 2026-10-20  
**Target Subsystem**: Research Metrics (E-Research Metrics Tab / `SystemEvaluationDashboardScreen`)  
**Components Modified**:
- `lib/features/analytics/presentation/system_evaluation_dashboard_screen.dart`
- `lib/features/analytics/presentation/widgets/indicator_card.dart`
- `lib/core/api/api_factory.dart`
- `test/system_evaluation_viewport_test.dart`

---

## 1. Executive Summary

A layout audit of the **Research Metrics** screen on narrow and standard smartphone viewports identified multiple `RenderFlex` horizontal overflow exceptions:
1. **Missing Hardware & Calibration Requirements Header**: Rigid `Row` with unbounded title text (`'Missing Hardware & Calibration Requirements'`) overflowing on narrow viewports (< 360px).
2. **IndicatorCard Header**: Inflexible `Row` combining an icon container, expanded title/subtitle, and a fixed capability badge pill (`'NOT MEASURABLE'` / `'PARTIALLY MEASURABLE'`), causing a 25px right overflow on 320px devices.
3. **Metric Item Badges**: Rigid `Row` inside `_buildMetricItem` exceeding container boundaries on compact screens when displaying long decimal numbers or units.
4. **Calibration Notes & Ground-Truth Comparisons**: Long calibration strings and notes lacked responsive wrapping containers.

All underlying constraint bottlenecks have been resolved using responsive Flutter patterns (`Wrap`, `Flexible`, `Expanded`, `LayoutBuilder`) while strictly preserving research calculations, indicator states, and backend contracts.

---

## 2. Root Cause Analysis & Implementations

### A. Missing Hardware & Calibration Requirements
- **Original Bottleneck**:
  ```dart
  // Before: Unbounded Row header caused 421px overflow on narrow screens
  const Row(
    children: [
      Icon(Icons.build_circle_outlined, ...),
      SizedBox(width: 8),
      Text('Missing Hardware & Calibration Requirements', ...),
    ],
  )
  ```
- **Remediation**:
  - Replaced with an aligned `Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon, SizedBox, Expanded(child: Text(...))])`.
  - Structured requirements into distinct responsive alert cards:
    - **Hardware Requirement Alert**: In-line pulse flow meter (e.g., YF-B5 Hall-effect) with an icon and `Expanded` text.
    - **Calibration Requirement Alert**: Flow meter K-factor pulse calibration or hydraulic pump curve verification against manual collection bucket standards.

### B. IndicatorCard Header LayoutBuilder
- **Original Bottleneck**:
  On viewports below 320px wide (e.g. 320 × 568 Compact Phone), placing the icon (24px + 16px padding), `Expanded` title/subtitle, and the status badge (`NOT MEASURABLE` ~110px) in a single horizontal `Row` caused 15–25px overflow.
- **Remediation**:
  - Introduced a `LayoutBuilder` with an adaptive breakpoint at `constraints.maxWidth < 320`.
  - On compact devices, stacks the icon and status badge in an upper `Wrap`, followed by full-width title and subtitle.
  - On larger smartphones (>= 320px inner width) and landscape orientation, gracefully retains the balanced horizontal `Row`.

### C. Metric Item Overflow Protection
- **Original Bottleneck**:
  `_buildMetricItem` used `Row(children: [Icon, Column(children: [Text, Text])])`. When wrapped inside `Wrap`, long labels or values pushed beyond maximum mobile column boundaries.
- **Remediation**:
  - Added `constraints: const BoxConstraints(maxWidth: 260)`.
  - Wrapped metric label and value texts inside `Flexible` with `TextOverflow.ellipsis`.

### D. Soil Moisture Calibration Notes & Ground-Truth References
- Surfaced `sm.calibrationNotes` in a dedicated responsive callout banner inside `_buildSoilMoistureCard`.
- Maintained horizontal scrollability (`SingleChildScrollView(scrollDirection: Axis.horizontal)`) for `DataTable` ground-truth reference measurements.

---

## 3. Viewport Verification Matrix

All 6 required mobile device profiles were tested and verified with zero `RenderFlex` or layout exceptions:

| Test Profile | Viewport (W × H) | Orientation | Overflow Result | Status |
|---|---|---|---|---|
| **Compact phone** | 320 × 568 | Portrait | **0 px (Clean)** | PASS |
| **Narrow Android phone** | 360 × 640 | Portrait | **0 px (Clean)** | PASS |
| **Standard phone** | 360 × 800 | Portrait | **0 px (Clean)** | PASS |
| **Modern smartphone** | 390 × 844 | Portrait | **0 px (Clean)** | PASS |
| **Large smartphone** | 430 × 932 | Portrait | **0 px (Clean)** | PASS |
| **Landscape phone** | 844 × 390 | Landscape | **0 px (Clean)** | PASS |

---

## 4. Verification & Build Artifacts

1. **Automated Viewport Suite**: `test/system_evaluation_viewport_test.dart` (6/6 passed).
2. **Full Workspace Test Suite**: All 398 tests passed.
3. **Flutter Static Analysis**: `flutter analyze` completed with 0 errors.
4. **Production Android APK**:
   - **Path**: `build/app/outputs/flutter-apk/app-release.apk`
   - **Variant**: Release (`assembleRelease`)
   - **Size**: 54 MB (56.5 MB uncompressed binary)
   - **SHA-256**: `867a7ea4576ffae21189bde569957c91d0c2dcb39150fe42f53b1e9d3b99527b`
