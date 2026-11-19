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

## SharedPreferences and multiple Flutter engines

`services/backend_ui_interop/SharedPreferencesEnginePlugin.kt` shares one upstream
SharedPreferences plugin across activity, bubble, and worker engines, unregistering only
when the final engine detaches. Version 2.5.x otherwise clears its process-wide JNI
registrars whenever any engine detaches. DartWorker registers the wrapper directly.
`app/build.gradle` compiles a transformed copy of Flutter's generated registrant so all
automatically registered engines use the wrapper too; it does not modify generated or
plugin source files. Revisit this workaround when the upstream registration lifecycle changes.

## The bubble's engine is kept between bubbles

`BubbleActivity` keeps one engine in `FlutterEngineCache` and hands it to the next bubble, so
a bubble opened after the first skips the `bubble` entrypoint's startup. Only one activity
draws on it at a time: a bubble opened while another still exists starts its own engine,
destroyed with it. A closing bubble gives the engine up in `onPause`, because `onDestroy`
comes after the next activity has drawn. Don't return it from `provideFlutterEngine`: the
embedding destroys a provided engine with the first bubble. Dart closes and leaves the chat when
the lifecycle reaches `detached` (`IntentsService.leaveBubbleChat`): it closes Settings/Find My, pops the
chat pane's nested navigator (where chats live, phones included) and then the root, so the next bubble
starts on the chat list and opens its chat from the intent. Closing matters, not just popping: the next
intent arrives on the stream path, where `openChat` skips a chat that is still active. When the
activity lets go of the kept engine (`cleanUpFlutterEngine`), it re-registers the method channel
with the application context so the idle engine doesn't keep the destroyed activity alive.

The kept engine is destroyed when Android asks for memory back (`onTrimMemory` at
`TRIM_MEMORY_BACKGROUND` or worse, the pre-Android 14 `RUNNING_LOW`/`RUNNING_CRITICAL`, or
`onLowMemory`), or after it has sat 10 minutes with no bubble attached (`KEPT_ENGINE_IDLE_TIMEOUT_MS`,
a main-thread `Handler` cancelled when a bubble attaches; keepAppAlive's foreground service can keep
those trim levels from ever arriving). Either way only while no activity is attached to it; the next
bubble then starts cold, as every bubble did before the engine was kept. `TRIM_MEMORY_UI_HIDDEN` is
deliberately ignored: it fires whenever a closed bubble was the only thing on screen. While it idles,
Dart has already purged its rebuildable caches (`LifecycleService.closeBubble`).

## Build Config

- Compile SDK: 37 (permission_handler_android 14 needs it) | Target SDK: 36 | Min SDK: 26 | NDK: 28.2 | Java/Kotlin compat: version 21
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
  slips through (`file_picker` 11.x did; its 13.x Android package, `android_file_picker`,
  checks `builtInKotlin` itself). If a plugin fails with "cannot find symbol" on its Kotlin
  classes, apply KGP to it from the root `build.gradle`.
- **Kotlin language floor:** KGP 2.4 rejects `languageVersion` below 2.0. No current plugin
  pins one (`unifiedpush_android` did, and is gone); if one comes back, force 2.0 on it
  from the root `build.gradle`.
- **Native libs:** AGP 9 rejects `android:extractNativeLibs` in the manifest, so packaging is
  set in `app/build.gradle`, per flavor. Sideloaded APKs (`prod` on GitHub releases, alpha,
  beta) keep libs compressed so the download stays small. The Play bundle (`prodNoAa`)
  stores them uncompressed: Play compresses in transit anyway, and devices skip extraction.
  This is keyed on flavor because one variant produces both APKs and bundles.
- **Gradle vs AGP:** AGP 8.x can't run on Gradle 9.6+ (Gradle removed
  `org.gradle.api.problems.internal.InternalProblems`), so never downgrade AGP without
  also dropping Gradle to 9.5.
