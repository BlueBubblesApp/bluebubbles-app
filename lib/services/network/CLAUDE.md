# services/network/ — Network Communication

## HTTP (`http_service.dart`)
Dio-based REST client. `HttpService` is the entrypoint — it holds core boilerplate and named
sub-service instances. Each sub-service lives in `api/` and handles one domain area → `api/CLAUDE.md`

**Sub-services (accessed via `HttpSvc.<sub-service>.<method>()`):**
| Property | Class | File | Key Methods |
|---|---|---|---|
| `server` | `ServerApi` | `api/server_api.dart` | `ping`, `lockMac`, `restartImessage`, `serverInfo`, `softRestart`, `hardRestart`, `checkUpdate`, `installUpdate`, `getTotalStats`, `getMediaStats`, `getLogs`, `landingPage` |
| `fcm` | `FcmApi` | `api/fcm_api.dart` | `addDevice`, `getServiceAccount` |
| `attachment` | `AttachmentApi` | `api/attachment_api.dart` | `fetch`, `download`, `downloadLivePhoto`, `downloadBlurhash`, `getCount` |
| `chat` | `ChatApi` | `api/chat_api.dart` | `query`, `getMessages`, `modifyParticipant`, `leave`, `setDisplayName`, `create`, `getCount`, `fetchOne`, `markRead`, `markUnread`, `getIcon`, `setIcon`, `removeIcon`, `delete`, `deleteMessage` |
| `message` | `MessageApi` | `api/message_api.dart` | `getCount`, `query`, `fetchOne`, `downloadEmbeddedMedia`, `sendText`, `sendAttachment`, `sendMultipart`, `sendTapback`, `unsend`, `edit`, `notify`, `getScheduled`, `createScheduled`, `updateScheduled`, `deleteScheduled` |
| `handle` | `HandleApi` | `api/handle_api.dart` | `handleCount`, `handles`, `handle`, `handleFocusState`, `handleiMessageState`, `handleFaceTimeState` |
| `contact` | `ContactApi` | `api/contact_api.dart` | `fetchAll`, `query`, `create` |
| `backup` | `BackupApi` | `api/backup_api.dart` | `getTheme`, `setTheme`, `deleteTheme`, `getSettings`, `setSettings`, `deleteSettings` |
| `faceTime` | `FaceTimeApi` | `api/facetime_api.dart` | `answer`, `leave` |
| `icloud` | `iCloudApi` | `api/icloud_api.dart` | `getDevices`, `refreshDevices`, `getFriends`, `refreshFriends`, `getAccountInfo`, `getAccountContact`, `setAccountAlias` |
| `firebase` | `FirebaseApi` | `api/firebase_api.dart` | `getFirebaseProjects`, `getGoogleInfo`, `getServerUrlRTDB`, `getServerUrlCF`, `setRestartDateCF` |

**Core utilities (on `HttpService` directly):**
- `runApiGuarded()` — wraps every call; handles retries on 502, propagates errors
- `buildQueryParams(map)` — injects auth GUID; call this on every request
- `returnSuccessOrError(response)` — validates status code
- `dio`, `origin`, `apiRoot`, `headers`, `originOverride` — request infrastructure
- `downloadFromUrl()`, `downloadAppleEmojiFont()` — utility downloads
- Timeouts configured globally from settings (`apiTimeout`); don't override per-request

**Adding a new endpoint:**
1. Find the right sub-service in `api/` (or add a new file for a new domain)
2. Add the method there, accepting `BaseApi _svc` calls for `dio`, `apiRoot`, etc.
3. Never add request methods directly to `HttpService`

See `.claude/rules/api.md` for full HTTP conventions.

## WebSocket (`socket_service.dart`)
socket_io_client connection to the BlueBubbles server. Don't create additional
`Socket` instances — one connection is managed here.

- State: `Rx<SocketState>` — `connected / disconnected / error / connecting / reconnecting`.
  `state` is the single source of truth; `handleStatusUpdate()` compares against it,
  so anything that changes the connection must write to it.
- **Three separate concerns, one owner each** (see ADR-014 in `docs/DECISIONS.md`):
  1. Retrying a transient failure → socket.io's own reconnect (unlimited attempts,
     backoff capped at 60s). **Never call `setReconnectionAttempts()`** — a finite cap
     makes socket.io stop permanently.
  2. Rebuilding the connection → `restartSocket()`, driven by `_runUrlDiscovery()`,
     a connectivity change, or an explicit config change. Only for things a `Manager`
     can't re-read at runtime: the URL, auth guid, headers.
  3. Staying down while backgrounded → `connectionDesired`, via
     `disconnect()` / `resumeConnection()`. Write it through `_setConnectionDesired()`.
- `enableForceNew()` is **required**. Without it `io()` returns the same cached
  `Socket`/`Manager`, pinned to the auth query and headers it was first built with.
- Restarts must clear Manager-level listeners (`onError`, `onReconnect*`) by hand —
  `Socket.dispose()` only clears socket-level ones. `_eventUnsubscribers` handles this.
- Every await in a discovery round is bounded by `_urlDiscoveryTimeout`, and the
  rebuild runs after the `finally`. Rediscovery is the only recovery from
  `_socketGaveUp`, so a wedged `_urlDiscoveryInProgress` disables it for the process.
- Connectivity changes (`Connectivity()` stream) drop a stale localhost origin
  override **and** rebuild (debounced) when the network returns — socket.io's backoff
  can be a minute out and `Socket.connect()` can't shorten it. On Windows an
  `InternetConnection` probe against the server drives this instead.
- A stale LAN override is re-probed by `_runUrlDiscovery()` via
  `NetworkTasks.detectLocalhost()`, not cleared by `saveNewServerUrl()`.
- Error logs are throttled per signature (`_errorLog`); a single-slot throttle would
  alternate between the differing payloads socket.io emits per failed attempt.
- On resume, `StartupTasks.onAppResume()` rebuilds the socket **before**
  `detectLocalhost()`, then again only if the resolved origin actually moved.

## TLS / Certificates
- `websocket_adapter.dart` — custom `HttpClientAdapter` for self-signed cert support
- `http_overrides.dart` — global `HttpOverrides` for certificate validation
- `user_certificates.dart` — user-added certificate management (Android native injection)

## Downloads (`downloads_service.dart`)
Attachment download state machine:
`queued → downloading → processing → complete / error`
- Concurrent download management
- EXIF extraction and format conversion post-download

## Firebase (`firebase/`) → `firebase/CLAUDE.md`
- `cloud_messaging_service.dart` — FCM device token registration (Android + Desktop)
- `firebase_database_service.dart` — Firebase Dart client setup for Desktop/Web; config fetching with fallback URLs
