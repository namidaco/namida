import 'dart:async';

import 'package:flutter/services.dart';
import 'package:namida/core/utils.dart';

class ClipboardController {
  static ClipboardController get inst => _instance;
  static final ClipboardController _instance = ClipboardController._internal();
  ClipboardController._internal();

  Timer? _timer;

  void setClipboardMonitoringStatus(bool monitor) {
    _timer?.cancel();
    _timer = null;

    if (monitor) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _checkClipboardChanged();
      });
    } else {
      _textInControllerEmpty.value = true;
      _lastCopyUsed.value = '';
      _clipboardText.value = '';
    }
  }

  void _checkClipboardChanged() async {
    final newClipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = newClipboardData?.text ?? '';
    _clipboardText.value = text;
  }

  void setLastPasted(String val) {
    _lastCopyUsed.value = val;
  }

  void updateTextInControllerEmpty(bool empty) {
    _textInControllerEmpty.value = empty;
  }

  RxBaseCore<bool> get textInControllerEmpty => _textInControllerEmpty;
  final _textInControllerEmpty = true.obs;

  RxBaseCore<String> get lastCopyUsed => _lastCopyUsed;
  final _lastCopyUsed = ''.obs;

  RxBaseCore<String> get clipboardText => _clipboardText;
  final _clipboardText = ''.obs;
}
