// by claude
#include "app_icon_switcher.h"

#include <shlobj.h>
#include <shobjidl.h>
#include <wrl/client.h>

#include <filesystem>
#include <system_error>
#include <utility>
#include <vector>

#include "app_icons.h"
#include "resource.h"

namespace {

constexpr char kRegistryPath[] = "Software\\Namida";
constexpr char kIconValue[] = "AppIcon";
constexpr char kShortcutsStampValue[] = "AppIconShortcutsStamp";

int ResourceIdForKey(const std::string& key) {
  for (const auto& icon : kAppIconResources) {
    if (key == icon.key) {
      return icon.resource_id;
    }
  }
  return IDI_APP_ICON;
}

int ReadSavedResourceId() {
  char key[64];
  DWORD size = sizeof(key);
  const LSTATUS status =
      RegGetValueA(HKEY_CURRENT_USER, kRegistryPath, kIconValue, RRF_RT_REG_SZ,
                   nullptr, key, &size);
  if (status != ERROR_SUCCESS) {
    return IDI_APP_ICON;
  }
  return ResourceIdForKey(key);
}

void WriteSavedKey(const std::string& key) {
  const DWORD size = static_cast<DWORD>(key.size() + 1);
  RegSetKeyValueA(HKEY_CURRENT_USER, kRegistryPath, kIconValue, REG_SZ,
                  key.c_str(), size);
}

std::wstring ExePath() {
  wchar_t path[MAX_PATH];
  const DWORD length = GetModuleFileNameW(nullptr, path, MAX_PATH);
  return std::wstring(path, length);
}

// -- an update rewrites the exe and recreates the shortcuts, so a different
// write time means the shortcuts are back to the default icon.
ULONGLONG ExeWriteTime(const std::wstring& exe_path) {
  WIN32_FILE_ATTRIBUTE_DATA data;
  if (!GetFileAttributesExW(exe_path.c_str(), GetFileExInfoStandard, &data)) {
    return 0;
  }
  ULARGE_INTEGER time;
  time.LowPart = data.ftLastWriteTime.dwLowDateTime;
  time.HighPart = data.ftLastWriteTime.dwHighDateTime;
  return time.QuadPart;
}

ULONGLONG ReadShortcutsStamp() {
  ULONGLONG stamp = 0;
  DWORD size = sizeof(stamp);
  RegGetValueA(HKEY_CURRENT_USER, kRegistryPath, kShortcutsStampValue,
               RRF_RT_REG_QWORD, nullptr, &stamp, &size);
  return stamp;
}

void WriteShortcutsStamp(ULONGLONG stamp) {
  RegSetKeyValueA(HKEY_CURRENT_USER, kRegistryPath, kShortcutsStampValue,
                  REG_QWORD, &stamp, sizeof(stamp));
}

std::filesystem::path KnownFolder(REFKNOWNFOLDERID folder_id) {
  PWSTR path = nullptr;
  std::filesystem::path folder;
  if (SUCCEEDED(
          SHGetKnownFolderPath(folder_id, KF_FLAG_DEFAULT, nullptr, &path))) {
    folder = path;
  }
  CoTaskMemFree(path);
  return folder;
}

// -- the folders where the installer and the user put shortcuts. the all users
// ones need admin, saving there fails and they keep the default icon.
std::vector<std::filesystem::path> ShortcutFolders() {
  std::vector<std::filesystem::path> folders;
  for (const KNOWNFOLDERID* folder_id :
       {&FOLDERID_Programs, &FOLDERID_Desktop, &FOLDERID_CommonPrograms,
        &FOLDERID_PublicDesktop}) {
    std::filesystem::path folder = KnownFolder(*folder_id);
    if (!folder.empty()) {
      folders.push_back(std::move(folder));
    }
  }
  const std::filesystem::path pinned = KnownFolder(FOLDERID_UserPinned);
  if (!pinned.empty()) {
    folders.push_back(pinned / L"TaskBar");
  }
  return folders;
}

bool IsSamePath(const wchar_t* a, const wchar_t* b) {
  return CompareStringOrdinal(a, -1, b, -1, TRUE) == CSTR_EQUAL;
}

bool ApplyToShortcut(const std::filesystem::path& shortcut_path,
                     const std::wstring& exe_path, int resource_id) {
  Microsoft::WRL::ComPtr<IShellLinkW> link;
  if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&link)))) {
    return false;
  }
  Microsoft::WRL::ComPtr<IPersistFile> file;
  if (FAILED(link.As(&file)) ||
      FAILED(file->Load(shortcut_path.c_str(), STGM_READWRITE))) {
    return false;
  }
  wchar_t target[MAX_PATH] = L"";
  if (link->GetPath(target, MAX_PATH, nullptr, 0) != S_OK ||
      !IsSamePath(target, exe_path.c_str())) {
    return false;
  }

  // -- no icon location makes the shortcut show the exe's own icon, like the
  // installer creates it
  const bool is_default = resource_id == IDI_APP_ICON;
  const wchar_t* icon_path = is_default ? L"" : exe_path.c_str();
  const int icon_index = is_default ? 0 : -resource_id;
  wchar_t current_icon_path[MAX_PATH] = L"";
  int current_icon_index = 0;
  link->GetIconLocation(current_icon_path, MAX_PATH, &current_icon_index);
  if (IsSamePath(current_icon_path, icon_path) &&
      current_icon_index == icon_index) {
    return false;
  }
  if (FAILED(link->SetIconLocation(icon_path, icon_index)) ||
      FAILED(file->Save(nullptr, TRUE))) {
    return false;
  }
  SHChangeNotify(SHCNE_UPDATEITEM, SHCNF_PATHW, shortcut_path.c_str(), nullptr);
  return true;
}

