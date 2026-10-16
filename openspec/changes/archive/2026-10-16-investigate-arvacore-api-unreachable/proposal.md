# OpenSpec Proposal: Investigation and Resolution of "Unable to reach ArvaCore API" from Alternative Perspectives

## 1. Problem Statement

Operators accessing the ArvaNet frontend encounter the persistent blocking error:
> **"Unable to reach the ArvaCore API."**

Even though backend API health checks and standalone terminal `curl` requests succeed, operators in browser and client runtime environments cannot complete authentication or initialize their dashboards. Previous attempts to resolve this issue focused on:
1. Enforcing `https://api-aquaflow.gladwindr.me` as the canonical URL.
2. Adding `@GetMapping("/status")` to `IrrigationController`.
3. Updating backend allowed origin patterns.

Despite these changes, the error persists because of an unverified runtime boundary: **the live browser environment executes under browser web security policies and multi-request lifecycle dependencies that standalone `curl` scripts bypass.**

---

## 2. Verified Current State

### A. Repositories and Components
- **`arvacore_arvanet_frontend`**: Flutter Web & Mobile client.
  - Generates the exact error message at `lib/core/api/api_client.dart:247`:
    ```dart
    throw ApiException(
      kind: ApiErrorKind.connectivity,
      message: 'Unable to reach the ArvaCore API.',
      cause: error,
    );
    ```
  - Sends initial and authenticated requests with a custom header `X-Client: aquasense-mobile` (`lib/core/api/api_client.dart:282`).
  - Upon successful login, navigates to `AppShell` with tab index 0 displaying `HomeScreen`.
  - `HomeScreen` immediately executes `fetchDashboardSummary()` which calls `_zoneRepository.fetchMonitoringZones()` (`GET /api/v1/zones`) and `_irrigationRepository.fetchSystemStatus()`.
  - `FieldScreen` (tab index 1) also executes `_loadZones()` on initialization.
- **`arvanet_arvanet_backend`**: Spring Boot 4.1.1 Java service.
  - Deployed in Docker container `aquaflow-backend` behind Nginx reverse proxy at `https://api-aquaflow.gladwindr.me`.
  - Configured CORS in `SecurityConfig.java`:
    ```java
    configuration.setAllowedHeaders(List.of("Authorization", "Content-Type", "X-Correlation-ID", "X-Webhook-Secret", "X-Downlink-Secret"));
    ```
    *(Notice `X-Client` is missing from `setAllowedHeaders`!)*

### B. Live Runtime Evidence
1. **Direct Terminal Probe**:
   A direct POST to `https://api-aquaflow.gladwindr.me/api/v1/auth/login` with `Content-Type: application/json` returns `HTTP 200 OK` with valid JWT tokens.
2. **Browser Preflight Verification**:
   When simulated as a browser preflight request (`OPTIONS`) requesting headers `Content-Type,Accept,X-Client,Authorization`, the server responds:
   ```http
   HTTP/1.1 200 OK
   Access-Control-Allow-Origin: http://localhost:3000
   Access-Control-Allow-Headers: Content-Type, Authorization
   ```
   **Crucial Discrepancy**: The browser requests permission to send `X-Client`. The backend omits `X-Client` from `Access-Control-Allow-Headers`. In browsers (Chrome, Edge, Firefox), the Fetch / XMLHttpRequest API **strictly rejects the request as a CORS violation**, throwing a generic client-side network error (`ClientException` or `TypeError: Failed to fetch`).
3. In `ApiClient._send`, this browser network rejection is caught by `catch (error)` and mapped directly to:
   ```dart
   ApiException(
     kind: ApiErrorKind.connectivity,
     message: 'Unable to reach the ArvaCore API.',
     cause: error,
   );
   ```

---

## 3. Alternative Root-Cause Analysis (Independent Technical Perspectives)

