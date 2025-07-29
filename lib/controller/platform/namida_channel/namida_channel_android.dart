part of 'namida_channel.dart';

/// The new flutter update, calls AppLifecycleState.inactive whenever the app
/// loses focus, like swiping notification center, not ideal for what we need.
/// so we use a method channel whenever `onUserLeaveHint`, etc is called from FlutterActivity
class _NamidaChannelAndroid extends NamidaChannel {
  late final MethodChannel _channel;
  late final EventChannel _channelEvent;

  StreamSubscription? _streamSub;

  _NamidaChannelAndroid._init() {
    _channel = const MethodChannel('namida');
    _channelEvent = const EventChannel('namida_events');

    _initLiseners();
  }

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

  @override
  Future<bool> openNamidaSync(String backupFolder, String musicFoldersJoined) async {
    try {
      final res = await _channel.invokeMethod(
        'openNamidaSync',
        {
          'backupPath': backupFolder,
          'musicFolders': musicFoldersJoined,
        },
      );
      return res ?? false;
    } on PlatformException catch (_) {
      // -- package doesn't exist
      return false;
    }
  }

  void _initLiseners() {
    _streamSub?.cancel();
    try {
      _streamSub = _channelEvent.receiveBroadcastStream().map((event) => event as bool).listen((message) {
        isInPip.value = message;
      });
    } catch (_) {
      // -- not initialized properly, can happen sometimes on newer android versions
    }

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onResume':
          for (final fn in _onResume) {
            fn();
          }

        case 'onUserLeaveHint':
          for (final fn in _onSuspending) {
            fn();
          }
        case 'onDestroy':
          for (final fn in _onDestroy) {
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