void ApplyToShortcuts(int resource_id) {
  const std::wstring exe_path = ExePath();
  bool did_change = false;
  for (const auto& folder : ShortcutFolders()) {
    std::error_code error;
    std::filesystem::directory_iterator entries(folder, error);
    for (; !error && entries != std::filesystem::directory_iterator();
         entries.increment(error)) {
      const std::filesystem::path& path = entries->path();
      if (!IsSamePath(path.extension().c_str(), L".lnk")) {
        continue;
      }
      if (ApplyToShortcut(path, exe_path, resource_id)) {
        did_change = true;
      }
    }
  }
  if (did_change) {
    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);
  }
  WriteShortcutsStamp(ExeWriteTime(exe_path));
}

HICON LoadIconOfSize(int resource_id, int size) {
  HINSTANCE instance = GetModuleHandle(nullptr);
  HANDLE icon = LoadImageW(instance, MAKEINTRESOURCEW(resource_id), IMAGE_ICON,
                           size, size, LR_DEFAULTCOLOR);
  return static_cast<HICON>(icon);
}

}  // namespace

AppIconSwitcher::AppIconSwitcher(HWND window) : window_(window) {}

AppIconSwitcher::~AppIconSwitcher() {
  if (shortcuts_thread_.joinable()) {
    shortcuts_thread_.join();
  }
  if (big_icon_) {
    DestroyIcon(big_icon_);
  }
  if (small_icon_) {
    DestroyIcon(small_icon_);
  }
}

void AppIconSwitcher::ApplySaved() {
  const int resource_id = ReadSavedResourceId();
  if (resource_id == IDI_APP_ICON) {
    return;
  }
  ApplyToWindow(resource_id);
  const ULONGLONG exe_write_time = ExeWriteTime(ExePath());
  if (ReadShortcutsStamp() != exe_write_time) {
    ApplyToShortcutsInBackground(resource_id);
  }
}

bool AppIconSwitcher::IsEnabled(const std::string& key) const {
  return ResourceIdForKey(key) == ReadSavedResourceId();
}

void AppIconSwitcher::Change(const std::string& key) {
  WriteSavedKey(key);
  const int resource_id = ResourceIdForKey(key);
  ApplyToWindow(resource_id);
  ApplyToShortcutsInBackground(resource_id);
}

void AppIconSwitcher::ApplyToWindow(int resource_id) {
  HICON big_icon = LoadIconOfSize(resource_id, GetSystemMetrics(SM_CXICON));
  HICON small_icon = LoadIconOfSize(resource_id, GetSystemMetrics(SM_CXSMICON));
  SendMessage(window_, WM_SETICON, ICON_BIG,
              reinterpret_cast<LPARAM>(big_icon));
  SendMessage(window_, WM_SETICON, ICON_SMALL,
              reinterpret_cast<LPARAM>(small_icon));
  if (big_icon_) {
    DestroyIcon(big_icon_);
  }
  if (small_icon_) {
    DestroyIcon(small_icon_);
  }
  big_icon_ = big_icon;
  small_icon_ = small_icon;
}

void AppIconSwitcher::ApplyToShortcutsInBackground(int resource_id) {
  if (shortcuts_thread_.joinable()) {
    shortcuts_thread_.join();
  }
  shortcuts_thread_ = std::thread([resource_id]() {
    const HRESULT com_result =
        CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    ApplyToShortcuts(resource_id);
    if (SUCCEEDED(com_result)) {
      CoUninitialize();
    }
  });
}
