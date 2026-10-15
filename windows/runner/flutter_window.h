#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Channel used to dismiss the native splash screen.
  std::unique_ptr<flutter::MethodChannel<>> splash_channel_;

  // Channel for Microsoft Store in-app updates.
  std::unique_ptr<flutter::MethodChannel<>> store_channel_;

  // Delivers toast activations forwarded from a second instance (see toast_forwarder.h).
  std::unique_ptr<flutter::MethodChannel<>> notification_channel_;

  void ForwardToastActivation(const COPYDATASTRUCT& cds);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
