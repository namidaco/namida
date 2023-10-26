import 'dart:async';

import 'package:flutter/services.dart';

/// The new flutter update, calls AppLifecycleState.inactive whenever the app
/// loses focus, like swiping notification center, not ideal for what we need.
/// so we use a method channel whenever `onUserLeaveHint`, etc is called from FlutterActivity
class LifeCycleController {
  static final LifeCycleController inst = LifeCycleController._internal();
  LifeCycleController._internal() {
    namidaChannel = const MethodChannel('namida');
    _initLiseners();
  }

  late final MethodChannel namidaChannel;

  _initLiseners() {
    namidaChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onResume':
          for (final fn in _onResume.values) {
            fn();
          }

        case 'onUserLeaveHint':
          for (final fn in _onSuspending.values) {
            fn();
          }
        case 'onStop':
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
}
