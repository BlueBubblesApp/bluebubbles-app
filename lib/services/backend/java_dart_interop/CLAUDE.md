# services/backend/java_dart_interop/ — Dart ↔ Android Bridge

Four files that form the Dart side of the Android bridge. The Kotlin side lives in `android/app/src/main/kotlin/com/bluebubbles/messaging/`.

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

### `voice_command_service.dart` — `VoiceCommandService` / `VoiceCommandSvc`

GetIt singleton. Turns Google Assistant / Gemini "send a message" commands into a real send.

`VoiceCommandRequest.parse(data, extras)` recognises a voice launch — either the
`bluebubbles://voice/send-message?...` deep link or a capability-bound conversation shortcut —
and returns null for everything else. `IntentsService` calls it before its own action switch.

`handleRequest` waits for the UI, resolves the spoken recipient against existing chats
(`rankChats` / `scoreChat`), asks the user to confirm unless `voiceCommandAutoSend` is on, then
queues through `OutgoingMsgHandler`. **Existing chats only** — an unmatched recipient is an
error, never a new chat.

Registered in `StartupTasks` *before* `IntentsService`, since `IntentsSvc.init()` replays the
launch intent and resolves `VoiceCommandSvc` synchronously.

Full walkthrough, including the Android-side declarations and `adb` test commands:
`docs/VOICE_COMMANDS.md`.

---

### `background_isolate.dart`

Minimal setup for the Android background isolate (used when the app is killed but a Firebase push arrives). Stores a callback handle to `SharedPreferences` and defines the `@pragma('vm:entry-point')` entry point that initializes HTTP overrides and calls `StartupTasks.initBackgroundIsolate()`.

This is distinct from `GlobalIsolate` (see `lib/services/isolates/CLAUDE.md`) — it's the Android-specific background execution path, not the in-process Dart isolate used for DB operations.
