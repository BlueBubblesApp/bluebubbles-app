#include "gpu_watchdog.h"

#include <d3d11.h>
#include <wrl/client.h>

#include <string>
#include <thread>

namespace {

// An env var, not an argument: the Dart side reads the first argument ("minimized").
constexpr wchar_t kParentPidVariable[] = L"BLUEBUBBLES_GPU_RECOVERY_PARENT";

Microsoft::WRL::ComPtr<ID3D11Device> CreateDevice() {
  Microsoft::WRL::ComPtr<ID3D11Device> device;
  D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0, nullptr, 0, D3D11_SDK_VERSION, &device, nullptr,
                    nullptr);
  return device;
}

// Starts a new copy of the app for the old one to hand over to. False when it couldn't, with nothing left behind.
bool Relaunch(HWND window) {
  wchar_t exe[MAX_PATH];
  if (GetModuleFileNameW(nullptr, exe, MAX_PATH) == 0) return false;
  std::wstring command_line = L"\"" + std::wstring(exe) + L"\"";
  // Hidden to the tray, or minimized: either way it shouldn't pop up on its own after a wake.
  if (!IsWindowVisible(window) || IsIconic(window)) command_line += L" minimized";

  SetEnvironmentVariableW(kParentPidVariable, std::to_wstring(GetCurrentProcessId()).c_str());
  STARTUPINFOW startup{sizeof(startup)};
  PROCESS_INFORMATION process{};
  if (!CreateProcessW(exe, command_line.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &startup,
                      &process)) {
    // Or anything this process starts later would wait on it
    SetEnvironmentVariableW(kParentPidVariable, nullptr);
    return false;
  }
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  return true;
}

void Watch(HWND window) {
  // An idle device on the default adapter, which is the one Flutter renders on. A GPU reset removes it too.
  auto device = CreateDevice();
  if (!device) return;  // No hardware GPU (RDP, WARP), so nothing to lose.
  while (true) {
    while (SUCCEEDED(device->GetDeviceRemovedReason())) Sleep(2000);

    // Wait (up to 15s) for the driver to come back, or the relaunch comes up white too and can't create its own
    // watchdog device.
    device.Reset();
    for (int i = 0; i < 30 && !device; i++) {
      Sleep(500);
      device = CreateDevice();
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      if (Relaunch(window)) {
        // Not a graceful exit: the engine may be stuck on the dead device, and close-to-tray would swallow
        // WM_CLOSE. ObjectBox commits are atomic, so stored data is safe.
        TerminateProcess(GetCurrentProcess(), 0);
      }
      Sleep(2000);
    }

    // Couldn't relaunch: keep watching, so the next loss tries again rather than leaving nothing on watch.
    while (!device) {
      Sleep(2000);
      device = CreateDevice();
    }
  }
}

}  // namespace

void StartGpuWatchdog(HWND window) {
#ifdef NDEBUG
  if (!IsDebuggerPresent()) std::thread(Watch, window).detach();
#else
  (void)window;  // /W4 /WX
#endif
}

void WaitForGpuRecoveryParent() {
  wchar_t pid[16];
  const DWORD length = GetEnvironmentVariableW(kParentPidVariable, pid, 16);
  if (length == 0 || length >= 16) return;
  SetEnvironmentVariableW(kParentPidVariable, nullptr);

  // The old process holds the database open until it exits.
  if (HANDLE parent = OpenProcess(SYNCHRONIZE, FALSE, wcstoul(pid, nullptr, 10))) {
    WaitForSingleObject(parent, 10000);
    CloseHandle(parent);
  }
}
