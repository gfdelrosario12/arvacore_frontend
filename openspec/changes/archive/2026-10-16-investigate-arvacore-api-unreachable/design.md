# Design: Resolution of "Unable to reach ArvaCore API"

## Context

The Flutter web client transmits a custom client identification header (`X-Client: aquasense-mobile`) with all outgoing API requests. Modern browsers strictly enforce CORS preflight verification (`OPTIONS` requests) when custom headers are attached.

Because `SecurityConfig.java` previously allowed only a restricted subset of headers and omitted `X-Client`, browser runtimes aborted authentication attempts before HTTP payloads were delivered, resulting in generic `ClientException` connectivity failures.

## Design Decisions

1. **Backend CORS Whitelisting**:
   - Explicitly configure `CorsConfiguration` in `SecurityConfig.java` to allow `X-Client`, `Authorization`, `Content-Type`, `Accept`, `X-Correlation-ID`, `X-Webhook-Secret`, and `X-Downlink-Secret`.
   - Ensure preflight `OPTIONS` requests receive HTTP 200 with matching `Access-Control-Allow-Headers`.

2. **Backend Route Resilience**:
   - Expose `@GetMapping("/status")` under `IrrigationController` to satisfy dashboard polling without throwing 500 errors.

3. **Frontend Diagnostics & Error Handling**:
   - Refactor `ApiClient._send` to propagate detailed error diagnostics rather than blanket "Unable to reach ArvaCore API" messages.
   - Decouple dashboard data fetching in `HomeScreen` and `FieldScreen` so failures in optional actuators do not prevent rendering telemetry and node discovery.
