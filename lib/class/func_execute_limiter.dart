import 'dart:async';

import 'package:namida/core/extensions.dart';

/// Controls function that may execute rapidly, mainly to improve performance.
class FunctionExecuteLimiter<T> {
  FunctionExecuteLimiter({
    Duration considerRapid = const Duration(milliseconds: 800),
    Duration executeAfter = const Duration(milliseconds: 800),
  })  : _considerRapid = considerRapid,
        _executeAfter = executeAfter;

  final Duration _considerRapid;
  final Duration _executeAfter;

  bool get _isRapidlyCalling => DateTime.now().difference(_latestColorUpdate) < _considerRapid;
  Timer? _isRapidlyCallingTimer;
  DateTime _latestColorUpdate = DateTime(0);

  Completer<T?>? _valueCompleter;

  void execute(Function fn) {
    if (_isRapidlyCalling) {
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

  Future<T?> executeFuture(Future<T?> Function() fn) async {
    if (_isRapidlyCalling) {
      _latestColorUpdate = DateTime.now();
      _isRapidlyCallingTimer?.cancel();
      _valueCompleter?.completeIfWasnt(null);
      _valueCompleter = Completer<T?>();
      _isRapidlyCallingTimer = Timer(const Duration(milliseconds: 800), () {
        fn().then((value) => _valueCompleter?.completeIfWasnt(value));
      });
      return _valueCompleter?.future;
    } else {
      _latestColorUpdate = DateTime.now();
      return fn();
    }
  }
}
