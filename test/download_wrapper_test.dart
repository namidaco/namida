// by claude
import 'dart:async';
import 'dart:io' show Directory, File, Platform;
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rhttp/rhttp.dart' show CancelState, CancelToken, HttpRequest, HttpStreamResponse, HttpVersion, RhttpCancelException, RhttpStatusCodeException;

import 'package:namida/class/download_wrapper.dart';
import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/controller/files_download_manager.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('namida_download_wrapper_test');
    file = File('${dir.path}${Platform.pathSeparator}file.bin');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  const chunkSize = 10;
  final source = _bytes(47);

  Directory partsDir() => Directory('${file.path}.parts');
  File partFile(int index) => File('${partsDir().path}${Platform.pathSeparator}$index.part');
  int sum(List<int> deltas) => deltas.fold(0, (a, b) => a + b);

  MultiThreadedDownloadWrapper multi(_FakeRequester requester, List<int> deltas, {int threads = 2}) {
    return MultiThreadedDownloadWrapper(
      requester: requester,
      url: _url,
      headers: null,
      file: file,
      totalBytes: source.length,
      onProgress: deltas.add,
      threads: threads,
      chunkSize: chunkSize,
    );
  }

  SingleThreadedDownloadWrapper single(_FakeRequester requester, List<int> deltas, {int? totalBytes}) {
    return SingleThreadedDownloadWrapper(
      requester: requester,
      url: _url,
      headers: null,
      file: file,
      totalBytes: totalBytes ?? source.length,
      onProgress: deltas.add,
    );
  }

  group('MultiThreadedDownloadWrapper', () {
    test('a fresh download over more threads than chunks writes the exact bytes, reports them all and leaves no parts', () async {
      final requester = _FakeRequester((range, _) => _partial(source, range));
      final deltas = <int>[];
      final wrapper = multi(requester, deltas, threads: 8);
      await wrapper.download();

      _expectBytes(file, source);
      expect(sum(deltas), source.length);
      expect(requester.requestedRanges, unorderedEquals(['bytes=0-9', 'bytes=10-19', 'bytes=20-29', 'bytes=30-39', 'bytes=40-46']));
      expect(partsDir().existsSync(), false);
    });

    test('resuming keeps the committed bytes and the valid parts, drops stale and oversized parts and downloads only what is missing', () async {
      const committedSize = 15;
      final garbage = Uint8List(12)..fillRange(0, 12, 0xEE);
      final committedPrefix = Uint8List.sublistView(source, 0, committedSize);
      final staleChunk0 = Uint8List.sublistView(garbage, 0, chunkSize);
      final completeChunk1 = Uint8List.sublistView(source, 10, 20);
      final partialChunk2 = Uint8List.sublistView(source, 20, 24);
      final oversizedChunk3 = garbage;
      file.writeAsBytesSync(committedPrefix);
      partsDir().createSync();
      partFile(0).writeAsBytesSync(staleChunk0);
      partFile(1).writeAsBytesSync(completeChunk1);
      partFile(2).writeAsBytesSync(partialChunk2);
      partFile(3).writeAsBytesSync(oversizedChunk3);

      final requester = _FakeRequester((range, _) => _partial(source, range));
      final deltas = <int>[];
      final wrapper = multi(requester, deltas);
      await wrapper.download();

      _expectBytes(file, source);
      expect(committedSize + sum(deltas), source.length);
      expect(requester.requestedRanges, unorderedEquals(['bytes=24-29', 'bytes=30-39', 'bytes=40-46']));
      expect(partsDir().existsSync(), false);
    });

    test('an already complete file makes no request', () async {
      file.writeAsBytesSync(source);
      final requester = _FakeRequester((range, _) => _partial(source, range));
      final wrapper = multi(requester, <int>[]);
      await wrapper.download();

      expect(requester.requestedRanges, isEmpty);
      _expectBytes(file, source);
      expect(partsDir().existsSync(), false);
    });

    test('cancel during the transfer throws DownloadCanceledException and keeps the parts', () async {
      int streamsStarted = 0;
      final bothStreamsStarted = Completer<void>();
      void onFirstPiece() {
        streamsStarted++;
        if (streamsStarted == 2) bothStreamsStarted.complete();
      }

      final requester = _FakeRequester((range, cancelToken) {
        final rangeEnd = range.end!;
        final bytes = Uint8List.sublistView(source, range.start, rangeEnd + 1);
        final body = _hangingAfterFirstPiece(bytes, cancelToken!, onFirstPiece);
        return _streamResponse(206, body, [('content-range', 'bytes ${range.start}-$rangeEnd/${source.length}')]);
      });
      final wrapper = multi(requester, <int>[]);
      final download = wrapper.download();
      await bothStreamsStarted.future;
      wrapper.cancel();

      await expectLater(download, throwsA(isA<DownloadCanceledException>()));
      expect(MultiThreadedDownloadWrapper.partsSizeSync(file.path), 2 * _kHangingPieceSize);
      expect(file.existsSync(), false);
    });

    test('a chunk answered without range support drops the parts and rolls the progress back to the file size', () async {
      final committedChunk0 = Uint8List.sublistView(source, 0, chunkSize);
      final partialChunk1 = Uint8List.sublistView(source, 10, 14);
      file.writeAsBytesSync(committedChunk0);
      partsDir().createSync();
      partFile(1).writeAsBytesSync(partialChunk1);

      final requester = _FakeRequester((range, _) => _response(200, source));
      final deltas = <int>[];
      final wrapper = multi(requester, deltas);
      await expectLater(wrapper.download(), throwsA(isA<DownloadChunkingNotSupportedException>()));

      expect(sum(deltas), 0);
      expect(partsDir().existsSync(), false);
      expect(file.lengthSync(), chunkSize);
    });

    Future<void> expectChunkRejected(HttpStreamResponse Function(_Range range) respond) async {
      final requester = _FakeRequester((range, _) => respond(range));
      final deltas = <int>[];
      final wrapper = multi(requester, deltas);
      await expectLater(wrapper.download(), throwsA(isA<DownloadChunkingNotSupportedException>()));

      expect(sum(deltas), 0);
      expect(partsDir().existsSync(), false);
      expect(file.existsSync(), false);
    }

    test('a chunk with another content-range start is rejected before reaching the file', () async {
      await expectChunkRejected((range) {
        final shiftedStart = range.start + 1;
        final shiftedEnd = range.end! + 1;
        final body = Uint8List.sublistView(source, shiftedStart, shiftedEnd + 1);
        return _response(206, body, headers: [('content-range', 'bytes $shiftedStart-$shiftedEnd/${source.length}')]);
      });
    });

    test('a chunk with a body longer than requested is rejected before reaching the file', () async {
      await expectChunkRejected((range) {
        final rangeEnd = range.end!;
        final body = Uint8List.sublistView(source, range.start, rangeEnd + 2);
        return _response(206, body, headers: [('content-range', 'bytes ${range.start}-$rangeEnd/${source.length}')]);
      });
    });
  });

  group('SingleThreadedDownloadWrapper', () {
    const shortSize = 30;

    HttpStreamResponse shortFirstResponse(_Range range) {
      if (range.start > 0) return _partial(source, range);
      final shortBody = Uint8List.sublistView(source, 0, shortSize);
      return _response(206, shortBody, headers: [('content-range', 'bytes 0-${source.length - 1}/${source.length}')]);
    }

    test('a stream ending before the expected size is resumed from where it stopped', () async {
      final requester = _FakeRequester((range, _) => shortFirstResponse(range));
      final deltas = <int>[];
      final wrapper = single(requester, deltas);
      await wrapper.download();

      _expectBytes(file, source);
      expect(requester.requestedRanges, ['bytes=0-', 'bytes=$shortSize-']);
      expect(sum(deltas), source.length);
    });

    test('a stream ending before the expected size throws once resuming fails', () async {
      final requester = _FakeRequester((range, _) {
        if (range.start > 0) throw _statusError(404);
        return shortFirstResponse(range);
      });
      final wrapper = single(requester, <int>[]);

      await expectLater(wrapper.download(), throwsA(isA<RhttpStatusCodeException>()));
      expect(requester.requestedRanges, ['bytes=0-', 'bytes=$shortSize-']);
    });

    test('a resumed request answered with 200 rewrites the file from scratch and rolls the progress back', () async {
      const staleSize = 20;
      final staleBytes = Uint8List(staleSize)..fillRange(0, staleSize, 0xEE);
      file.writeAsBytesSync(staleBytes);
      final requester = _FakeRequester((range, _) => _response(200, source));
      final deltas = <int>[];
      final wrapper = single(requester, deltas);
      await wrapper.download();

      _expectBytes(file, source);
      expect(deltas.first, -staleSize);
      expect(staleSize + sum(deltas), source.length);
    });

    test('416 reporting the current size as the total completes a download of unknown size', () async {
      file.writeAsBytesSync(source);
      final requester = _FakeRequester((range, _) => throw _statusError(416, headers: [('content-range', 'bytes */${source.length}')]));
      final deltas = <int>[];
      final wrapper = single(requester, deltas, totalBytes: 0);
      await wrapper.download();

      _expectBytes(file, source);
      expect(deltas, isEmpty);
      expect(requester.requestedRanges, ['bytes=${source.length}-']);
    });
  });

  group('FilesDownloadManager download run', () {
    final bigSource = _bytes(_kManagerChunkSize + 100 * 1024);
    String moveToPath() => '${dir.path}${Platform.pathSeparator}moved.bin';

    Future<(Object?, int)> runDownload(_FakeRequester requester, {required int totalBytes, required int threads, String? moveTo, int? moveToRequiredBytes}) async {
      final port = ReceivePort();
      int progress = 0;
      final allProgressReceived = Completer<void>();
      port.listen((message) {
        if (message == null) return allProgressReceived.complete();
        progress += message as int;
      });
      final result = await FilesDownloadManager.debugRunDownload(requester, {
        'url': _url,
        'headers': null,
        'filePath': file.path,
        'totalBytes': totalBytes,
        'threads': threads,
        'moveTo': moveTo,
        'moveToRequiredBytes': moveToRequiredBytes,
        'progressPort': port.sendPort,
      });
      port.sendPort.send(null);
      await allProgressReceived.future;
      port.close();
      return (result, progress);
    }

    test('a chunk answered with 200 falls back to one connection resuming from the whole-chunk prefix', () async {
      const committedSize = _kManagerChunkSize;
      const partSize = 50 * 1024;
      final committedChunk0 = Uint8List.sublistView(bigSource, 0, committedSize);
      final partialChunk1 = Uint8List.sublistView(bigSource, committedSize, committedSize + partSize);
      file.writeAsBytesSync(committedChunk0);
      partsDir().createSync();
      partFile(1).writeAsBytesSync(partialChunk1);

      final requester = _FakeRequester((range, _) {
        if (range.end == null) return _partial(bigSource, range, pieceSize: _kBigPieceSize);
        return _response(200, bigSource, pieceSize: _kBigPieceSize);
      });
      final (result, progress) = await runDownload(requester, totalBytes: bigSource.length, threads: 2);

      expect(result, null);
      _expectBytes(file, bigSource);
      expect(partsDir().existsSync(), false);
      expect(requester.requestedRanges, ['bytes=${committedSize + partSize}-${bigSource.length - 1}', 'bytes=$committedSize-']);
      expect(progress, bigSource.length - committedSize);
    });

    test('finishing on one connection deletes the parts of an earlier chunked attempt', () async {
      const committedSize = _kManagerChunkSize;
      const partSize = 50 * 1024;
      final committedChunk0 = Uint8List.sublistView(bigSource, 0, committedSize);
      final partialChunk1 = Uint8List.sublistView(bigSource, committedSize, committedSize + partSize);
      file.writeAsBytesSync(committedChunk0);
      partsDir().createSync();
      partFile(1).writeAsBytesSync(partialChunk1);

      final requester = _FakeRequester((range, _) => _partial(bigSource, range, pieceSize: _kBigPieceSize));
      final (result, progress) = await runDownload(requester, totalBytes: bigSource.length, threads: 1);

      expect(result, null);
      _expectBytes(file, bigSource);
      expect(partsDir().existsSync(), false);
      expect(requester.requestedRanges, ['bytes=$committedSize-']);
      expect(progress, bigSource.length - committedSize);
    });

    test('a file short of moveToRequiredBytes is reported as an error and not moved', () async {
      const expectedSize = 4096;
      const serverSize = 1000;
      final serverBytes = _bytes(serverSize);
      file.writeAsBytesSync(serverBytes);
      final requester = _FakeRequester((range, _) => throw _statusError(416, headers: [('content-range', 'bytes */$serverSize')]));
      final moveTo = moveToPath();
      final (result, _) = await runDownload(requester, totalBytes: expectedSize, threads: 1, moveTo: moveTo, moveToRequiredBytes: expectedSize);

      expect(result, isNotNull);
      expect(File(moveTo).existsSync(), false);
      expect(file.lengthSync(), serverSize);
    });

    test('an already complete file makes no request and is moved', () async {
      file.writeAsBytesSync(bigSource);
      final requester = _FakeRequester((range, _) => _partial(bigSource, range, pieceSize: _kBigPieceSize));
      final moveTo = moveToPath();
      final (result, progress) = await runDownload(requester, totalBytes: bigSource.length, threads: 2, moveTo: moveTo, moveToRequiredBytes: bigSource.length);

      expect(result, null);
      expect(requester.requestedRanges, isEmpty);
      expect(progress, 0);
      expect(file.existsSync(), false);
      _expectBytes(File(moveTo), bigSource);
    });
  });
}

