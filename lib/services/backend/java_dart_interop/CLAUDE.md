# services/backend/java_dart_interop/ — Dart ↔ Android Bridge

The Dart side of the Android method channel bridges. The Kotlin side lives in `android/app/src/main/kotlin/com/bluebubbles/messaging/`.

For the full Android bridge overview, see `android/CLAUDE.md`.

## Files

### `method_channel_service.dart` — `MethodChannelService` / `MethodChannelSvc`

GetIt singleton. The primary bridge between Dart and Android. Uses `MethodChannel('com.bluebubbles.messaging')`.

**Calling Android from Dart:**
```dart
await MethodChannelSvc.invokeMethod("method-name", {"key": "value"});
```

Key methods invoked:
- `"push-notify"` — trigger a local notification
- `"delete-notification"` — clear a notification by ID
- `"start-foreground"` / `"stop-foreground"` — foreground service control
- `"get-server-url"` — read server URL from Android SharedPreferences

**Android calling Dart:** The service also registers a `MethodCallHandler` to receive calls from Kotlin (e.g. handling an incoming notification tap, background wake-up).

**Guards:** Initialization is skipped in headless/bubble/desktop modes. Always check `MethodChannelSvc.isAvailable` before calling on non-Android platforms.

---

### `intents_service.dart` — `IntentsService`

Handles Android intents arriving at the Flutter layer (share targets, notification deep links, app shortcuts).

Listens to `ReceiveIntent.receivedIntentStream` and routes by action:
- Share intent → pre-fill the chat composer with shared content
- Notification tap → open the correct conversation
- Custom deep link → navigate to the specified screen

---

### `open_pigeon_service.dart` — `OpenPigeon`

Static class, Android only. Bridge to the third-party OpenPigeon app (`com.openbubbles.openpigeon`), a GamePigeon
client that plugs in as a Madrid extension. It has its own channel, `com.bluebubbles.messaging/openpigeon`, whose
Kotlin side is `services/extensions/OpenPigeonHost.kt`: a singleton that binds OpenPigeon's `MadridExtensionService`
over AIDL (`android/app/src/main/aidl/`) and hosts its game picker and bubble platform views. OpenPigeon draws games;
`OpenPigeon` sends the turns it produces through the v2 server's app-message route (`HttpSvc.message`), which needs Pro.

- Only `MainActivity` registers the host (one channel per process), so `offered` is false in a bubble and
  `OpenPigeon.init()` is skipped there (`StartupTasks`).
- `installed` is re-checked on resume (`refresh()`); `offered` / `supported` / `canDraw` gate the UI.
- Payloads, snapshots and opened sessions are small LRU caches (100 / 50 / 100 entries) for the life of the process.

---

### `background_isolate.dart`

Minimal setup for the Android background isolate (used when the app is killed but a Firebase push arrives). Stores a callback handle to `SharedPreferences` and defines the `@pragma('vm:entry-point')` entry point that initializes HTTP overrides and calls `StartupTasks.initBackgroundIsolate()`.

This is distinct from `GlobalIsolate` (see `lib/services/isolates/CLAUDE.md`) — it's the Android-specific background execution path, not the in-process Dart isolate used for DB operations.
