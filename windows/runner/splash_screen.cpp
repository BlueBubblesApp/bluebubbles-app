#include "splash_screen.h"

#include <appmodel.h>
#include <dwmapi.h>
#include <flutter_windows.h>
#include <shellapi.h>
#include <windowsx.h>
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
#pragma comment(lib, "shell32.lib")
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
constexpr int kVersionFont = 12;

// Rolling log of startup steps: bottom-aligned, oldest dimmest. Grows downward
// into the space below the spinner — kContentH stays 300 so everything above it
// keeps its position.
constexpr int kLogTop = 216;
constexpr int kLogLines = 6;
constexpr int kLogLine = 15;
constexpr int kLogFont = 11;

// Close button, pinned to the top-right corner (not part of the centered box).
// Held back for a moment so a normal fast launch never flashes it.
constexpr int kCloseSize = 28;
constexpr int kCloseMargin = 6;
constexpr int kCloseGlyph = 10;
constexpr ULONGLONG kCloseDelayMs = 3000;

constexpr ULONGLONG kSlowMs = 10000;
constexpr int kSlowTop = 318;
constexpr int kSlowHeight = 18;
constexpr int kSlowFont = 11;
constexpr wchar_t kSlowLine1[] = L"Taking longer than usual?";
constexpr wchar_t kSlowLine2[] = L"Click here to report it.";
constexpr wchar_t kSlowUrl[] = L"https://github.com/BlueBubblesApp/bluebubbles-app/issues/new/choose";

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
bool g_close_hot = false;
bool g_url_hot = false;
ULONGLONG g_start_tick = 0;

// Bounds of the drawn issues-URL line, measured during Paint so the click and
// hover tests match exactly what is on screen. Empty while the line is hidden.
RECT g_url_rect = {};

std::mutex g_status_mutex;
std::vector<std::wstring> g_log_lines{L"Starting..."};

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

ULONGLONG ElapsedMs() { return GetTickCount64() - g_start_tick; }

RECT CloseButtonRect(int client_w) {
  int size = S(kCloseSize);
  int margin = S(kCloseMargin);
  return RECT{client_w - margin - size, margin, client_w - margin, margin + size};
}

// Draws the text and returns the bounds it actually occupies, for hit-testing.
Gdiplus::RectF DrawCenteredText(Gdiplus::Graphics& g, const std::wstring& text, int top, int height,
                                int font_size, BYTE alpha, int client_w, bool link = false) {
  BYTE channel = g_dark ? 255 : 0;
  // Links get the brand blue so they read as tappable; everything else is the
  // foreground color at some alpha.
  Gdiplus::SolidBrush brush(link ? Gdiplus::Color(alpha, 25, 130, 252)
                                 : Gdiplus::Color(alpha, channel, channel, channel));
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
  Gdiplus::RectF bounds;
  g.MeasureString(text.c_str(), -1, &font, rect, &fmt, &bounds);
  return bounds;
}