| Perspective | Hypothesis | Evidence For / Against | Conclusion |
| :--- | :--- | :--- | :--- |
| **Perspective A: Request Never Sent** | Form validation or UI event loop halts before dispatch. | **Refuted**: In `login_screen.dart`, `_handleLogin()` validates and awaits `_notifier.login()`. Logging demonstrates execution reaches `_send`. | Not the primary cause. |
| **Perspective B: Wrong Destination** | Path prefix mismatch (e.g. `/api/api/v1`) or stale local fallback. | **Partially Contributory**: `ApiConfig.fromEnvironment()` previously defaulted to `http://localhost:8080/api/v1`. Corrected in local tree, but running client must run updated bundle. | Secondary factor. |
| **Perspective C: Network / CORS Filter Block** | Preflight negotiation fails in browser runtime due to headers or origin restrictions. | **Confirmed by Live Probe**: The Flutter web client sends `X-Client: aquasense-mobile`. Spring Boot `SecurityConfig` does **not** include `X-Client` in `allowedHeaders`. The browser browser security model aborts the connection with a network failure before payload delivery. | **Primary Root Cause (Browser)**. |
| **Perspective D: Server Rejection** | Server returns HTTP 401, 403, or 500. | **Refuted for login, Confirmed for Dashboard**: `/api/v1/auth/login` returns HTTP 200. However, subsequent unmapped routes (`/api/v1/irrigation/status`) previously returned 500. | Co-factor in post-login dashboard crash. |
| **Perspective E: Token Parsing Failure** | Client fails to parse JWT or field claims. | **Refuted**: Base64Url padding and claims parsing logic in `AuthToken.withClaimsFromJwt` and `ApiMappers.userSession` handle standard Spring Boot JWT schemas. | Not the cause. |
| **Perspective F: Post-Login Initialization Cascade** | Dashboard initialization crashes after login, mimicking connectivity failure. | **Confirmed**: `HomeScreen` and `FieldScreen` invoked unmapped routes concurrently; any failure was presented as a general failure. | Co-factor resolved in code changes. |
| **Perspective G: Deployment / Cache Mismatch** | VPS container or browser holds stale compilation artifacts. | **Confirmed**: Backend container on VPS had not received the updated `IrrigationController` and CORS configuration; browser client held cached JavaScript. | Operational barrier. |

---

## 4. Failure Localization Boundary

We establish 12 concrete checkpoints along the authentication and dashboard lifecycle:

1. `[PASS]` **Form Submission**: Operator clicks "Sign In", triggering `_handleLogin()`.
2. `[PASS]` **Request Construction**: `AuthApiService.login()` constructs payload `{"username": "Gladwin", ...}`.
3. `[PASS]` **Header Composition**: `_headers()` adds `Content-Type`, `Accept`, and `X-Client: aquasense-mobile`.
4. `[FAIL in Browser]` **Browser Preflight (OPTIONS)**:
   - Browser sends `Access-Control-Request-Headers: Content-Type,Accept,X-Client`.
   - Backend replies without `X-Client` in `Access-Control-Allow-Headers`.
   - Browser terminates request with `TypeError: Failed to fetch`.
   - Catch block triggers: `"Unable to reach the ArvaCore API."`.
5. `[PASS via curl / FAIL in Browser]` **Reverse Proxy / Nginx**: Upstream proxy accepts traffic.
6. `[PASS via curl]` **Backend Controller**: `AuthController.login()` verifies credentials.
7. `[PASS via curl]` **Token Issuance**: Returns HTTP 200 with JWT tokens.
8. `[PASS]` **Response Parsing**: `UserSession` and `AuthToken` decode claims.
9. `[PASS]` **State Emission**: `AuthState.authenticated` is emitted.
10. `[PASS]` **AppShell Transition**: Application displays `HomeScreen` and `FieldScreen`.
11. `[FAIL on un-updated backend]` **Dashboard Data Fetch**: `fetchSystemStatus()` hits `/api/v1/irrigation/status` (requires backend update on VPS).
12. `[RESOLVED with decoupled loading]` **Dashboard UI Presentation**: Independent components render without global cascade failure.

