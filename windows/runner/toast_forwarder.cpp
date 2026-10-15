#include "toast_forwarder.h"

#include <NotificationActivationCallback.h>
#include <appmodel.h>
#include <shellapi.h>

#include <string>

namespace {

// Keep in sync with _exeNotificationGuid in lib/services/backend/notifications/notifications_service.dart.
constexpr CLSID kExeToastActivatorClsid = {
    0x5963a68d, 0x695e, 0x4b6e, {0x95, 0x96, 0x42, 0x1c, 0x00, 0x53, 0xa0, 0x55}};

// COM calls Activate right after the class object is registered; this only bounds a launch that never gets one.
constexpr UINT kActivationTimeoutMs = 10000;

HWND g_target = nullptr;

class ActivationCallback : public INotificationActivationCallback {
 public:
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** out) override {
    if (riid == IID_IUnknown || riid == __uuidof(INotificationActivationCallback)) {
      *out = static_cast<INotificationActivationCallback*>(this);
      AddRef();
      return S_OK;
    }
    *out = nullptr;
    return E_NOINTERFACE;
  }

  ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&refs_); }

  ULONG STDMETHODCALLTYPE Release() override {
    const ULONG refs = InterlockedDecrement(&refs_);
    if (refs == 0) delete this;
    return refs;
  }

  HRESULT STDMETHODCALLTYPE Activate(LPCWSTR, LPCWSTR args, const NOTIFICATION_USER_INPUT_DATA* data,
                                     ULONG count) override {
    std::wstring message = args ? args : L"";
    message.push_back(L'\0');
    for (ULONG i = 0; i < count; i++) {
      message.append(data[i].Key ? data[i].Key : L"");
      message.push_back(L'\0');
      message.append(data[i].Value ? data[i].Value : L"");
      message.push_back(L'\0');
    }

    // The shell lets this process take the foreground; pass that on so a tap can focus the window.
    DWORD target_pid = 0;
    GetWindowThreadProcessId(g_target, &target_pid);
    AllowSetForegroundWindow(target_pid);

    COPYDATASTRUCT cds{kToastActivationCopyDataId, static_cast<DWORD>(message.size() * sizeof(wchar_t)),
                       message.data()};
    SendMessageTimeoutW(g_target, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&cds), SMTO_ABORTIFHUNG, 5000,
                        nullptr);
    PostQuitMessage(0);
    return S_OK;
  }

 private:
  LONG refs_ = 1;
};

class ActivationCallbackFactory : public IClassFactory {
 public:
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** out) override {
    if (riid == IID_IUnknown || riid == IID_IClassFactory) {
      *out = static_cast<IClassFactory*>(this);
      return S_OK;
    }
    *out = nullptr;
    return E_NOINTERFACE;
  }

  // Lives on the stack for the whole registration, so no real ref counting.
  ULONG STDMETHODCALLTYPE AddRef() override { return 2; }
  ULONG STDMETHODCALLTYPE Release() override { return 1; }

  HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer, REFIID riid, void** out) override {
    *out = nullptr;
    if (outer) return CLASS_E_NOAGGREGATION;
    auto* callback = new ActivationCallback();
    const HRESULT hr = callback->QueryInterface(riid, out);
    callback->Release();
    return hr;
  }

  HRESULT STDMETHODCALLTYPE LockServer(BOOL) override { return S_OK; }
};

// flutter_local_notifications_windows registers LocalServer32 with this argument, as the Windows App SDK does.
constexpr wchar_t kToastActivatedArgument[] = L"----AppNotificationActivated:";

bool LaunchedForToast() {
  int argc = 0;
  wchar_t** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  bool toast = false;
  for (int i = 1; argv != nullptr && i < argc; i++) {
    if (wcsncmp(argv[i], kToastActivatedArgument, wcslen(kToastActivatedArgument)) == 0 ||
        _wcsicmp(argv[i], L"-Embedding") == 0 || _wcsicmp(argv[i], L"/Embedding") == 0) {
      toast = true;
    }
  }
  LocalFree(argv);
  return toast;
}

}  // namespace

bool ForwardToastActivationToRunningInstance(const wchar_t* window_class, const wchar_t* title) {
  if (!LaunchedForToast()) return false;

  // Packaged builds activate through their manifest's ExeServer instead.
  UINT32 length = 0;
  if (GetCurrentPackageFullName(&length, nullptr) != APPMODEL_ERROR_NO_PACKAGE) return false;

  g_target = FindWindowW(window_class, title);
  if (g_target == nullptr) return false;

  if (FAILED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) return false;

  ActivationCallbackFactory factory;
  DWORD registration = 0;
  bool forwarded = false;
  if (SUCCEEDED(CoRegisterClassObject(kExeToastActivatorClsid, &factory, CLSCTX_LOCAL_SERVER, REGCLS_SINGLEUSE,
                                      &registration))) {
    const UINT_PTR timer = SetTimer(nullptr, 0, kActivationTimeoutMs, nullptr);
    MSG msg{};
    while (GetMessageW(&msg, nullptr, 0, 0)) {
      if (msg.message == WM_TIMER && msg.hwnd == nullptr) break;
      TranslateMessage(&msg);
      DispatchMessageW(&msg);
    }
    // GetMessage returns 0 only for the WM_QUIT that Activate posts.
    forwarded = msg.message == WM_QUIT;
    KillTimer(nullptr, timer);
    CoRevokeClassObject(registration);
  }

  CoUninitialize();
  return forwarded;
}
