// by claude
#ifndef RUNNER_APP_ICON_SWITCHER_H_
#define RUNNER_APP_ICON_SWITCHER_H_

#include <windows.h>

#include <string>
#include <thread>

class AppIconSwitcher {
 public:
  explicit AppIconSwitcher(HWND window);
  ~AppIconSwitcher();

  AppIconSwitcher(const AppIconSwitcher&) = delete;
  AppIconSwitcher& operator=(const AppIconSwitcher&) = delete;

  // -- also reapplies to the shortcuts when an update recreated them
  void ApplySaved();

  bool IsEnabled(const std::string& key) const;
  void Change(const std::string& key);

 private:
  void ApplyToWindow(int resource_id);
  void ApplyToShortcutsInBackground(int resource_id);

  HWND window_;
  HICON big_icon_ = nullptr;
  HICON small_icon_ = nullptr;
  std::thread shortcuts_thread_;
};

#endif  // RUNNER_APP_ICON_SWITCHER_H_
