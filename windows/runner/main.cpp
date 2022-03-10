#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>
auto bdw = bitsdojo_window_configure(BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP);

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  LPCWSTR szTitle = L"BlueBubbles";
  LPCWSTR szWindowClass = L"FLUTTER_RUNNER_WIN32_WINDOW";

  HANDLE hMutex = OpenMutex(MUTEX_ALL_ACCESS, 0, szTitle);

  if (!hMutex) {
      // Mutex doesn't exist. This is
      // the first instance so create
      // the mutex.
      hMutex = CreateMutex(0, 0, szTitle);
  } else {
      // The mutex exists so this is the
      // the second instance so return.

      // Find the window of First Instance
      HWND hwnd = FindWindow(szWindowClass,szTitle);

      // Display the window of First Instance
      ShowWindow(hwnd,SW_SHOWNORMAL);
      SetForegroundWindow(hwnd);

      return 0; // Exit Second instance
  }

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
if (!window.CreateAndShow(L"BlueBubbles", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
