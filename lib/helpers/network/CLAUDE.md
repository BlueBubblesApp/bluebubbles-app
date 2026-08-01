# helpers/network/ — Network Utility Functions

Pure helpers for network operations. No UI dependencies.

## File Routing

| File | What's inside |
|------|---------------|
| `network_helpers.dart` | `sanitizeServerAddress(url)` — validates and normalizes server URLs (detects ngrok/Cloudflare tunnels, ensures correct scheme); `getOrCreateUniqueId()` — persistent install ID; `getDeviceName()` — device name for server registration |
| `network_error_handler.dart` | `handleSendError(error, message)` — classifies `DioException`/HTTP errors into timeout vs. connection failure, updates `message.guid` with error prefix for UI display |
| `metadata_helper.dart` | `MetadataHelper` — public entry point for URL preview metadata. Thin facade over `metadata/` |
| `metadata/` | The URL preview metadata pipeline → `metadata/CLAUDE.md` |
| `network_tasks.dart` | `onConnect()` — called when network becomes available; triggers localhost detection, incremental sync, and socket reconnection |

## Key Usage Notes

**Server URL normalization** — always pass user-entered server addresses through `sanitizeServerAddress()` before storing or connecting. It handles missing schemes, trailing slashes, and known tunnel providers.

**Send error classification** — in error handlers for outgoing messages, use `handleSendError()` rather than inspecting `DioException` directly. It returns an updated `Message` with the correct error code set and the GUID prefixed with `"error-"` so the UI shows the failure state.

**URL preview metadata** — call `MetadataHelper.fetchForMessage(message)` (or `fetchForUrl(url)`). It returns a `MetadataFetchResult`, never throws, and dedupes concurrent calls for the same URL. Persist and read cached results through `MessageMetadataStore`, never by touching `message.metadata` keys directly. See `metadata/CLAUDE.md`.

**Never use `HttpSvc.dio` for third-party URLs.** It carries the user's `customHeaders` (server auth secrets) as defaults and an interceptor that converts HTTP errors into fake successes. `metadata/network/metadata_http_client.dart` exists for outbound requests to sites the user did not configure.

**Network reconnect** — `onConnect()` in `network_tasks.dart` is the entry point wired to connectivity change events. Don't call sync or socket logic directly from connectivity listeners; call `onConnect()` instead.
