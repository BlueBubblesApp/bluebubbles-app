#ifndef RUNNER_SPLASH_SCREEN_H_
#define RUNNER_SPLASH_SCREEN_H_

#include <windows.h>

#include <string>

// Shows a small, centered native splash window displaying the app logo.
// Intended to be called once at startup, before the Flutter engine is
// initialized, so the user sees something the instant the process launches.
void ShowSplashScreen(HINSTANCE instance);

// Updates the status line shown beneath the spinner. Safe to call from the
// platform (UI) thread; the splash repaints on its own thread.
void SetSplashStatus(const std::wstring& status);

// Closes the native splash window if it is open. Safe to call multiple times
// and from the platform (UI) thread once Flutter has shown its own window.
void CloseSplashScreen();

#endif  // RUNNER_SPLASH_SCREEN_H_
