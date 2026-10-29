#include "store_update.h"

#include <flutter/standard_method_codec.h>
#include <shobjidl.h>
#include <winrt/Windows.ApplicationModel.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Services.Store.h>

#include <string>

using namespace winrt::Windows::Services::Store;
using MethodResultPtr = std::unique_ptr<flutter::MethodResult<>>;

namespace {

StoreContext GetStoreContext(HWND hwnd) {
  auto context = StoreContext::GetDefault();
  // Win32 apps must parent Store dialogs to an HWND or the request fails.
  context.as<::IInitializeWithWindow>()->Initialize(hwnd);
  return context;
}

winrt::fire_and_forget CheckUpdate(HWND hwnd, MethodResultPtr result) {
  winrt::apartment_context ui;
  std::string error;
  try {
    auto updates = co_await GetStoreContext(hwnd).GetAppAndOptionalStorePackageUpdatesAsync();
    co_await ui;
    if (updates.Size() == 0) {
      result->Success();
      co_return;
    }
    auto v = updates.GetAt(0).Package().Id().Version();
    result->Success(flutter::EncodableValue(std::to_string(v.Major) + "." + std::to_string(v.Minor) + "." +
                                            std::to_string(v.Build) + "." + std::to_string(v.Revision)));
    co_return;
  } catch (winrt::hresult_error const& e) {
    error = winrt::to_string(e.message());
  } catch (...) {
    error = "unknown error";
  }
  // Can't co_await inside a catch, and an exception may surface on a background thread.
  co_await ui;
  result->Error("store_error", error);
}

winrt::fire_and_forget InstallUpdate(HWND hwnd, MethodResultPtr result) {
  winrt::apartment_context ui;
  std::string error;
  try {
    auto context = GetStoreContext(hwnd);
    auto updates = co_await context.GetAppAndOptionalStorePackageUpdatesAsync();
    co_await ui;
    if (updates.Size() == 0) {
      result->Success(flutter::EncodableValue(false));
      co_return;
    }
    // The Store force-closes the app to install, so this may never return. Registering here (not at
    // startup) gets the app relaunched after the update without also auto-restarting it after crashes.
    RegisterApplicationRestart(nullptr, 0);
    auto install = co_await context.RequestDownloadAndInstallStorePackageUpdatesAsync(updates);
    co_await ui;
    bool completed = install.OverallState() == StorePackageUpdateState::Completed;
    if (!completed) UnregisterApplicationRestart();
    result->Success(flutter::EncodableValue(completed));
    co_return;
  } catch (winrt::hresult_error const& e) {
    error = winrt::to_string(e.message());
  } catch (...) {
    error = "unknown error";
  }
  co_await ui;
  UnregisterApplicationRestart();
  result->Error("store_error", error);
}

}  // namespace

std::unique_ptr<flutter::MethodChannel<>> CreateStoreUpdateChannel(
    flutter::BinaryMessenger* messenger, HWND hwnd) {
  auto channel = std::make_unique<flutter::MethodChannel<>>(
      messenger, "bluebubbles/store", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [hwnd](const flutter::MethodCall<>& call, MethodResultPtr result) {
        if (call.method_name() == "checkUpdate") {
          CheckUpdate(hwnd, std::move(result));
        } else if (call.method_name() == "installUpdate") {
          InstallUpdate(hwnd, std::move(result));
        } else {
          result->NotImplemented();
        }
      });
  return channel;
}
