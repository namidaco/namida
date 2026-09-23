// by claude

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:rhttp/rhttp.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/http_response_wrapper.dart';

/// Downloads [url] into [file], resuming whatever is already on disk.
abstract class DownloadWrapper {
  DownloadWrapper({
    required this.requester,
    required this.url,
    required this.headers,
    required this.file,
    required this.totalBytes,
    required this.onProgress,
  });

  final HttpClientWrapper requester;
  final Uri url;
  final Map<String, String>? headers;
  final File file;

  /// expected size of the resource, 0 when unknown.
  final int totalBytes;

  /// bytes secured since the last call, negative when previously reported bytes had to be discarded.
  final void Function(int bytesDelta) onProgress;

  /// retries per request, for short network hiccups. longer outages are handled by callers.
  static const _kMaxRetries = 5;

  /// max idle duration between 2 chunks before considering the connection stalled.
  static const _kStallTimeout = Duration(seconds: 30);

  final _activeTokens = <CancelToken>{};
  final _stopCompleter = Completer<void>();
  bool _stopped = false;
  bool _canceled = false;

  bool get isCanceled => _canceled;

  /// completes once [file] holds the whole resource, throws [DownloadCanceledException] after [cancel],
  /// or the last error once retries are exhausted.
  Future<void> download();

  /// aborts ongoing requests, [download] then throws [DownloadCanceledException].
  void cancel() {
    _canceled = true;
    _stop();
  }

  void _stop() {
    if (_stopped) return;
    _stopped = true;
    _stopCompleter.complete();
    for (final token in _activeTokens) {
      token.cancel();
    }
    _activeTokens.clear();
  }

  /// 1s, 2s, 4s, 8s, then 10s.
  static Duration _retryBackoff(int attempt) {
    const maxSeconds = 10;
    return Duration(seconds: attempt >= 4 ? maxSeconds : 1 << attempt);
  }

  static bool _isRetryable(Object e) {
    if (e is RhttpStatusCodeException) return e.statusCode >= 500 || e.statusCode == 408 || e.statusCode == 429;
    return e is _IncompleteRangeException ||
        e is TimeoutException ||
        e is SocketException ||
        e is HandshakeException ||
        e is HttpException ||
        e is RhttpTimeoutException ||
        e is RhttpConnectionException ||
        e is RhttpUnknownException;
  }

  static int _sizeSync(FileSystemEntity entity) {
    final stat = entity.statSync();
    return stat.type == FileSystemEntityType.notFound ? 0 : stat.size;
  }

  static Future<void> _closeSink(IOSink sink) async {
    try {
      await sink.flush();
    } catch (_) {}
    try {
      await sink.close();
    } catch (_) {}
  }

  /// appends bytes `[targetBaseOffset + target size, end)` to [target], [end] null means till the resource end.
  /// with an [end], any reply not matching the requested range throws [DownloadChunkingNotSupportedException],
  /// without it a non 206 reply to a resumed request rewrites [target] from scratch.
  Future<void> _downloadRange({
    required File target,
    required int targetBaseOffset,
    required int? end,
    required void Function(int bytesDelta, int targetSize) onWritten,
  }) async {
    for (int attempt = 0; ; attempt++) {
      if (_stopped) throw const DownloadCanceledException();

      int targetSize = _sizeSync(target);
      final start = targetBaseOffset + targetSize;
      if (end != null && start >= end) return;

      final cancelToken = CancelToken();
      _activeTokens.add(cancelToken);
      IOSink? sink;
      bool requestFinished = false;
      try {
        final rangeHeader = end == null ? 'bytes=$start-' : 'bytes=$start-${end - 1}';
        final response = await requester.getStream(url.toString(), headers: {...?headers, 'range': rangeHeader}, cancelToken: cancelToken);

        var writeMode = FileMode.writeOnlyAppend;
        if (end != null) {
          if (response.statusCode != 206 || !_contentRangeMatches(response.headers, start)) throw const DownloadChunkingNotSupportedException();
        } else if (response.statusCode != 206 && targetSize > 0) {
          // -- server didnt honor our range request, restarting from scratch to not corrupt the file.
          onWritten(-targetSize, 0);
          targetSize = 0;
          writeMode = FileMode.writeOnly;
        }

        final expectedBytes = end == null ? null : end - start;
        int writtenBytes = 0;
        sink = target.openWrite(mode: writeMode);
        await for (final data in response.body.timeout(_kStallTimeout)) {
          writtenBytes += data.length;
          if (expectedBytes != null && writtenBytes > expectedBytes) throw const DownloadChunkingNotSupportedException();
          sink.add(data);
          targetSize += data.length;
          onWritten(data.length, targetSize);
        }
        await sink.flush();
        await sink.close();
        sink = null;
        requestFinished = true;
        if (expectedBytes != null && writtenBytes < expectedBytes) throw const _IncompleteRangeException();
        return;
      } on RhttpCancelException {
        throw const DownloadCanceledException();
      } catch (e) {
        if (_stopped) throw const DownloadCanceledException();
        if (e is RhttpStatusCodeException && e.statusCode == 416) {
          if (end != null) throw const DownloadChunkingNotSupportedException();
          final contentRange = _contentRange(e.headers);
          if (start > 0 && contentRange != null && _contentRangeTotal(contentRange) == start) return; // -- was already complete, its size wasnt known
        }
        if (attempt >= _kMaxRetries || !_isRetryable(e)) {
          if (e is _IncompleteRangeException) throw const DownloadChunkingNotSupportedException();
          rethrow;
        }
      } finally {
        _activeTokens.remove(cancelToken);
        if (!requestFinished) cancelToken.cancel();
        if (sink != null) await _closeSink(sink);
      }
      await Future.any([Future<void>.delayed(_retryBackoff(attempt)), _stopCompleter.future]);
    }
  }

