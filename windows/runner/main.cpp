#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// flow launcher injects modifiers without scan codes and flutter keeps Win stuck. other keys would turn into numpad ones.
// flutter#193675 fixed it for Shift only, remove once the engine covers Ctrl, Alt and Win too.
void FillMissingModifierScanCode(MSG& msg) {
  switch (msg.message) {
    case WM_KEYDOWN:
    case WM_KEYUP:
    case WM_SYSKEYDOWN:
    case WM_SYSKEYUP:
      break;
    default:
      return;
  }
  const UINT scancode = static_cast<UINT>((msg.lParam >> 16) & 0xFF);
  if (scancode != 0) {
    return;
  }
  switch (msg.wParam) {
    case VK_SHIFT:
    case VK_CONTROL:
    case VK_MENU:
    case VK_LWIN:
    case VK_RWIN:
      break;
    default:
      return;
  }
  const UINT mapped = MapVirtualKey(static_cast<UINT>(msg.wParam), MAPVK_VK_TO_VSC_EX);
  if (mapped == 0) {
    return;
  }
  const bool is_extended = (mapped & 0xFF00) != 0;
  msg.lParam |= static_cast<LPARAM>(mapped & 0xFF) << 16;
  if (is_extended) {
    msg.lParam |= 1 << 24;
  }
}

}  // namespace

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
  // impeller (gles through angle) costs 2-3x the gpu of skia per frame, #1367
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"namida", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    FillMissingModifierScanCode(msg);
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