// What both the close button and Escape do, once the close button is showing.
// The user gave up, and the main thread is blocked inside engine init, so there
// is nothing to unwind gracefully — exit hard.
void Dismiss() { TerminateProcess(GetCurrentProcess(), 0); }

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

  std::vector<std::wstring> log;
  {
    std::lock_guard<std::mutex> lock(g_status_mutex);
    log = g_log_lines;
  }

  {
    Gdiplus::Graphics g(mem);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

    DrawCenteredText(g, g_version_line, kVersionTop + oy, kVersionHeight, kVersionFont, 120, w);

    // Bottom-aligned so the current step holds one spot and older ones stack
    // upward as they dim, rather than the live line crawling down the block.
    int count = static_cast<int>(log.size());
    for (int i = 0; i < count; i++) {
      int age = count - 1 - i;  // 0 == newest
      BYTE alpha = static_cast<BYTE>(200 - age * (200 - 70) / (kLogLines > 1 ? kLogLines - 1 : 1));
      int top = kLogTop + (kLogLines - count + i) * kLogLine;
      DrawCenteredText(g, log[i], top + oy, kLogLine, kLogFont, alpha, w);
    }

    // Rotating arc spinner in the BlueBubbles brand blue.
    Gdiplus::Pen pen(Gdiplus::Color(255, 25, 130, 252), static_cast<Gdiplus::REAL>(S(kSpinnerStroke)));
    pen.SetStartCap(Gdiplus::LineCapRound);
    pen.SetEndCap(Gdiplus::LineCapRound);
    int spin = S(kSpinner);
    g.DrawArc(&pen, (w - spin) / 2, S(kSpinnerTop + oy), spin, spin,
              static_cast<Gdiplus::REAL>(g_angle), 270.0f);

    ULONGLONG elapsed = ElapsedMs();
    BYTE channel = g_dark ? 255 : 0;

    if (elapsed >= kSlowMs) {
      DrawCenteredText(g, kSlowLine1, kSlowTop + oy, kSlowHeight, kSlowFont, 130, w);
      Gdiplus::RectF url = DrawCenteredText(g, kSlowLine2, kSlowTop + kSlowHeight + oy, kSlowHeight,
                                            kSlowFont, g_url_hot ? 255 : 205, w, true);
      g_url_rect = RECT{static_cast<LONG>(url.X), static_cast<LONG>(url.Y),
                        static_cast<LONG>(url.GetRight()), static_cast<LONG>(url.GetBottom())};
      InflateRect(&g_url_rect, S(4), S(3));
    } else {
      g_url_rect = RECT{};
    }

    // Close button "x", with a subtle disc behind it while hovered.
    if (elapsed >= kCloseDelayMs) {
      RECT cb = CloseButtonRect(w);
      if (g_close_hot) {
        Gdiplus::SolidBrush disc(Gdiplus::Color(38, channel, channel, channel));
        g.FillEllipse(&disc, cb.left, cb.top, cb.right - cb.left, cb.bottom - cb.top);
      }
      Gdiplus::Pen x_pen(Gdiplus::Color(g_close_hot ? 235 : 150, channel, channel, channel),
                         static_cast<Gdiplus::REAL>(std::max(1, S(2))));
      x_pen.SetStartCap(Gdiplus::LineCapRound);
      x_pen.SetEndCap(Gdiplus::LineCapRound);
      Gdiplus::REAL cx = (cb.left + cb.right) / 2.0f;
      Gdiplus::REAL cy = (cb.top + cb.bottom) / 2.0f;
      Gdiplus::REAL a = S(kCloseGlyph) / 2.0f;
      g.DrawLine(&x_pen, cx - a, cy - a, cx + a, cy + a);
      g.DrawLine(&x_pen, cx - a, cy + a, cx + a, cy - a);
    }
  }

  BitBlt(hdc, 0, 0, w, h, mem, 0, 0, SRCCOPY);
  SelectObject(mem, old_bmp);
  DeleteObject(bmp);
  DeleteDC(mem);
  EndPaint(hwnd, &ps);
}

LRESULT CALLBACK SplashWndProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_TIMER: {
      g_angle = (g_angle + 12) % 360;
      POINT pt;
      RECT rc;
      GetCursorPos(&pt);
      ScreenToClient(hwnd, &pt);
      GetClientRect(hwnd, &rc);
      RECT close = CloseButtonRect(rc.right);
      g_close_hot = ElapsedMs() >= kCloseDelayMs && PtInRect(&close, pt);
      g_url_hot = PtInRect(&g_url_rect, pt) != FALSE;
      InvalidateRect(hwnd, nullptr, FALSE);
      return 0;
    }
    case WM_SPLASH_STATUS:
      InvalidateRect(hwnd, nullptr, FALSE);
      return 0;
    case WM_PAINT:
      Paint(hwnd);
      return 0;
    case WM_LBUTTONDOWN: {
      RECT rc;
      GetClientRect(hwnd, &rc);
      RECT close = CloseButtonRect(rc.right);
      POINT pt{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      if (PtInRect(&g_url_rect, pt)) {
        ShellExecuteW(nullptr, L"open", kSlowUrl, nullptr, nullptr, SW_SHOWNORMAL);
      } else if (ElapsedMs() >= kCloseDelayMs && PtInRect(&close, pt)) {
        Dismiss();
      }
      return 0;
    }
    case WM_KEYDOWN:
      // Escape is the keyboard equivalent of the close button, held back by the
      // same delay — it is a topmost tool window with no titlebar or taskbar
      // entry, so the x must not be the only way out.
      if (wparam == VK_ESCAPE && ElapsedMs() >= kCloseDelayMs) Dismiss();
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
  g_start_tick = GetTickCount64();
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
    if (!g_log_lines.empty() && g_log_lines.back() == status) return;  // nothing changed
    g_log_lines.push_back(status);
    if (g_log_lines.size() > kLogLines) g_log_lines.erase(g_log_lines.begin());
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
