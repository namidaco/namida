#include "flutter_window.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

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

  app_icon_switcher_ = std::make_unique<AppIconSwitcher>(GetHandle());
  app_icon_switcher_->ApplySaved();
  namida_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "namida",
          &flutter::StandardMethodCodec::GetInstance());
  namida_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleNamidaCall(call, std::move(result));
  });

  // Dart positions, maximizes and shows the window. Maximizing makes it
  // visible, so it stays cloaked until it has a frame to present.
  BOOL cloak = TRUE;
  DwmSetWindowAttribute(GetHandle(), DWMWA_CLOAK, &cloak, sizeof(cloak));
  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    BOOL cloak = FALSE;
    DwmSetWindowAttribute(GetHandle(), DWMWA_CLOAK, &cloak, sizeof(cloak));
  });

  // Flutter can complete the first frame before the callback is registered.
  // This ensures a frame is pending, no-op if the first frame hasn't completed.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  namida_channel_ = nullptr;
  app_icon_switcher_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::HandleNamidaCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
  const std::string* key = nullptr;
  if (arguments) {
    const auto found = arguments->find(flutter::EncodableValue("key"));
    if (found != arguments->end()) {
      key = std::get_if<std::string>(&found->second);
    }
  }
  const std::string& method = call.method_name();
  if (method == "isAppIconEnabled" && key) {
    const bool is_enabled = app_icon_switcher_->IsEnabled(*key);
    result->Success(flutter::EncodableValue(is_enabled));
  } else if (method == "changeAppIcon" && key) {
    app_icon_switcher_->Change(*key);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
