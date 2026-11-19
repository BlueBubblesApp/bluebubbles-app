# linux/ — Linux Native (Minimal Custom Code)

C++ code: `main.cc` + `my_application.cc/h` — standard GTK-based Flutter app wrapper. `splash_screen.cc/h` — native splash screen shown before the Flutter engine attaches.

## Runner Notes (`my_application.cc`)
- Exports an `app.quit` GAction so the desktop shell's "Quit" (e.g. GNOME's dock menu) really quits instead of closing the
  window, which Close to Tray would turn into a hide. The tray's "Close App" and the window close button quit from Dart
  with `exit(0)` instead (`lib/main.dart`), since the runner registers no channel to route a quit through.
- UI and platform threads stay merged (no `FL_UI_THREAD_POLICY_RUN_ON_SEPARATE_THREAD`): the tray (`tray_manager` 0.9 /
  nativeapi FFI) must run on the platform thread.
- Channel: `bluebubbles/splash` (`setStatus`, `setProgress`, `closeSplash`).

## Tray & Launcher Badge
- The tray icon is a StatusNotifierItem over D-Bus (`tray_manager` → nativeapi); no libayatana/libappindicator dependency.
- The unread badge is a Unity `LauncherEntry` D-Bus signal (`lib/utils/linux_launcher_badge.dart`). The Snap needs the
  `unity7` plug for it; a parallel Snap install's desktop ID is `bluebubbles+<key>_bluebubbles.desktop`.

## Distribution Packages (project root)
- `flatpak/` — Flatpak package (`app.bluebubbles.BlueBubbles`)
- `snap/` — Snap package (`snapcraft.yaml`); core24 base, amd64/arm64, GNOME extension

## Notable Dependencies
- `desktop_webview_auth` — WebKit2GTK 4.1 (custom fork) for OAuth WebView
- ALSA audio support configured via snap layout
- Snap plugs: network, network-manager, camera, desktop, desktop-legacy, wayland, x11, unity7, opengl, alsa, audio-playback, audio-record (no `home`)

## Flutter-Side Linux Code
- `lib/utils/window_effects.dart` — window transparency (limited on Linux)
- `lib/app/wrappers/titlebar_wrapper.dart` — custom titlebar
