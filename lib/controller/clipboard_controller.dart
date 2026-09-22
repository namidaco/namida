import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:namida/core/utils.dart';

class ClipboardController {
  static ClipboardController get inst => _instance;
  static final ClipboardController _instance = ClipboardController._internal();
  ClipboardController._internal();

  AppLifecycleListener? _lifecycleListener;

  /// no platform notifies of clipboard changes, but a copy made elsewhere is always followed by a resume.
  void setClipboardMonitoringStatus(bool monitor) {
    if (monitor) {
      _lifecycleListener ??= AppLifecycleListener(onResume: _checkClipboardChanged);
      _checkClipboardChanged();
    } else {
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
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

  /// in-app copies never go through a resume.
  void onCopiedInternally(String text) {
    if (_lifecycleListener != null) _clipboardText.value = text;
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
