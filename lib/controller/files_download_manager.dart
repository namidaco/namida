import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:rhttp/rhttp.dart';

import 'package:namida/class/download_wrapper.dart';
import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/core/extensions.dart';

export 'package:namida/class/download_wrapper.dart' show DownloadCanceledException;

/// Resumable downloads running in a shared isolate.
class FilesDownloadManager with PortsProvider<SendPort> {
  static final inst = FilesDownloadManager._();
  FilesDownloadManager._();

  final _downloadCompleters = <String, Completer<Object?>?>{}; // file path
  final _progressPorts = <String, RawReceivePort?>{}; // file path
  final _downloadIds = <String, int>{}; // file path
  int _lastDownloadId = 0;

  static const _kMultiThreaded = true;
  static const _kChunkSize = 8 * 1024 * 1024;

  /// progress is batched, sending each chunk floods the main isolate, especially with parallel downloads.
  static const _kProgressReportIntervalMs = 100;

  static DownloadWrapper _createWrapper({
    required HttpClientWrapper requester,
    required Uri url,
    required Map<String, String>? headers,
    required File file,
    required int totalBytes,
    required void Function(int bytesDelta) onProgress,
    required int threads,
  }) {
    if (_kMultiThreaded && threads > 1 && totalBytes > _kChunkSize) {
      return MultiThreadedDownloadWrapper(
        requester: requester,
        url: url,
        headers: headers,
        file: file,
        totalBytes: totalBytes,
        onProgress: onProgress,
        threads: threads,
        chunkSize: _kChunkSize,
      );
    }
    return SingleThreadedDownloadWrapper(
      requester: requester,
      url: url,
      headers: headers,
      file: file,
      totalBytes: totalBytes,
      onProgress: onProgress,
    );
  }

  static int chunksSizeSync(String filePath) => MultiThreadedDownloadWrapper.partsSizeSync(filePath);

  static void deleteDownloadFiles(File file) {
    file.delete().ignoreError();
    MultiThreadedDownloadWrapper.deleteParts(file.path).ignoreError();
  }

  /// [threads] above 1 download over several connections, which needs the expected size in [totalBytes].
  /// if [file] is temp, u can provide [moveTo] to move/rename the temp file to it.
  Future<Object?> download({
    required Uri? url,
    Map<String, String>? headers,
    required File file,
    int totalBytes = 0,
    int threads = 1,
    String? moveTo,
    int? moveToRequiredBytes,
    required void Function(int downloadedBytesLength) downloadingStream,
  }) async {
    if (url == null || url.host.isEmpty) return Exception('Host Empty. url: ${url.toString()}');

    final filePath = file.path;
    if (_downloadCompleters[filePath] != null) return _downloadCompleters[filePath]!.future;
    _downloadCompleters[filePath]?.completeIfWasnt(null);
    _downloadCompleters[filePath] = Completer<Object?>();
    final id = _downloadIds[filePath] = ++_lastDownloadId;

    _progressPorts[filePath]?.close();
    final progressPort = _progressPorts[filePath] = RawReceivePort((message) {
      downloadingStream(message as int);
    });
    final p = {
      'id': id,
      'url': url,
      'headers': headers,
      'filePath': filePath,
      'totalBytes': totalBytes,
      'threads': threads,
      'moveTo': moveTo,
      'moveToRequiredBytes': moveToRequiredBytes,
      'progressPort': progressPort.sendPort,
    };
    if (!isInitialized) await initialize();
    await sendPort(p);
    final res = await _downloadCompleters[filePath]?.future;
    _onFileFinish(filePath, res);
    return res;
  }

  Future<void> stopDownload({required File? file}) async {
    if (file == null) return;
    final filePath = file.path;
    _onFileFinish(filePath, const DownloadCanceledException());
    final p = {
      'files': [file],
      'stop': true,
    };
    await sendPort(p);
  }

  Future<void> stopDownloads({required List<File> files}) async {
    if (files.isEmpty) return;
    for (var e in files) {
      _onFileFinish(e.path, const DownloadCanceledException());
    }
    final p = {'files': files, 'stop': true};
    await sendPort(p);
  }

