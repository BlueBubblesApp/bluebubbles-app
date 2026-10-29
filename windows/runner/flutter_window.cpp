#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "splash_screen.h"
#include "store_update.h"
#include "toast_forwarder.h"
#include "utils.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Channel the Flutter side uses to dismiss the native splash once its own
  // splash window is on screen (see ShowSplashScreen in main.cpp).
  splash_channel_ = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(), "bluebubbles/splash",
      &flutter::StandardMethodCodec::GetInstance());
  splash_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<>& call,
         std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "setStatus") {
          if (const auto* status = std::get_if<std::string>(call.arguments())) {
            int len = MultiByteToWideChar(CP_UTF8, 0, status->c_str(), -1, nullptr, 0);
            std::wstring wide(len > 0 ? len - 1 : 0, L'\0');
            if (len > 0) {
              MultiByteToWideChar(CP_UTF8, 0, status->c_str(), -1, &wide[0], len);
            }
            SetSplashStatus(wide);
          }
          result->Success();
        } else if (call.method_name() == "setProgress") {
          if (const auto* progress = std::get_if<double>(call.arguments())) {
            SetSplashProgress(*progress);
          }
          result->Success();
        } else if (call.method_name() == "closeSplash") {
          CloseSplashScreen();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  store_channel_ = CreateStoreUpdateChannel(flutter_controller_->engine()->messenger(), GetHandle());

  notification_channel_ = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(), "bluebubbles/notifications",
      &flutter::StandardMethodCodec::GetInstance());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_COPYDATA) {
    const auto* cds = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
    if (cds != nullptr && cds->dwData == kToastActivationCopyDataId) {
      ForwardToastActivation(*cds);
      return TRUE;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::ForwardToastActivation(const COPYDATASTRUCT& cds) {
  if (!notification_channel_ || cds.lpData == nullptr) return;
  const std::wstring message(static_cast<const wchar_t*>(cds.lpData), cds.cbData / sizeof(wchar_t));

  std::vector<std::string> parts;
  size_t start = 0;
  for (size_t end; (end = message.find(L'\0', start)) != std::wstring::npos; start = end + 1) {
    parts.push_back(Utf8FromUtf16(message.substr(start, end - start).c_str()));
  }
  if (parts.empty()) return;

  flutter::EncodableMap data;
  for (size_t i = 1; i + 1 < parts.size(); i += 2) {
    data[flutter::EncodableValue(parts[i])] = flutter::EncodableValue(parts[i + 1]);
  }
  notification_channel_->InvokeMethod(
      "activate", std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
                      {flutter::EncodableValue("payload"), flutter::EncodableValue(parts[0])},
                      {flutter::EncodableValue("data"), flutter::EncodableValue(data)},
                  }));
}
