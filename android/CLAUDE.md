# android/ — Android Native (Kotlin)

Source: `app/src/main/kotlin/com/bluebubbles/messaging/`

## Key Modules
| Directory | Purpose |
|-----------|---------|
| `services/foreground/` | Foreground service to keep socket alive |
| `services/firebase/` | FCM push notifications and Firebase auth |
| `services/notifications/` | Notification channels, message/FaceTime builders |
| `services/intents/` | Intent receivers (deep links, auto-start) |
| `services/system/` | Calendar, contacts, browser, Chrome OS integrations |
| `services/network/` | Native HTTP service |
| `services/backend_ui_interop/` | DartWorkManager / DartWorker for background Dart |
| `services/filesystem/` | File path resolution |

## Dart ↔ Android Bridge
Flutter side: `lib/services/backend/java_dart_interop/`
- `method_channel_service.dart` — channel setup
- `intents_service.dart` — Android intent handling
- `voice_command_service.dart` — Assistant/Gemini "send a message" commands
- `background_isolate.dart` — background Dart execution

## Voice Commands (App Actions)
`res/xml/shortcuts.xml` declares the `actions.intent.SEND_MESSAGE` /
`actions.intent.CREATE_MESSAGE` capabilities that back "Hey Google, send a
BlueBubbles message to ...". Fulfillment is a `bluebubbles://voice/...` deep link
claimed by `MainActivity`; `PushShareTargetsHandler` additionally binds each
donated conversation shortcut to those capabilities so assistants can ground
spoken names. Full walkthrough: `docs/VOICE_COMMANDS.md`.

## Build Config
- Target SDK: 35 | NDK: 27.0 | Java/Kotlin compat: version 21
- Gradle with Kotlin plugin
