part of 'namida_channel.dart';

/// The new flutter update, calls AppLifecycleState.inactive whenever the app
/// loses focus, like swiping notification center, not ideal for what we need.
/// so we use a method channel whenever `onUserLeaveHint`, etc is called from FlutterActivity
class _NamidaChannelAndroid extends NamidaChannel {
  late final MethodChannel _channel;
  late final EventChannel _channelEvent;

  _NamidaChannelAndroid._init() {
    _channel = const MethodChannel('namida');
    _channelEvent = const EventChannel('namida_events');

    _streamSub?.cancel();
    _streamSub = _channelEvent.receiveBroadcastStream().map((event) => event as bool).listen((message) {
      isInPip.value = message;
    });
    _initLiseners();
  }

  StreamSubscription? _streamSub;

  @override
  Future<void> updatePipRatio({int? width, int? height}) async {
    await _channel.invokeMethod('updatePipRatio', {'width': width, 'height': height});
  }

  @override
  Future<void> setCanEnterPip(bool canEnter) async {
    await _channel.invokeMethod('setCanEnterPip', {"canEnter": canEnter});
  }

  @override
  Future<void> showToast({
    required String message,
    required SnackDisplayDuration duration,
  }) async {
    final seconds = (duration.milliseconds / 1000).ceil();
    _channel.invokeMethod(
      'showToast',
      {
        "text": message,
        "seconds": seconds,
      },
    );
  }

  @override
  Future<int> getPlatformSdk() async {
    final version = await _channel.invokeMethod<int?>('sdk');
    return version ?? 0;
  }

  @override
  Future<bool> setMusicAs({required String path, required List<SetMusicAsAction> types}) async {
    final t = <int>[];
    types.loop((e) {
      final n = _setMusicAsActionConverter[e];
      if (n != null) t.add(n);
    });
    final res = await _channel.invokeMethod<bool?>('setMusicAs', {'path': path, 'types': t});
    return res ?? false;
  }

  @override
  Future<bool> openSystemEqualizer(int? sessionId) async {
    final res = await _channel.invokeMethod<bool?>('openEqualizer', {'sessionId': sessionId});
    return res ?? false;
  }

  void _initLiseners() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onResume':
          for (final fn in _onResume.values) {
            fn();
          }

        case 'onUserLeaveHint':
          for (final fn in _onSuspending.values) {
            fn();
          }
        case 'onDestroy':
          for (final fn in _onDestroy.values) {
            fn();
          }
      }
    });
  }

  late final _setMusicAsActionConverter = {
    SetMusicAsAction.alarm: 4,
    SetMusicAsAction.notification: 2,
    SetMusicAsAction.ringtone: 1,
  };
}
