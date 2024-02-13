import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

/// The new flutter update, calls AppLifecycleState.inactive whenever the app
/// loses focus, like swiping notification center, not ideal for what we need.
/// so we use a method channel whenever `onUserLeaveHint`, etc is called from FlutterActivity
class NamidaChannel {
  static final NamidaChannel inst = NamidaChannel._internal();
  NamidaChannel._internal() {
    _channel = const MethodChannel('namida');
    _channelEvent = const EventChannel('namida_events');

    _streamSub?.cancel();
    _streamSub = _channelEvent.receiveBroadcastStream().map((event) => event as bool).listen((message) {
      isInPip.value = message;
    });
    _initLiseners();
  }

  StreamSubscription? _streamSub;

  final isInPip = false.obs;

  Future<void> updatePipRatio({int? width, int? height}) async {
    await _channel.invokeMethod('updatePipRatio', {'width': width, 'height': height});
  }

  Future<void> setCanEnterPip(bool canEnter) async {
    await _channel.invokeMethod('setCanEnterPip', {"canEnter": canEnter});
  }

  Future<void> showToast({
    required String message,
    int seconds = 5,
  }) async {
    _channel.invokeMethod(
      'showToast',
      {
        "text": message,
        "seconds": seconds,
      },
    );
  }

  Future<int> getPlatformSdk() async {
    final version = await _channel.invokeMethod<int?>('sdk');
    return version ?? 0;
  }

  Future<bool> setMusicAs({required String path, required List<SetMusicAsAction> types}) async {
    final t = <int>[];
    types.loop((e, index) {
      final n = _setMusicAsActionConverter[e];
      if (n != null) t.add(n);
    });
    final res = await _channel.invokeMethod<bool?>('setMusicAs', {'path': path, 'types': t});
    return res ?? false;
  }

  Future<bool> openSystemEqualizer() async {
    final res = await _channel.invokeMethod<bool?>('openEqualizer');
    return res ?? false;
  }

  late final MethodChannel _channel;
  late final EventChannel _channelEvent;

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

  final _onResume = <String, FutureOr<void> Function()>{};
  final _onSuspending = <String, FutureOr<void> Function()>{};
  final _onDestroy = <String, FutureOr<void> Function()>{};

  void addOnDestroy(String key, FutureOr<void> Function() fn) {
    _onDestroy[key] = fn;
  }

  void addOnResume(String key, FutureOr<void> Function() fn) {
    _onResume[key] = fn;
  }

  void addOnSuspending(String key, FutureOr<void> Function() fn) {
    _onSuspending[key] = fn;
  }

  void removeOnDestroy(String key) {
    _onDestroy.remove(key);
  }

  void removeOnResume(String key) {
    _onResume.remove(key);
  }

  void removeOnSuspending(String key) {
    _onSuspending.remove(key);
  }

  late final _setMusicAsActionConverter = {
    SetMusicAsAction.alarm: 4,
    SetMusicAsAction.notification: 2,
    SetMusicAsAction.ringtone: 1,
  };
}
