# AquaSense API Boundary

Configure the API layer with build-time defines — never commit production secrets:

```bash
flutter run
```

| Define | Purpose |
|--------|---------|
| `ARVACORE_API_BASE_URL` | Backend base URL. Default: `https://api-aquaflow.gladwindr.me`. Production/staging **must** use `https:`. |
| `ARVACORE_ALLOW_INSECURE_HTTP` | Set `true` only for local/test HTTP. Default `false`; insecure URLs are rejected. |

`ApiClient` owns JSON headers, access-token attachment, timeout/error mapping, bounded GET retries, one-shot refresh replay, HTTPS enforcement, and redacted request diagnostics. TLS uses the **platform trust store** — there is no trust-all or certificate-bypass path.

API services decode endpoint responses into DTOs; repository adapters map DTOs into existing feature domain models.

Use `ApiRepositoryFactory` to share one configured client across resource services. Existing mock repositories remain valid for tests and offline development.

Irrigation commands are intentionally non-retryable and require `ENTIRE FIELD`. Q1-Q4 identifiers are valid only for monitoring queries. The mobile app has no LoRaWAN, radio, BLE, or direct gateway hardware transport.

## Account Audit API Endpoints

- `GET /api/audit/events`: Query paginated audit history filtered by category, actorId, targetType, targetId, and time range. Restrict read access to `fieldAdmin` role.
- `GET /api/audit/events/{id}`: Fetch full detail and metadata for a specific audit event.
- `POST /api/audit/events`: **Backend-only** emission endpoint. Enforces server-side tamper resistance; not exposed to mobile/frontend clients.

