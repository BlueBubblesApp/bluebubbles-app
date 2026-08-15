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
- `background_isolate.dart` — background Dart execution

## Build Config
- Compile/Target SDK: 36 | Min SDK: 26 | NDK: 28.2 | Java/Kotlin compat: version 21
- Gradle with Kotlin plugin

Targeting API 36 means Android 16 behavior changes apply: edge-to-edge is mandatory
(no opt-out), predictive back is on by default, and on `sw600dp`+ screens the system
ignores orientation/resizability restrictions — including
`SystemChrome.setPreferredOrientations` from Dart.
