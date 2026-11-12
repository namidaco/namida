part of 'namida_channel.dart';

class _NamidaChannelLinux extends NamidaChannel {
  _NamidaChannelLinux._internal() {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static const _channel = MethodChannel('namida');

  Future<void> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSystemAccentColorChanged':
        _onSystemAccentColorChanged?.call();
    }
  }

  late final _portalAppearance = _PortalAppearanceSettings();

  /// the portal accent color, else the gtk theme selection color.
  @override
  Future<Color?> getSystemAccentColor() async {
    final portalAccentColor = await _portalAppearance.getAccentColor();
    if (portalAccentColor != null) return portalAccentColor;
    return NamidaChannel._getSystemAccentColorFromChannel(_channel);
  }

  void Function()? _onSystemAccentColorChanged;
  StreamSubscription<DBusSignal>? _portalAccentColorSubscription;

  @override
  void setSystemAccentColorListener(void Function()? onChanged) {
    _onSystemAccentColorChanged = onChanged;
    _portalAccentColorSubscription?.cancel();
    _portalAccentColorSubscription = null;
    _channel.invokeMethod('setSystemAccentColorListener', {'enabled': onChanged != null});
    if (onChanged == null) return;
    final accentColorChanges = _portalAppearance.onAccentColorChanged();
    // -- no session bus or portal, gtk theme changes still arrive through the channel
    _portalAccentColorSubscription = accentColorChanges.listen((_) => onChanged(), onError: (_) {});
  }

  @override
  bool get canOpenFileInExplorer => true;

  @override
  Future<void>? openFileInExplorer(String filePath, {bool isDirectory = false}) async {
    final fileManagers = <({String command, List<String> args})>[
      // KDE Dolphin
      (command: 'dolphin', args: ['--select', filePath]),
      // GNOME Files (Nautilus)
      (command: 'nautilus', args: ['--select', filePath]),
      // Nemo (Cinnamon)
      (command: 'nemo', args: [filePath]),
      // Thunar (XFCE)
      (command: 'thunar', args: [filePath]),
      // PCManFM (LXDE)
      (command: 'pcmanfm', args: [filePath]),
      // Fallback: xdg-open (opens parent directory)
      (command: 'xdg-open', args: [File(filePath).parent.path]),
    ];

    for (final fm in fileManagers) {
      try {
        // Check if command exists
        final which = await Process.run('which', [fm.command]);
        if (which.exitCode == 0) {
          await Process.start(
            fm.command,
            fm.args,
            mode: ProcessStartMode.detached,
          );
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }
}

/// `org.freedesktop.portal.Settings`, kde plasma 6 and gnome 47+ provide the accent color.
// by claude
class _PortalAppearanceSettings {
  static const _interface = 'org.freedesktop.portal.Settings';
  static const _namespace = 'org.freedesktop.appearance';
  static const _accentColorKey = 'accent-color';
  static const _timeout = Duration(seconds: 3);

  late final _client = DBusClient.session();
  late final _object = DBusRemoteObject(
    _client,
    name: 'org.freedesktop.portal.Desktop',
    path: DBusObjectPath('/org/freedesktop/portal/desktop'),
  );

  /// null when the portal has none, ex: older portals and other desktops.
  Future<Color?> getAccentColor() async {
    try {
      final response = await _object
          .callMethod(_interface, 'ReadOne', const [DBusString(_namespace), DBusString(_accentColorKey)], replySignature: DBusSignature('v'))
          .timeout(_timeout);
      final rgb = response.values.first.asVariant().asStruct();
      final red = rgb[0].asDouble();
      final green = rgb[1].asDouble();
      final blue = rgb[2].asDouble();
      // -- values outside 0-1 mean no accent color is set
      if (!_isInRange(red) || !_isInRange(green) || !_isInRange(blue)) return null;
      return Color.from(alpha: 1.0, red: red, green: green, blue: blue);
    } catch (_) {
      return null;
    }
  }

  static bool _isInRange(double component) => component >= 0.0 && component <= 1.0;

  Stream<DBusSignal> onAccentColorChanged() {
    final settingChanges = DBusRemoteObjectSignalStream(object: _object, interface: _interface, name: 'SettingChanged', signature: DBusSignature('ssv'));
    return settingChanges.where((signal) => signal.values[0].asString() == _namespace && signal.values[1].asString() == _accentColorKey);
  }
}
