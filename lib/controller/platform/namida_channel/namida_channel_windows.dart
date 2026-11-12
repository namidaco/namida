part of 'namida_channel.dart';

class _NamidaChannelWindows extends NamidaChannel {
  _NamidaChannelWindows._internal();

  static const _channel = MethodChannel('namida');

  @override
  bool get canOpenFileInExplorer => true;

  @override
  Future<void>? openFileInExplorer(String filePath, {bool isDirectory = false}) {
    return Process.start(
      'explorer.exe',
      isDirectory ? [filePath] : ['/select,', filePath],
      runInShell: true,
      mode: ProcessStartMode.normal,
    );
  }

  static const _kInternetSettingsPath = r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  @override
  Future<NetworkProxy?> getSystemProxy() async {
    final key = win32_registry.CURRENT_USER;
    return NetworkProxy.fromWindowsSettings(
      proxyEnable: key.getInt('ProxyEnable', path: _kInternetSettingsPath),
      proxyServer: key.getString('ProxyServer', path: _kInternetSettingsPath),
      proxyOverride: key.getString('ProxyOverride', path: _kInternetSettingsPath),
    );
  }

  @override
  void listenSystemProxyChanges(Future<void> Function() onChanged) {
    WindowsRegistryWatcher.watchCurrentUserKey(_kInternetSettingsPath, onChanged);
  }

  static const _kAccentPath = r'Software\Microsoft\Windows\CurrentVersion\Explorer\Accent';
  static const _kDwmPath = r'Software\Microsoft\Windows\DWM';

  @override
  Future<Color?> getSystemAccentColor() async {
    final key = win32_registry.CURRENT_USER;
    final accentAbgr = key.getInt('AccentColorMenu', path: _kAccentPath);
    if (accentAbgr != null) {
      final accentArgb = (accentAbgr & 0xFF00FF00) | ((accentAbgr & 0xFF) << 16) | ((accentAbgr >> 16) & 0xFF);
      return Color(accentArgb);
    }
    final dwmArgb = key.getInt('ColorizationColor', path: _kDwmPath);
    if (dwmArgb == null) return null;
    return Color(dwmArgb);
  }

  WindowsRegistryWatch? _accentColorWatch;

  @override
  void setSystemAccentColorListener(void Function()? onChanged) {
    _accentColorWatch?.cancel();
    _accentColorWatch = null;
    if (onChanged == null) return;
    _accentColorWatch = WindowsRegistryWatcher.watchCurrentUserKey(_kAccentPath, onChanged);
    _accentColorWatch ??= WindowsRegistryWatcher.watchCurrentUserKey(_kDwmPath, onChanged);
  }

  @override
  bool get supportsAppIcons => true;

  @override
  Future<String?> _getEnabledAppIconKey() {
    return _channel.invokeMethod<String>('getEnabledAppIcon');
  }

  @override
  Future<void> _changeAppIcon(NamidaAppIcons type) {
    return _channel.invokeMethod('changeAppIcon', {'key': type.name});
  }
}
