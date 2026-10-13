#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <chrono>
#include <cstdio>
#include <string>
#include <unordered_map>

#include "flutter_window.h"
#include "splash_screen.h"
#include "utils.h"

#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>
auto bdw = bitsdojo_window_configure(BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP);

namespace {

// Diagnoses intermittent typing lag from the platform thread, which sees keys before Flutter does:
//  - queue: how long a keyboard message waited in the queue (msg.time is when Windows queued it)
//  - key->char: first WM_KEYDOWN to its WM_CHAR. The embedder holds the char until Flutter answers the key
//    and re-sends it, so this covers the whole framework round trip.
//  - dispatch: any message (including engine/plugin tasks) whose handling blocked the loop.
// Reports at most one summary per second, and only when something crossed a threshold.
class InputLagMonitor {
 public:
  explicit InputLagMonitor(FlutterWindow& window) : window_(window) {}

  void BeforeDispatch(const MSG& msg) {
    const DWORD now = ::GetTickCount();
    const UINT m = msg.message;
    if (m < WM_KEYFIRST || m > WM_KEYLAST) return;

    const DWORD queued = now - msg.time;
    if (queued > max_queue_ms_) max_queue_ms_ = queued;

    const UINT scan = (msg.lParam >> 16) & 0x1FF;
    const bool repeat = (msg.lParam & (1 << 30)) != 0;
    if (m == WM_KEYDOWN && !repeat && ::MapVirtualKeyW(static_cast<UINT>(msg.wParam), MAPVK_VK_TO_CHAR) != 0 &&
        ::GetKeyState(VK_CONTROL) >= 0 && ::GetKeyState(VK_MENU) >= 0) {
      key_downs_++;
      pending_.try_emplace(scan, msg.time);
    } else if (m == WM_CHAR) {
      chars_++;
      auto it = pending_.find(scan);
      if (it != pending_.end()) {
        const DWORD latency = now - it->second;
        if (latency > max_key_to_char_ms_) max_key_to_char_ms_ = latency;
        pending_.erase(it);
      }
    }
  }

  void AfterDispatch(const MSG& msg, std::chrono::steady_clock::duration took) {
    const auto ms = static_cast<DWORD>(std::chrono::duration_cast<std::chrono::milliseconds>(took).count());
    // Title-bar drags, resizes and system menus run a modal loop inside one dispatch; that isn't a stall.
    const bool modal = msg.message == WM_NCLBUTTONDOWN || msg.message == WM_SYSCOMMAND ||
                       msg.message == WM_NCRBUTTONDOWN;
    if (!modal && ms > max_dispatch_ms_) {
      max_dispatch_ms_ = ms;
      max_dispatch_msg_ = msg.message;
      max_dispatch_hwnd_ = msg.hwnd;
    }
    MaybeReport();
  }

 private:
  static constexpr DWORD kQueueWarnMs = 100;
  static constexpr DWORD kKeyToCharWarnMs = 150;
  static constexpr DWORD kDispatchWarnMs = 50;

  void MaybeReport() {
    const DWORD now = ::GetTickCount();
    if (now - window_start_ < 1000) return;

    // Keys the framework consumed (shortcuts) never produce a char; age them out.
    DWORD oldest_pending = 0;
    for (auto it = pending_.begin(); it != pending_.end();) {
      const DWORD age = now - it->second;
      if (age > 10000) {
        it = pending_.erase(it);
      } else {
        if (age > oldest_pending) oldest_pending = age;
        ++it;
      }
    }

    const bool lagging = max_queue_ms_ >= kQueueWarnMs || max_key_to_char_ms_ >= kKeyToCharWarnMs ||
                         max_dispatch_ms_ >= kDispatchWarnMs || oldest_pending >= kKeyToCharWarnMs * 4;
    if (lagging) {
      char cls[64] = "";
      if (max_dispatch_hwnd_) ::GetClassNameA(max_dispatch_hwnd_, cls, sizeof(cls));
      char line[384];
      snprintf(line, sizeof(line),
               "max queue %lums, max key->char %lums, max dispatch %lums (msg 0x%04X, %s), "
               "%d keydowns, %d chars, %zu keys awaiting char (oldest %lums)",
               max_queue_ms_, max_key_to_char_ms_, max_dispatch_ms_, max_dispatch_msg_, cls, key_downs_, chars_,
               pending_.size(), oldest_pending);
      window_.ReportDiagnostic(line);
    }

    window_start_ = now;
    max_queue_ms_ = max_key_to_char_ms_ = max_dispatch_ms_ = 0;
    max_dispatch_msg_ = 0;
    max_dispatch_hwnd_ = nullptr;
    key_downs_ = chars_ = 0;
  }

  FlutterWindow& window_;
  std::unordered_map<UINT, DWORD> pending_;  // scan code -> msg.time of its first unanswered WM_KEYDOWN
  DWORD window_start_ = ::GetTickCount();
  DWORD max_queue_ms_ = 0;
  DWORD max_key_to_char_ms_ = 0;
  DWORD max_dispatch_ms_ = 0;
  UINT max_dispatch_msg_ = 0;
  HWND max_dispatch_hwnd_ = nullptr;
  int key_downs_ = 0;
  int chars_ = 0;
};

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (std::wstring(command_line ? command_line : L"").find(L"minimized") == std::wstring::npos) {
    ShowSplashScreen(instance);
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"BlueBubbles", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  InputLagMonitor lag_monitor(window);
  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    lag_monitor.BeforeDispatch(msg);
    const auto dispatch_start = std::chrono::steady_clock::now();
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
    lag_monitor.AfterDispatch(msg, std::chrono::steady_clock::now() - dispatch_start);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
