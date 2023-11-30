import 'dart:async';

import 'package:get/get_rx/get_rx.dart';

import 'package:namida/core/extensions.dart';

class YoutubeParallelDownloadsHandler {
  static final YoutubeParallelDownloadsHandler inst = YoutubeParallelDownloadsHandler._internal();
  YoutubeParallelDownloadsHandler._internal();

  /// Use this to wait till a place has been freed.
  Future<void>? get waitForParallelCompleter => _maxParallelDownloadsCompleter?.future;

  /// Max number of items that can be downloaded simultaniously.
  int get maxParallelDownloadingItems => _maxParallelDownloadingItems.value;

  void refreshCompleterStatus() => _tryReAssignMaxParallelDownloadsCompleter();

  int _currentDownloadingItemsCount = 0;
  final _maxParallelDownloadingItems = 1.obs;

  /// used to control the parallel process, stopping the download loop or continuing it.
  Completer<void>? _maxParallelDownloadsCompleter;

  /// updates the current downloading items number, and triggering completer re-assign
  /// which either stops ongoing downloads or continues them.
  set currentDownloadingItemsCount(int value) {
    _currentDownloadingItemsCount = value;
    _tryReAssignMaxParallelDownloadsCompleter();
  }

  void inc() => currentDownloadingItemsCount = _currentDownloadingItemsCount + 1;
  void dec() => currentDownloadingItemsCount = _currentDownloadingItemsCount - 1;

  void setMaxParalellDownloads(int count) {
    _maxParallelDownloadingItems.value = count.withMinimum(1);
    _tryReAssignMaxParallelDownloadsCompleter();
  }

  void _tryReAssignMaxParallelDownloadsCompleter() {
    if (_currentDownloadingItemsCount >= _maxParallelDownloadingItems.value) {
      _maxParallelDownloadsCompleter ??= Completer<void>();
    } else {
      _maxParallelDownloadsCompleter?.completeIfWasnt();
      _maxParallelDownloadsCompleter = null;
    }
  }
}