The **earliest failing checkpoint** in the browser is **Checkpoint 4**.

---

## 5. Proposed Changes

### A. Backend (`arvanet_arvanet_backend`)
1. **`src/main/java/com/aquaflow/backend/config/SecurityConfig.java`**:
   - Update `corsConfigurationSource()` to explicitly allow `X-Client` and wildcard/standard custom headers:
     ```java
     configuration.setAllowedHeaders(List.of(
         "Authorization",
         "Content-Type",
         "Accept",
         "X-Client",
         "X-Correlation-ID",
         "X-Webhook-Secret",
         "X-Downlink-Secret"
     ));
     ```
2. **`src/main/java/com/aquaflow/backend/api/IrrigationController.java`**:
   - Maintain the implemented `@GetMapping("/status")` routing to `IrrigationDecisionService.getFieldIrrigationStatus(fieldId)`.

### B. Frontend (`arvacore_arvanet_frontend`)
1. **`lib/core/api/api_client.dart`**:
   - Provide accurate diagnostics in `ApiException` causes (surface underlying XMLHttpRequest or network error details).
   - Ensure header consistency across mobile and web targets.
2. **`lib/features/home/data/repositories/field_dashboard_repository.dart`**:
   - Add resilient fallback when `_irrigationRepository.fetchSystemStatus()` returns empty or default data, ensuring `HomeScreen` displays available zone summaries cleanly.
3. **`lib/features/field/presentation/field_screen.dart`**:
   - Maintain decoupled, fault-tolerant `_loadZones()` logic so hardware pairing requests (`NODE-C3E8`) and zones render even if optional actuators are offline.

---

## 6. Targeted Regression Tests

1. **Backend CORS Preflight Test**:
   - Update `BackendSecurityHardeningTest.java` or `AuthControllerTest.java` to perform an `OPTIONS` preflight request with `Access-Control-Request-Headers: X-Client, Content-Type, Authorization` and assert `Access-Control-Allow-Headers` contains `X-Client`.
2. **Backend Irrigation Status Unit Test**:
   - Execute `IrrigationControllerTest.shouldReturnSystemStatusSuccessfully()` to ensure `GET /api/v1/irrigation/status` returns HTTP 200.
3. **Frontend API Client Error Parsing Test**:
   - Verify that non-200 responses and connection exceptions preserve actionable diagnostic context.

---

## 7. Deployment and Verification Plan

1. **Commit & Push Backend Changes**:
   - Commit the `SecurityConfig.java` and `IrrigationController.java` updates to `aquaflow_backend.git` main branch.
2. **Redeploy Backend Container on VPS**:
   - Run `./scripts/redeploy-and-test.sh` to trigger container rebuild and verify health probes.
3. **Test Browser Preflight**:
   - Execute `curl -i -X OPTIONS "https://api-aquaflow.gladwindr.me/api/v1/auth/login" -H "Origin: http://localhost:3000" -H "Access-Control-Request-Headers: Content-Type,Accept,X-Client"` and verify `Access-Control-Allow-Headers` includes `X-Client`.
4. **Rebuild & Refresh Frontend**:
   - Run `flutter clean && flutter run -d chrome --web-port=3000`.
   - In Chrome, perform Hard Reload (`Ctrl + Shift + R`).
5. **End-to-End Validation**:
   - Log in with `Gladwin` / `password123`.
   - Confirm immediate transition to Dashboard without "Unable to reach ArvaCore API" error banner.
   - Confirm pending ArvaNode `NODE-C3E8` is visible in the pairing modal.

---

## 8. Acceptance Criteria

- [ ] Browser `OPTIONS` preflight for `X-Client` returns HTTP 200 with `Access-Control-Allow-Headers: ...X-Client...`.
- [ ] Login completes smoothly from the browser without network abort.
- [ ] Dashboard displays field zones and telemetry without 500 error cascade.
- [ ] Hardware pairing requests for `NODE-C3E8` appear in the pairing list.