class _FakeRequester implements HttpClientWrapper {
  _FakeRequester(this._respond);

  final FutureOr<HttpStreamResponse> Function(_Range range, CancelToken? cancelToken) _respond;
  final requestedRanges = <String>[];

  @override
  Future<HttpStreamResponse> getStream(String url, {Map<String, String>? headers, required CancelToken? cancelToken}) async {
    final rangeHeader = headers!['range']!;
    requestedRanges.add(rangeHeader);
    final value = rangeHeader.substring('bytes='.length);
    final dash = value.indexOf('-');
    final start = int.parse(value.substring(0, dash));
    final end = int.tryParse(value.substring(dash + 1));
    return _respond((start: start, end: end), cancelToken);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// mirrors `FilesDownloadManager._kChunkSize`, multi threading starts above it.
const _kManagerChunkSize = 8 * 1024 * 1024;
const _kBigPieceSize = 64 * 1024;
const _kHangingPieceSize = 4;

final _url = Uri.parse('https://example.com/file.bin');
final _request = HttpRequest(url: 'https://example.com/file.bin');

Uint8List _bytes(int length) {
  final bytes = Uint8List(length);
  int seed = 0x2545F491;
  for (int i = 0; i < length; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
    bytes[i] = seed >> 16;
  }
  return bytes;
}

void _expectBytes(File file, Uint8List expected) {
  final actual = file.readAsBytesSync();
  expect(actual.length, expected.length);
  int firstMismatch = -1;
  for (int i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) {
      firstMismatch = i;
      break;
    }
  }
  expect(firstMismatch, -1);
}

Stream<Uint8List> _pieces(Uint8List bytes, int pieceSize) async* {
  for (int i = 0; i < bytes.length; i += pieceSize) {
    final end = math.min(i + pieceSize, bytes.length);
    yield Uint8List.sublistView(bytes, i, end);
  }
}

Stream<Uint8List> _hangingAfterFirstPiece(Uint8List bytes, CancelToken cancelToken, void Function() onFirstPiece) async* {
  yield Uint8List.sublistView(bytes, 0, _kHangingPieceSize);
  onFirstPiece();
  while (cancelToken.state == CancelState.idle) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw RhttpCancelException(_request);
}

HttpStreamResponse _streamResponse(int statusCode, Stream<Uint8List> body, List<(String, String)> headers) {
  return HttpStreamResponse(remoteIp: null, request: _request, version: HttpVersion.http1_1, statusCode: statusCode, headers: headers, body: body);
}

HttpStreamResponse _response(int statusCode, Uint8List body, {List<(String, String)> headers = const [], int pieceSize = 4}) {
  final pieces = _pieces(body, pieceSize);
  return _streamResponse(statusCode, pieces, headers);
}

HttpStreamResponse _partial(Uint8List source, _Range range, {int pieceSize = 4}) {
  final endExclusive = (range.end ?? source.length - 1) + 1;
  final body = Uint8List.sublistView(source, range.start, endExclusive);
  return _response(206, body, headers: [('content-range', 'bytes ${range.start}-${endExclusive - 1}/${source.length}')], pieceSize: pieceSize);
}

RhttpStatusCodeException _statusError(int statusCode, {List<(String, String)> headers = const []}) {
  return RhttpStatusCodeException(request: _request, statusCode: statusCode, headers: headers, body: null);
}

typedef _Range = ({int start, int? end});
