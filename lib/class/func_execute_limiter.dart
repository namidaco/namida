import 'dart:async';

import 'package:namida/core/extensions.dart';

/// Controls function that may execute rapidly, mainly to improve performance.
class FunctionExecuteLimiter<T> {
  FunctionExecuteLimiter({
    this.considerRapidAfterNExecutions = 2,
    Duration considerRapid = const Duration(milliseconds: 800),
    Duration executeAfter = const Duration(milliseconds: 800),
  })  : _considerRapid = considerRapid,
        _executeAfter = executeAfter;

  final Duration _considerRapid;
  final Duration _executeAfter;
  final int considerRapidAfterNExecutions;
  int rapidExecutionsCount = 0;

  bool get _isRapidlyCalling => DateTime.now().difference(_latestColorUpdate) < _considerRapid;
  Timer? _isRapidlyCallingTimer;
  DateTime _latestColorUpdate = DateTime(0);

  Completer<T?>? _valueCompleter;

  void execute(Function fn, {void Function()? onRapidDetected}) {
    if (_isRapidlyCalling) {
      rapidExecutionsCount++;
    } else {
      rapidExecutionsCount = 0;
    }
    if (rapidExecutionsCount >= considerRapidAfterNExecutions) {
      if (onRapidDetected != null) onRapidDetected();
      _latestColorUpdate = DateTime.now();
      _isRapidlyCallingTimer?.cancel();
      _isRapidlyCallingTimer = Timer(_executeAfter, () {
        fn();
      });
    } else {
      _latestColorUpdate = DateTime.now();
      fn();
    }
  }

  Future<T?> executeFuture(Future<T?> Function() fn, {void Function()? onRapidDetected, void Function()? onReExecute}) async {
    if (_isRapidlyCalling) {
      rapidExecutionsCount++;
    } else {
      rapidExecutionsCount = 0;
    }
    if (rapidExecutionsCount >= considerRapidAfterNExecutions) {
      if (onRapidDetected != null) onRapidDetected();
      _latestColorUpdate = DateTime.now();
      _isRapidlyCallingTimer?.cancel();
      _valueCompleter?.completeIfWasnt(null);
      _valueCompleter = Completer<T?>();
      _isRapidlyCallingTimer = Timer(const Duration(milliseconds: 800), () {
        fn().then((value) {
          _valueCompleter?.completeIfWasnt(value);
          if (onReExecute != null) onReExecute();
        });
      });
      return _valueCompleter?.future;
    } else {
      _latestColorUpdate = DateTime.now();
      return fn();
    }
  }
}
