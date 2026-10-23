part of 'home_widgets.dart';

// by claude
/// the widget extension's side lives in `ios/NamidaWidgets`, `NamidaWidgetsPlugin` copies what's written here into the app group.
/// a build that had to drop the extension has no `namida/widgets` channel, nothing is written then.
class _HomeWidgetsIOS extends HomeWidgets {
  _HomeWidgetsIOS() {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static const _channel = MethodChannel('namida/widgets');

  @override
  Set<_HomeWidgetKey> get _shownKeys => _kShownKeys;
  static const _kShownKeys = {
    _HomeWidgetKey.title, _HomeWidgetKey.message, _HomeWidgetKey.image, //
    _HomeWidgetKey.playing, _HomeWidgetKey.favourite, //
  };

  bool _isAvailable = false;
  Future<void> Function(HomeWidgetMediaAction action)? _performMediaAction;

  /// whether widgets are placed arrives later through `onHasWidgetsChanged`, asking the system for it isn't instant.
  @override
  Future<bool?> init() async {
    try {
      final isAvailable = await _channel.invokeMethod<bool>('isAvailable');
      _isAvailable = isAvailable == true;
    } on MissingPluginException catch (_) {
      _isAvailable = false;
    }
    return _isAvailable;
  }

  Future<Object?> _onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onMediaAction':
        final actionName = call.arguments as String;
        final action = HomeWidgetMediaAction.values.getEnum(actionName);
        final performMediaAction = _performMediaAction;
        if (action != null && performMediaAction != null) await performMediaAction(action);
      case 'onHasWidgetsChanged':
        final hasWidgets = call.arguments as bool;
        await setHasWidgets(hasWidgets);
    }
    return null;
  }

  @override
  Future<void> onPlayerReady(Future<void> Function(HomeWidgetMediaAction action) performMediaAction) async {
    if (!_isAvailable) return;
    _performMediaAction = performMediaAction;
    await _channel.invokeMethod('attachMediaActions');
  }

  @override
  Future<void> _saveAndRefresh(Map<String, Object?> data) {
    return _channel.invokeMethod('updateHomeWidget', data);
  }

  @override
  Future<bool> updateLiveActivity({required String title, required String? artist, required String? line}) async {
    if (!_isAvailable) return false;
    final isSupported = await _channel.invokeMethod<bool>('updateLiveActivity', {
      'title': title,
      'artist': artist,
      'line': line,
    });
    return isSupported == true;
  }

  @override
  Future<void> endLiveActivity() async {
    if (!_isAvailable) return;
    await _channel.invokeMethod('endLiveActivity');
  }
}
