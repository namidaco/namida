part of 'namida_channel.dart';

/// registered by both the ios & macos runners.
const _kDarwinChannel = MethodChannel('namida');

abstract class _NamidaChannelDarwin extends NamidaChannel {
  void Function(List<String> items)? _onOpenedUrls;

  _NamidaChannelDarwin() {
    _kDarwinChannel.setMethodCallHandler(_onMethodCall);
    // -- resumed also follows every inactive state (control center, a dialog), shown only follows an actual return
    AppLifecycleListener(onShow: _runOnResume);
  }

  void _runOnResume() {
    for (final fn in _onResume) {
      fn();
    }
  }

  Future<void> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onOpenedUrls':
        final items = (call.arguments as List).cast<String>();
        _onOpenedUrls?.call(items);
    }
  }

  @override
  Future<void> listenOpenedUrls(void Function(List<String> items) onItems) async {
    _onOpenedUrls = onItems;
    final pending = await _kDarwinChannel.invokeListMethod<String>('consumeOpenedUrls');
    if (pending != null && pending.isNotEmpty) onItems(pending);
  }
}

class _NamidaChannelIOS extends _NamidaChannelDarwin {
  _NamidaChannelIOS._init();

  @override
  bool get canOpenFileInExplorer => true;

  @override
  Future<void>? openFileInExplorer(String filePath, {bool isDirectory = false}) {
    return _kDarwinChannel.invokeMethod('openInFiles', {'path': filePath, 'isDirectory': isDirectory});
  }

  @override
  bool get supportsAppIcons => true;

  @override
  Future<bool?> isAppIconEnabled(NamidaAppIcons type) {
    return _kDarwinChannel.invokeMethod<bool>('isAppIconEnabled', {'key': type.name});
  }

  @override
  Future<void> changeAppIcon(NamidaAppIcons type) {
    return _kDarwinChannel.invokeMethod('changeAppIcon', {'key': type.name});
  }

  @override
  Future<void> setPreferredSampleRate(int sampleRate) {
    return _kDarwinChannel.invokeMethod('setPreferredSampleRate', {'sampleRate': sampleRate});
  }

  @override
  Future<void> setKeepRunningInBackground(bool keepRunning) {
    return _kDarwinChannel.invokeMethod('setKeepRunningInBackground', {'keepRunning': keepRunning});
  }

  @override
  Future<void> updateBackgroundWorkProgress({required int progress, required int totalProgress, required int itemsCount}) {
    return _kDarwinChannel.invokeMethod('updateBackgroundWorkProgress', {
      'progress': progress,
      'totalProgress': totalProgress,
      'itemsCount': itemsCount,
    });
  }
}

class _NamidaChannelMacOS extends _NamidaChannelDarwin {
  _NamidaChannelMacOS._init();

  @override
  bool get canOpenFileInExplorer => true;

  @override
  Future<void>? openFileInExplorer(String filePath, {bool isDirectory = false}) {
    return Process.start('open', isDirectory ? [filePath] : ['-R', filePath]);
  }
}
