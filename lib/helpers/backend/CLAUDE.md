# helpers/backend/ — Backend Bootstrap & Service Helpers

## File Routing

| File | What's inside |
|------|---------------|
| `startup_tasks.dart` | `StartupTasks` — ordered service initialization; the single source of truth for startup sequence |
| `settings_helpers.dart` | `saveNewServerUrl()`, `clearServerUrl()`, `disableBatteryOptimizations()` — convenience wrappers for common settings mutations |
| `foreground_service_helpers.dart` | `runForegroundService()`, `restartForegroundService()` — Android foreground service control via method channel |

---

## `startup_tasks.dart` — Service Init Order

`StartupTasks.initStartupServices()` registers services in strict dependency order using `GetIt.registerSingletonAsync()`. The order matters — each service may depend on those registered before it.

**Startup sequence (abbreviated):**
1. `FilesystemService`
2. `SharedPreferencesService` (`PrefsSvc`)
3. `SettingsService` + Logger
4. Database (ObjectBox)
5. `GlobalIsolate` + `IncrementalSyncIsolate`
6. `HttpService`, `MethodChannelService`, `LifecycleService` (in parallel)
7. `ContactServiceV2`, `ChatsService`, `SocketService`, `NotificationsService`
8. `EventDispatcher`

If adding a new service, place it in this file at the correct position in the dependency chain. Do not register services ad-hoc elsewhere.

**Isolate-specific init sequences** (subset of full startup):
- `StartupTasks.initGlobalIsolateServices()` — services available inside `GlobalIsolate`
- `StartupTasks.initSyncIsolateServices()` — lighter set for `IncrementalSyncIsolate`
- `StartupTasks.initBackgroundIsolate()` — Android background wake-up path

---

## `settings_helpers.dart`

`saveNewServerUrl(url)` — validates the URL via `sanitizeServerAddress()`, persists it, optionally restarts the socket and Android foreground service. Use this instead of writing `serverAddress` directly.

`clearServerUrl()` / `disableBatteryOptimizations()` — remaining convenience wrappers in this file.

---

## `foreground_service_helpers.dart`

Android-only. Starts or stops the foreground service that keeps the socket alive when the app is backgrounded.

`runForegroundService()` — starts if `keepAppAlive` is enabled, stops otherwise.
`restartForegroundService()` — performs a stop→start cycle; used after a server URL change.

Both call `MethodChannelSvc.invokeMethod(...)` under the hood. Guard with `Platform.isAndroid` before calling on other platforms.