  static String? _contentRange(List<(String, String)> headers) {
    for (final (name, value) in headers) {
      if (name == 'content-range') return value;
    }
    return null;
  }

  static int? _contentRangeTotal(String contentRange) => int.tryParse(contentRange.substring(contentRange.lastIndexOf('/') + 1).trim());

  /// false when a content-range header reports another start or resource size than requested.
  bool _contentRangeMatches(List<(String, String)> headers, int start) {
    final value = _contentRange(headers);
    if (value == null) return true;
    const unit = 'bytes ';
    final dash = value.indexOf('-');
    final slash = value.lastIndexOf('/');
    if (!value.startsWith(unit) || dash == -1 || slash < dash) return false;
    if (int.tryParse(value.substring(unit.length, dash)) != start) return false;
    final total = _contentRangeTotal(value);
    return total == null || total == totalBytes;
  }
}

class SingleThreadedDownloadWrapper extends DownloadWrapper {
  SingleThreadedDownloadWrapper({
    required super.requester,
    required super.url,
    required super.headers,
    required super.file,
    required super.totalBytes,
    required super.onProgress,
  });

  @override
  Future<void> download() {
    return _downloadRange(
      target: file,
      targetBaseOffset: 0,
      end: null,
      onWritten: (bytesDelta, _) => onProgress(bytesDelta),
    );
  }
}

/// Downloads [chunkSize] sized chunks over up to [threads] connections, then appends them in order to [file].
///
/// [file] only grows by whole chunks so it always holds a valid prefix, and each `<index>.part`
/// holds the bytes from `index * chunkSize`, so everything resumes from file sizes alone.
class MultiThreadedDownloadWrapper extends DownloadWrapper {
  MultiThreadedDownloadWrapper({
    required super.requester,
    required super.url,
    required super.headers,
    required super.file,
    required super.totalBytes,
    required super.onProgress,
    required this.threads,
    required this.chunkSize,
  });

  final int threads;
  final int chunkSize;

  static const _kPartExtension = '.part';
  static const _kCopyBufferSize = 1 << 20;

  static String _partsDirectoryPath(String filePath) => '$filePath.parts';

  static int partsSizeSync(String filePath) {
    int size = 0;
    try {
      for (final entity in Directory(_partsDirectoryPath(filePath)).listSync()) {
        if (entity is File) size += DownloadWrapper._sizeSync(entity);
      }
    } catch (_) {}
    return size;
  }

  static Future<void> deleteParts(String filePath) => Directory(_partsDirectoryPath(filePath)).delete(recursive: true);

  static void deletePartsSync(String filePath) {
    try {
      Directory(_partsDirectoryPath(filePath)).deleteSync(recursive: true);
    } catch (_) {}
  }

  static int? _parsePartIndex(File part) {
    final name = part.uri.pathSegments.last;
    if (!name.endsWith(_kPartExtension)) return null;
    return int.tryParse(name.substring(0, name.length - _kPartExtension.length));
  }

  late final _partsDir = Directory(_partsDirectoryPath(file.path));
  late final _chunkCount = (totalBytes + chunkSize - 1) ~/ chunkSize;
  late final _copyBuffer = Uint8List(_kCopyBufferSize);

  final _workers = <int, Future<void>>{};
  Completer<void> _wakeUp = Completer<void>();
  Object? _failure;

  int _reportedBytes = 0;

  int _chunkLength(int index) => math.min(chunkSize, totalBytes - index * chunkSize);
  File _partFile(int index) => File(FileParts.joinPath(_partsDir.path, '$index$_kPartExtension'));

