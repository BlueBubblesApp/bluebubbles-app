# services/backend/lifecycle/ — App Lifecycle Service

## File
`lifecycle_service.dart` — `AppLifecycleService` (registered with GetIt)

## Responsibilities
- Listens to Flutter `AppLifecycleState` changes (resumed, paused, detached, inactive)
- On **resume**: reconnects socket, triggers incremental sync, refreshes contact sync state
- On **pause**: records last-active timestamp, optionally disconnects socket (configurable), drains the global isolate (Android), and purges rebuildable caches via `CacheSvc.onAppBackgrounded()` (mobile)
- On **memory pressure** (`didHaveMemoryPressure`): `CacheSvc.onMemoryPressure()` — aggressive purge unless the signal is the echo of an engine purge the cache service requested itself
- Drives the `isActive` flag on `ChatState` for the currently open conversation

## Usage
Initialized at startup via `StartupTasks`. Do not instantiate; access via `GetIt.I<AppLifecycleService>()` if needed.

## Related
- Socket reconnect: `lib/services/network/socket_service.dart`
- Incremental sync trigger: `lib/services/backend/sync/incremental_sync_manager.dart`
- Android foreground service: `lib/helpers/backend/foreground_service_helpers.dart`
