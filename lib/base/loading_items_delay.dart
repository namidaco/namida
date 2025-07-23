import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';

mixin LoadingItemsDelayMixin<T extends StatefulWidget> on State<T> {
  /// creates a completer that checks wether the widget is mounted or not.
  int get itemsLoadingdelayMS => 300;

  Timer? _loadingDelayTimer;
  Completer<bool>? _loadingDelayCompleter;

  Future<bool> canStartLoadingItems({int? delayMS}) async {
    if (!mounted) return false;
    final shouldDelayLoading = Scrollable.recommendDeferredLoadingForContext(context);
    if (!shouldDelayLoading) return true;
    if (itemsLoadingdelayMS == 0) return false;

    _loadingDelayCompleter ??= Completer<bool>();
    _loadingDelayTimer ??= Timer(Duration(milliseconds: delayMS ?? itemsLoadingdelayMS), () {
      _fillResults(mounted);
    });
    return await _loadingDelayCompleter?.future ?? false;
  }

  void _fillResults(bool canLoad) {
    _loadingDelayTimer?.cancel();
    _loadingDelayTimer = null;
    _loadingDelayCompleter?.completeIfWasnt(canLoad);
    _loadingDelayCompleter = null;
  }

  @override
  void dispose() {
    _fillResults(false);
    super.dispose();
  }
}

@Deprecated('use LoadingItemsDelayMixin instead')
mixin LoadingItemsDelayMixinSimple<T extends StatefulWidget> on State<T> {
  bool canStartLoadingItems() {
    if (!mounted) return false;
    final shouldDelayLoading = Scrollable.recommendDeferredLoadingForContext(context);
    return !shouldDelayLoading;
  }
}
