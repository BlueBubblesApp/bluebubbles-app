#ifndef RUNNER_SPLASH_SCREEN_H_
#define RUNNER_SPLASH_SCREEN_H_

#include <gtk/gtk.h>

// In-window splash (logo, version, spinner, status) overlaid on top of the
// FlView while the Flutter engine and app services initialize. GTK/Cairo
// counterpart of windows/runner/splash_screen.cpp.
//
// Unlike a separate top-level window, this lives inside the main window as a
// GtkOverlay child, which matters on Linux: a software-GL FlView only paints
// after its window is mapped, and a separate splash can't reliably stay above
// the main window (compositors ignore keep-above on Wayland/WSLg). By mapping
// the main window early with this opaque overlay on top, Flutter rasterizes its
// first frame underneath during startup; the overlay is removed (on
// closeSplash) only once that content is ready — so there's no empty-window
// flash and nothing to be covered.

// Creates the splash drawing-area widget and starts the spinner animation. The
// caller adds it as an overlay over the FlView. Returns the widget (owned by
// the overlay it is added to).
GtkWidget* create_splash_widget();

// Updates the status line. Called on the GTK main thread from the
// `bluebubbles/splash` method-channel handler in my_application.cc.
void set_splash_status(const char* status);

// Stops the spinner and destroys the splash widget, removing it from its
// overlay and revealing the FlView. Safe to call multiple times.
void close_splash_screen();

// Whether the splash chose its dark palette (honors the GTK prefer-dark
// setting, else sniffs the theme name). The runner uses this to clear the
// FlView to a matching color as a fallback.
bool splash_is_dark_mode();

#endif  // RUNNER_SPLASH_SCREEN_H_