  void _report(int bytesDelta) {
    if (bytesDelta == 0) return;
    _reportedBytes += bytesDelta;
    onProgress(bytesDelta);
  }

  @override
  Future<void> download() async {
    if (_stopped) throw const DownloadCanceledException();
    final initialCommitted = DownloadWrapper._sizeSync(file);
    int committed = initialCommitted;
    if (committed >= totalBytes) return;

    try {
      final partsSizes = _discoverParts(committed);
      int nextIndex = committed ~/ chunkSize;
      while (!_stopped) {
        committed = await _appendReadyParts(committed);
        if (committed >= totalBytes || _stopped) break;

        while (_workers.length < threads && nextIndex < _chunkCount) {
          final index = nextIndex++;
          if (partsSizes[index] == _chunkLength(index)) continue;
          _startWorker(index, initialCommitted);
        }
        if (_workers.isEmpty) throw StateError('no chunk left to download while file is incomplete');

        _wakeUp = Completer<void>();
        await _wakeUp.future;
      }
    } catch (e) {
      _failure ??= e;
    }

    if (_failure != null) _stop();
    await Future.wait(_workers.values.toList());

    if (_canceled) throw const DownloadCanceledException();
    final failure = _failure;
    if (failure == null) {
      deletePartsSync(file.path);
      return;
    }
    if (failure is DownloadChunkingNotSupportedException) {
      // -- chunks contents are suspect, reported progress goes back to what the file holds.
      deletePartsSync(file.path);
      _report((DownloadWrapper._sizeSync(file) - initialCommitted) - _reportedBytes);
    }
    throw failure;
  }

  /// deletes stale or corrupt parts, reports the bytes the remaining ones secure.
  Map<int, int> _discoverParts(int committed) {
    try {
      _partsDir.createSync(recursive: true);
    } catch (_) {
      throw const DownloadChunkingNotSupportedException();
    }
    final partsSizes = <int, int>{};
    final lowestIndex = committed ~/ chunkSize;
    final committedInLowest = committed - lowestIndex * chunkSize;
    for (final entity in _partsDir.listSync()) {
      if (entity is! File) continue;
      final index = _parsePartIndex(entity);
      if (index == null) continue;
      final size = DownloadWrapper._sizeSync(entity);
      if (index < lowestIndex || index >= _chunkCount || size > _chunkLength(index)) {
        _deleteSync(entity);
        continue;
      }
      partsSizes[index] = size;
      final securedBytes = index == lowestIndex ? size - committedInLowest : size;
      if (securedBytes > 0) _report(securedBytes);
    }
    return partsSizes;
  }

  void _startWorker(int index, int initialCommitted) {
    _workers[index] = _runWorker(index, initialCommitted).whenComplete(() {
      _workers.remove(index);
      if (!_wakeUp.isCompleted) _wakeUp.complete();
    });
  }

  Future<void> _runWorker(int index, int initialCommitted) async {
    final start = index * chunkSize;
    final bytesAlreadyInFile = math.max<int>(0, initialCommitted - start);
    try {
      await _downloadRange(
        target: _partFile(index),
        targetBaseOffset: start,
        end: start + _chunkLength(index),
        onWritten: (bytesDelta, partSize) {
          final securedBytes = partSize - math.max<int>(partSize - bytesDelta, bytesAlreadyInFile);
          if (securedBytes > 0) _report(securedBytes);
        },
      );
    } catch (e) {
      if (_stopped) return;
      _failure = e;
      _stop();
    }
  }

  Future<int> _appendReadyParts(int committed) async {
    while (committed < totalBytes) {
      final index = committed ~/ chunkSize;
      if (_workers.containsKey(index)) break;
      final part = _partFile(index);
      final length = _chunkLength(index);
      if (DownloadWrapper._sizeSync(part) != length) break;
      await _appendPart(part, committed - index * chunkSize);
      committed = index * chunkSize + length;
      _deleteSync(part);
    }
    return committed;
  }

  Future<void> _appendPart(File part, int fromOffset) async {
    final source = await part.open(mode: FileMode.read);
    try {
      final sink = await file.open(mode: FileMode.append);
      try {
        await source.setPosition(fromOffset);
        final buffer = _copyBuffer;
        while (true) {
          final read = await source.readInto(buffer);
          if (read <= 0) break;
          await sink.writeFrom(buffer, 0, read);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      await source.close();
    }
  }

  static void _deleteSync(FileSystemEntity entity) {
    try {
      entity.deleteSync();
    } catch (_) {}
  }
}

class DownloadCanceledException implements Exception {
  const DownloadCanceledException();
}

class DownloadChunkingNotSupportedException implements Exception {
  const DownloadChunkingNotSupportedException();
}

class _IncompleteRangeException implements Exception {
  const _IncompleteRangeException();
}
