import 'dart:async';
import 'dart:collection';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';

// rewrite by claude
class YoutubeParallelDownloadsHandler {
  static final YoutubeParallelDownloadsHandler inst = YoutubeParallelDownloadsHandler._internal();
  YoutubeParallelDownloadsHandler._internal();

  /// queued or running tasks.
  final _tasks = <DownloadTaskFilename, _ParallelDownloadTask>{};
  final _queue = Queue<_ParallelDownloadTask>();
  int _runningCount = 0;

  void setMaxParallelDownloads(int count) {
    settings.youtube.save(downloadParallelCount: count.withMinimum(1));
    _startQueued();
  }

  /// Queues [config] to be downloaded once a slot is free, completes when it's downloaded or skipped.
  ///
  /// [shouldSkip] is checked right before starting, to drop tasks that got paused/canceled while queued.
  Future<void> add({
    required YoutubeItemDownloadConfig config,
    required bool Function(YoutubeItemDownloadConfig config) shouldSkip,
    required Future<void> Function(YoutubeItemDownloadConfig config) download,
  }) {
    final filename = config.filename;
    final existing = _tasks[filename];
    if (existing != null) {
      if (identical(existing.config, config)) return existing.completer.future;

      if (!existing.isRunning) {
        existing
          ..config = config
          ..shouldSkip = shouldSkip
          ..download = download;
        return existing.completer.future;
      }

      // -- replaced while running, the old one is being stopped so we wait for it to fully finish first.
      return existing.completer.future.then((_) => add(config: config, shouldSkip: shouldSkip, download: download));
    }

    final task = _tasks[filename] = _ParallelDownloadTask(config, shouldSkip, download);
    _queue.add(task);
    _startQueued();
    return task.completer.future;
  }

  void _startQueued() {
    final maxCount = settings.youtube.downloadParallelCount.valueF;
    while (_runningCount < maxCount && _queue.isNotEmpty) {
      final task = _queue.removeFirst();
      if (task.shouldSkip(task.config)) {
        _finish(task);
      } else {
        _run(task);
      }
    }
  }

  Future<void> _run(_ParallelDownloadTask task) async {
    _runningCount++;
    task.isRunning = true;
    try {
      await task.download(task.config);
    } finally {
      _runningCount--;
      _finish(task);
      _startQueued();
    }
  }

  void _finish(_ParallelDownloadTask task) {
    _tasks.remove(task.config.filename);
    task.completer.complete();
  }
}

class _ParallelDownloadTask {
  YoutubeItemDownloadConfig config;
  bool Function(YoutubeItemDownloadConfig config) shouldSkip;
  Future<void> Function(YoutubeItemDownloadConfig config) download;

  final completer = Completer<void>();
  bool isRunning = false;

  _ParallelDownloadTask(this.config, this.shouldSkip, this.download);
}