  static void _prepareDownloadResources(SendPort sendPort) async {
    await Rhttp.init();
    final requester = HttpClientWrapper.createSync();

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    final activeDownloads = <String, _ActiveDownload>{}; // filePath

    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (p == PortsProviderMessages.disposed) {
        for (final download in activeDownloads.values) {
          download.wrapper.cancel();
        }
        activeDownloads.clear();
        recievePort.close();
        streamSub?.cancel();
        return;
      }

      p as Map;
      final stop = p['stop'] as bool?;
      if (stop == true) {
        final files = p['files'] as List<File>?;
        if (files != null) {
          for (final file in files) {
            activeDownloads[file.path]?.wrapper.cancel();
          }
        }
        return;
      }

      final filePath = p['filePath'] as String;
      Object? exception;
      try {
        exception = await _runDownload(requester, activeDownloads, p);
      } catch (e) {
        exception = e; // general error
      }
      final id = p['id'] as int;
      try {
        sendPort.send((filePath, id, exception));
      } catch (_) {
        // -- the exception holds isolate bound objects (ex: rhttp request cancel token).
        sendPort.send((filePath, id, _DownloadErrorMessage(exception.toString())));
      }
    });

    sendPort.send(PortsProviderMessages.prepared);
  }

  /// null when the file was fully downloaded (and moved), the error otherwise.
  static Future<Object?> _runDownload(HttpClientWrapper requester, Map<String, _ActiveDownload> activeDownloads, Map p) async {
    final filePath = p['filePath'] as String;
    final url = p['url'] as Uri;
    final headers = p['headers'] as Map<String, String>?;
    final totalBytes = p['totalBytes'] as int;
    final threads = p['threads'] as int;
    final moveTo = p['moveTo'] as String?;
    final moveToRequiredBytes = p['moveToRequiredBytes'] as int?;
    final progressPort = p['progressPort'] as SendPort;

    final file = File(filePath);
    file.createSync(recursive: true);

    int pendingProgress = 0;
    final progressStopwatch = Stopwatch()..start();
    void flushProgress() {
      if (pendingProgress == 0) return;
      progressPort.send(pendingProgress);
      pendingProgress = 0;
    }

    void onProgress(int bytesDelta) {
      pendingProgress += bytesDelta;
      if (progressStopwatch.elapsedMilliseconds >= _kProgressReportIntervalMs) {
        flushProgress();
        progressStopwatch.reset();
      }
    }

    DownloadWrapper createWrapper(int threadsCount) => _createWrapper(
      requester: requester,
      url: url,
      headers: headers,
      file: file,
      totalBytes: totalBytes,
      onProgress: onProgress,
      threads: threadsCount,
    );

    final active = _ActiveDownload(createWrapper(threads));
    final previous = activeDownloads[filePath];
    activeDownloads[filePath] = active;
    if (previous != null) {
      // -- registered before waiting, so a stop arriving meanwhile still reaches this download.
      previous.wrapper.cancel();
      await previous.done;
    }

    Object? downloadException;
    try {
      try {
        await active.wrapper.download();
      } on DownloadChunkingNotSupportedException {
        if (active.wrapper.isCanceled) rethrow;
        active.wrapper = createWrapper(1);
        await active.wrapper.download();
      }
    } catch (e) {
      downloadException = e;
    } finally {
      active.finish();
      if (identical(activeDownloads[filePath], active)) activeDownloads.remove(filePath);
    }

    flushProgress();
    if (downloadException != null) return downloadException;

    if (threads > 1 && totalBytes > _kChunkSize && active.wrapper is SingleThreadedDownloadWrapper) {
      MultiThreadedDownloadWrapper.deletePartsSync(filePath); // -- leftovers of an earlier chunked attempt
    }

    Object? movedException;
    if (moveTo != null && moveToRequiredBytes != null) {
      try {
        final fileSize = file.fileSizeSync() ?? 0;
        const allowance = 1024; // 1KB allowance
        if (fileSize >= moveToRequiredBytes - allowance) {
          final movedFile = file.moveSync(
            moveTo,
            goodBytesIfCopied: (fileLength) => fileLength >= moveToRequiredBytes - allowance,
          );
          if (movedFile == null) {
            movedException = FileSystemException("Error moving $file to $moveTo");
          }
        }
      } catch (e) {
        movedException = e;
      }
    }
    return movedException;
  }

  @override
  void onResult(dynamic result) {
    if (result is (String, int, Object?)) {
      final (path, id, exception) = result;
      if (_downloadIds[path] == id) _onFileFinish(path, exception); // -- stale results of a replaced download are dropped
    }
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_prepareDownloadResources, port);
  }

  void _onFileFinish(String path, Object? exception) {
    _downloadIds.remove(path);
    _downloadCompleters[path]?.completeIfWasnt(exception);
    _downloadCompleters[path] = null; // important
    _progressPorts[path]?.close();
    _progressPorts[path] = null;
  }
}

class _ActiveDownload {
  _ActiveDownload(this.wrapper);

  DownloadWrapper wrapper;
  final _doneCompleter = Completer<void>();

  Future<void> get done => _doneCompleter.future;

  void finish() => _doneCompleter.complete();
}

class _DownloadErrorMessage implements Exception {
  const _DownloadErrorMessage(this.message);

  final String message;

  @override
  String toString() => message;
}
