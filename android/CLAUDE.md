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
- Gradle 9.8.0 | AGP 9.4.1 | KGP 2.4.20 | Gradle with Kotlin plugin

Targeting API 36 means Android 16 behavior changes apply: edge-to-edge is mandatory
(no opt-out), predictive back is on by default, and on `sw600dp`+ screens the system
ignores orientation/resizability restrictions — including
`SystemChrome.setPreferredOrientations` from Dart.

### AGP 9 and Kotlin — don't flip `builtInKotlin` blindly

The build runs on AGP 9 with `android.builtInKotlin=false` and `android.newDsl=false` in
`gradle.properties`. Both opt-outs stop working in AGP 10.

- **Why `builtInKotlin=false`:** with it on, AGP 9 rejects every module that applies
  `kotlin-android`. That covers the app itself and ~30 plugins, which Flutter lists on each
  build ("Your app uses the following plugins that apply Kotlin Gradle Plugin"). Turn it on
  only when that list is empty, then remove `kotlin-android` from `app/build.gradle` and
  the KGP entry from `settings.gradle`.
- **Plugins that skip KGP on AGP 9:** Flutter (3.47+) applies `kotlin-android` to any plugin
  that doesn't, so it has to stay declared in `settings.gradle`. Flutter detects that by
  text-matching each plugin's build file, so a plugin that applies KGP only behind an `if`
  slips through. `file_picker` 11.x does this; the root `build.gradle` applies KGP to it
  directly and sets its Kotlin `jvmTarget`. Without that, the app fails with
  `FilePickerPlugin` "cannot find symbol".
- **Kotlin language floor:** KGP 2.4 rejects `languageVersion` below 2.0, so the root
  `build.gradle` forces 2.0 on all modules (some plugins pin 1.7/1.8).
- **Native libs:** AGP 9 rejects `android:extractNativeLibs` in the manifest, so packaging is
  set in `app/build.gradle`, per flavor. Sideloaded APKs (`prod` on GitHub releases, alpha,
  beta) keep libs compressed so the download stays small. The Play bundle (`prodNoAa`)
  stores them uncompressed: Play compresses in transit anyway, and devices skip extraction.
  This is keyed on flavor because one variant produces both APKs and bundles.
- **Gradle vs AGP:** AGP 8.x can't run on Gradle 9.6+ (Gradle removed
  `org.gradle.api.problems.internal.InternalProblems`), so never downgrade AGP without
  also dropping Gradle to 9.5.
