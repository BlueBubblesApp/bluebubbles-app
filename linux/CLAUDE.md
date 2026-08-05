# linux/ — Linux Native (Minimal Custom Code)

C++ code: `main.cc` + `my_application.cc/h` — standard GTK-based Flutter app wrapper. `splash_screen.cc/h` — native splash screen shown before the Flutter engine attaches.

## Distribution Packages (project root)
- `flatpak/` — Flatpak package (`app.bluebubbles.BlueBubbles`)
- `snap/` — Snap package (`snapcraft.yaml`); core24 base, amd64/arm64, GNOME extension

## Notable Dependencies
- `desktop_webview_auth` — WebKit2GTK 4.1 (custom fork) for OAuth WebView
- ALSA audio support configured via snap layout
- GTK plugs: network, camera, desktop, wayland, x11, home, opengl

## Flutter-Side Linux Code
- `lib/utils/window_effects.dart` — window transparency (limited on Linux)
- `lib/app/wrappers/titlebar_wrapper.dart` — custom titlebar
