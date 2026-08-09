#include "splash_screen.h"

#include <appmodel.h>
#include <dwmapi.h>
#include <flutter_windows.h>
#include <winver.h>

#include <algorithm>
#include <atomic>
#include <mutex>
#include <string>
#include <vector>

// Rounded-corner support (Windows 11); redefined in case the SDK is older.
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWCP_ROUND
#define DWMWCP_ROUND 2
#endif

// gdiplus.h depends on the min/max macros, which the build disables via
// NOMINMAX. Inject std::min/std::max into the Gdiplus namespace before the
// header so it compiles.
namespace Gdiplus {
using std::max;
using std::min;
}  // namespace Gdiplus
#include <gdiplus.h>

#include "resource.h"

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "version.lib")

namespace {

constexpr wchar_t kSplashClassName[] = L"BlueBubblesSplashWindow";

// Logical (96-DPI) layout; scaled per-monitor. 4:3 window (360x480) matching the
// Linux splash. Content tops are within a kContentH-tall box that is centered
// vertically in the window (see oy in Paint), so a window resize only touches
// kWindowW/kWindowH.
constexpr int kWindowW = 360;
constexpr int kWindowH = 480;
constexpr int kContentH = 300;
constexpr int kIcon = 72;
constexpr int kIconTop = 40;
constexpr int kVersionTop = 124;
constexpr int kVersionHeight = 18;
constexpr int kSpinnerTop = 168;
constexpr int kSpinner = 26;
constexpr int kSpinnerStroke = 3;
constexpr int kStatusTop = 224;
constexpr int kStatusHeight = 40;
constexpr int kVersionFont = 12;
constexpr int kStatusFont = 12;

constexpr UINT_PTR kTimerId = 1;
constexpr UINT WM_SPLASH_STATUS = WM_APP + 1;

std::atomic<HWND> g_splash_hwnd{nullptr};
HANDLE g_splash_thread = nullptr;
HICON g_splash_icon = nullptr;
HINSTANCE g_instance = nullptr;
ULONG_PTR g_gdiplus_token = 0;
COLORREF g_bg_color = RGB(28, 28, 30);
bool g_dark = true;
double g_scale = 1.0;
int g_angle = 0;

std::mutex g_status_mutex;
std::wstring g_status = L"Starting...";

// "v<file-version>" plus " (MSIX)" only when packaged — built in ShowSplashScreen.
std::wstring g_version_line;

// Matches the system "apps use light theme" preference.
bool IsDarkMode() {
  DWORD value = 1;
  DWORD size = sizeof(value);
  HKEY key;
  if (RegOpenKeyExW(HKEY_CURRENT_USER,
                    L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                    0, KEY_READ, &key) == ERROR_SUCCESS) {
    RegQueryValueExW(key, L"AppsUseLightTheme", nullptr, nullptr,
                     reinterpret_cast<LPBYTE>(&value), &size);
    RegCloseKey(key);
  }
  return value == 0;  // 0 => dark
}

// Reads the FileVersion embedded in the running exe (windows/runner/Runner.rc),
// which is the authoritative version for the binary (e.g. "1.15.102.0").
std::wstring ExeFileVersion() {
  wchar_t path[MAX_PATH];
  if (GetModuleFileNameW(nullptr, path, MAX_PATH) == 0) return L"";
  DWORD handle = 0;
  DWORD size = GetFileVersionInfoSizeW(path, &handle);
  if (size == 0) return L"";
  std::vector<BYTE> data(size);
  if (!GetFileVersionInfoW(path, handle, size, data.data())) return L"";
  VS_FIXEDFILEINFO* info = nullptr;
  UINT len = 0;
  if (!VerQueryValueW(data.data(), L"\\", reinterpret_cast<LPVOID*>(&info), &len) || info == nullptr) {
    return L"";
  }
  return std::to_wstring(HIWORD(info->dwFileVersionMS)) + L"." +
         std::to_wstring(LOWORD(info->dwFileVersionMS)) + L"." +
         std::to_wstring(HIWORD(info->dwFileVersionLS)) + L"." +
         std::to_wstring(LOWORD(info->dwFileVersionLS));
}

// True when running from an MSIX package (has package identity).
bool IsMsix() {
  UINT32 length = 0;
  return GetCurrentPackageFullName(&length, nullptr) != APPMODEL_ERROR_NO_PACKAGE;
}

std::wstring BuildVersionLine() {
  std::wstring version = ExeFileVersion();
  if (version.empty()) version = L"?";
  return L"v" + version + (IsMsix() ? L" (MSIX)" : L"");
}

int S(int logical) { return static_cast<int>(logical * g_scale); }

void DrawCenteredText(Gdiplus::Graphics& g, const std::wstring& text, int top, int height,
                      int font_size, BYTE alpha, int client_w) {
  BYTE channel = g_dark ? 255 : 0;
  Gdiplus::SolidBrush brush(Gdiplus::Color(alpha, channel, channel, channel));
  Gdiplus::FontFamily family(L"Segoe UI");
  Gdiplus::Font font(&family, static_cast<Gdiplus::REAL>(S(font_size)),
                     Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
  Gdiplus::StringFormat fmt;
  fmt.SetAlignment(Gdiplus::StringAlignmentCenter);
  fmt.SetLineAlignment(Gdiplus::StringAlignmentCenter);
  fmt.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
  fmt.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);
  Gdiplus::RectF rect(0, static_cast<Gdiplus::REAL>(S(top)),
                      static_cast<Gdiplus::REAL>(client_w),
                      static_cast<Gdiplus::REAL>(S(height)));
  g.DrawString(text.c_str(), -1, &font, rect, &fmt, &brush);
}

void Paint(HWND hwnd) {
  PAINTSTRUCT ps;
  HDC hdc = BeginPaint(hwnd, &ps);
  RECT rc;
  GetClientRect(hwnd, &rc);
  int w = rc.right;
  int h = rc.bottom;

  // Double-buffer so the spinner animation doesn't flicker.
  HDC mem = CreateCompatibleDC(hdc);
  HBITMAP bmp = CreateCompatibleBitmap(hdc, w, h);
  HBITMAP old_bmp = static_cast<HBITMAP>(SelectObject(mem, bmp));

  HBRUSH bg = CreateSolidBrush(g_bg_color);
  FillRect(mem, &rc, bg);
  DeleteObject(bg);

  // Center the content box vertically within the window (matches Linux's oy).
  int oy = (kWindowH - kContentH) / 2;

  if (g_splash_icon) {
    int icon = S(kIcon);
    DrawIconEx(mem, (w - icon) / 2, S(kIconTop + oy), g_splash_icon, icon, icon, 0, nullptr, DI_NORMAL);
  }

  std::wstring status;
  {
    std::lock_guard<std::mutex> lock(g_status_mutex);
    status = g_status;
  }

  {
    Gdiplus::Graphics g(mem);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

    DrawCenteredText(g, g_version_line, kVersionTop + oy, kVersionHeight, kVersionFont, 120, w);
    DrawCenteredText(g, status, kStatusTop + oy, kStatusHeight, kStatusFont, 165, w);

    // Rotating arc spinner in the BlueBubbles brand blue.
    Gdiplus::Pen pen(Gdiplus::Color(255, 25, 130, 252), static_cast<Gdiplus::REAL>(S(kSpinnerStroke)));
    pen.SetStartCap(Gdiplus::LineCapRound);
    pen.SetEndCap(Gdiplus::LineCapRound);
    int spin = S(kSpinner);
    g.DrawArc(&pen, (w - spin) / 2, S(kSpinnerTop + oy), spin, spin,
              static_cast<Gdiplus::REAL>(g_angle), 270.0f);
  }

  BitBlt(hdc, 0, 0, w, h, mem, 0, 0, SRCCOPY);
  SelectObject(mem, old_bmp);
  DeleteObject(bmp);
  DeleteDC(mem);
  EndPaint(hwnd, &ps);
}

LRESULT CALLBACK SplashWndProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_TIMER:
      g_angle = (g_angle + 12) % 360;
      InvalidateRect(hwnd, nullptr, FALSE);
      return 0;
    case WM_SPLASH_STATUS:
      InvalidateRect(hwnd, nullptr, FALSE);
      return 0;
    case WM_PAINT:
      Paint(hwnd);
      return 0;
    case WM_DESTROY:
      KillTimer(hwnd, kTimerId);
      PostQuitMessage(0);
      return 0;
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

// Runs the splash window on its own thread with its own message loop so the
// spinner keeps animating while the main thread blocks initializing Flutter.
DWORD WINAPI SplashThreadProc(LPVOID) {
  Gdiplus::GdiplusStartupInput startup_input;
  Gdiplus::GdiplusStartup(&g_gdiplus_token, &startup_input, nullptr);

  WNDCLASSW wc = {};
  wc.style = CS_DROPSHADOW;  // elevation/drop shadow for the borderless window
  wc.lpfnWndProc = SplashWndProc;
  wc.hInstance = g_instance;
  wc.lpszClassName = kSplashClassName;
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  RegisterClassW(&wc);

  POINT cursor;
  GetCursorPos(&cursor);
  HMONITOR monitor = MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  if (dpi < 48) dpi = 96;  // guard against early/garbage values -> 0-size window
  g_scale = dpi / 96.0;
  int win_w = S(kWindowW);
  int win_h = S(kWindowH);

  MONITORINFO mi = {sizeof(MONITORINFO)};
  GetMonitorInfo(monitor, &mi);
  int x = mi.rcWork.left + (mi.rcWork.right - mi.rcWork.left - win_w) / 2;
  int y = mi.rcWork.top + (mi.rcWork.bottom - mi.rcWork.top - win_h) / 2;

  int icon_px = S(kIcon);
  g_splash_icon = static_cast<HICON>(LoadImage(g_instance, MAKEINTRESOURCE(IDI_APP_ICON),
                                               IMAGE_ICON, icon_px, icon_px, LR_DEFAULTCOLOR));

  HWND hwnd = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_TOPMOST, kSplashClassName, L"BlueBubbles",
                              WS_POPUP, x, y, win_w, win_h, nullptr, nullptr, g_instance, nullptr);
  g_splash_hwnd = hwnd;
  if (!hwnd) {
    if (g_splash_icon) {
      DestroyIcon(g_splash_icon);
      g_splash_icon = nullptr;
    }
    Gdiplus::GdiplusShutdown(g_gdiplus_token);
    return 0;
  }

