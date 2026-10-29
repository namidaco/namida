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
