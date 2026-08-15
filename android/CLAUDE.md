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
- Gradle 9.5.0 | AGP 8.11.1 | KGP 2.2.20 | Gradle with Kotlin plugin

Targeting API 36 means Android 16 behavior changes apply: edge-to-edge is mandatory
(no opt-out), predictive back is on by default, and on `sw600dp`+ screens the system
ignores orientation/resizability restrictions — including
`SystemChrome.setPreferredOrientations` from Dart.

### Version ceilings — don't bump these blindly

**Gradle is capped at 9.5.x.** Gradle 9.6.0 removed the internal API
`org.gradle.api.problems.internal.InternalProblems`, which AGP 8.x depends on. On Gradle
9.6+ the build fails at `apply plugin: 'com.android.application'`. Raising Gradle past 9.5
requires AGP 9 first.

**AGP is capped at 8.x until Flutter 3.47+.** AGP 9 has no workable configuration here:
- `android.builtInKotlin=false` — AGP-9-aware plugins break. `file_picker` (and others)
  deliberately skip applying KGP on AGP 9 and expect built-in Kotlin to compile their
  `.kt` sources; with it off, nothing does, and `FilePickerPlugin` fails to resolve.
- `android.builtInKotlin=true` — every plugin still applying `kotlin-android` breaks, since
  AGP 9 rejects that plugin. Flutter 3.44's Gradle plugin only *detects* those
  (`FlutterPluginUtils.detectApplyingKotlinGradlePlugin`) and tells you to report them
  upstream; the compatibility shim that actually allows KGP under AGP 9 lands in 3.47.

`android.newDsl=false` and `android.builtInKotlin=false` in `gradle.properties` are the
AGP 9 opt-outs, staged ahead of that move. Both stop working in AGP 10.