  // Rounded corners (Windows 11; no-op on older Windows).
  DWORD corner = DWMWCP_ROUND;
  DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner, sizeof(corner));

  ShowWindow(hwnd, SW_SHOW);
  UpdateWindow(hwnd);
  SetTimer(hwnd, kTimerId, 30, nullptr);

  MSG msg;
  while (GetMessage(&msg, nullptr, 0, 0)) {
    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }

  if (g_splash_icon) {
    DestroyIcon(g_splash_icon);
    g_splash_icon = nullptr;
  }
  Gdiplus::GdiplusShutdown(g_gdiplus_token);
  g_splash_hwnd = nullptr;
  return 0;
}

}  // namespace

void ShowSplashScreen(HINSTANCE instance) {
  if (g_splash_thread) {
    return;
  }
  g_instance = instance;
  g_dark = IsDarkMode();
  g_bg_color = g_dark ? RGB(28, 28, 30) : RGB(255, 255, 255);
  g_version_line = BuildVersionLine();
  g_splash_thread = CreateThread(nullptr, 0, SplashThreadProc, nullptr, 0, nullptr);
}

void SetSplashStatus(const std::wstring& status) {
  {
    std::lock_guard<std::mutex> lock(g_status_mutex);
    g_status = status;
  }
  HWND hwnd = g_splash_hwnd;
  if (hwnd) {
    PostMessageW(hwnd, WM_SPLASH_STATUS, 0, 0);
  }
}

void CloseSplashScreen() {
  HWND hwnd = g_splash_hwnd;
  if (hwnd) {
    // The window lives on the splash thread; ask it to close itself.
    PostMessageW(hwnd, WM_CLOSE, 0, 0);
  }
  if (g_splash_thread) {
    WaitForSingleObject(g_splash_thread, 2000);
    CloseHandle(g_splash_thread);
    g_splash_thread = nullptr;
  }
}
