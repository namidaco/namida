// by claude
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/controller/sync_manager/sync_manager.dart';

void main() {
  const kindJson = 0;
  const kindBinary = 1;

  Uint8List frameOf(int kind, List<int> payload) {
    final length = payload.length + 1;
    return Uint8List.fromList([(length >> 24) & 0xFF, (length >> 16) & 0xFF, (length >> 8) & 0xFF, length & 0xFF, kind, ...payload]);
  }

  Uint8List streamOf(List<(int, List<int>)> frames) {
    final bytes = frames.expand((e) => frameOf(e.$1, e.$2)).toList();
    return Uint8List.fromList(bytes);
  }

  int lengthOfFirst(List<(int, List<int>)> frames, int count) => frames.take(count).fold(0, (sum, e) => sum + frameOf(e.$1, e.$2).length);

  List<int> jsonPayload(String fill, int count) => utf8.encode('{"m":"${fill * count}"}');
  List<int> binaryPayload(int size, int seed) => List.generate(size, (i) => (i * 31 + seed) % 256);

  List<Uint8List> splitAt(Uint8List bytes, List<int> offsets) {
    final chunks = <Uint8List>[];
    int start = 0;
    for (final end in [...offsets, bytes.length]) {
      chunks.add(Uint8List.sublistView(bytes, start, end));
      start = end;
    }
    return chunks;
  }

  /// feeds [chunks] the way the dart:io read loop does, each next read runs as a microtask right after the previous one.
  /// json payloads are copied on delivery since the real listener decodes them right away, binary ones are kept as delivered.
  Future<({List<(int, List<int>)> frames, List<Object> errors})> read(List<Uint8List> chunks, {bool closeAfter = false, bool isPaired = true}) async {
    final reader = debugCreateFrameReader(isPaired: isPaired);
    final frames = <(int, List<int>)>[];
    final errors = <Object>[];
    reader.frames.listen(
      (frame) {
        final (kind, payload) = frame;
        final keptPayload = kind == kindJson ? Uint8List.fromList(payload) : payload;
        frames.add((kind, keptPayload));
      },
      onError: errors.add,
    );
    void feed(int index) {
      reader.addBytes(chunks[index]);
      final nextIndex = index + 1;
      if (nextIndex < chunks.length) {
        scheduleMicrotask(() => feed(nextIndex));
      } else if (closeAfter) {
        reader.close();
      }
    }

    feed(0);
    await Future<void>.delayed(Duration.zero);
    return (frames: frames, errors: errors);
  }

  void expectFrames(List<(int, List<int>)> actual, List<(int, List<int>)> expected, {String reason = ''}) {
    final actualKinds = actual.map((e) => e.$1).toList();
    final expectedKinds = expected.map((e) => e.$1).toList();
    expect(actualKinds, expectedKinds, reason: reason);
    for (int i = 0; i < expected.length; i++) {
      expect(actual[i].$2, expected[i].$2, reason: '$reason frame #$i');
    }
  }

  test('json frames stay intact when the next read lands before they are delivered', () async {
    final frames = [
      (kindJson, jsonPayload('a', 300)),
      (kindJson, jsonPayload('b', 300)),
      (kindJson, jsonPayload('d', 1500)),
      (kindJson, jsonPayload('e', 3000)),
      ...List.generate(4, (i) => (kindJson, jsonPayload('$i', 1200))),
    ];
    final firstReadEnd = lengthOfFirst(frames, 3) + 2000;
    final result = await read(splitAt(streamOf(frames), [firstReadEnd]));
    expectFrames(result.frames, frames);
  });

  test('a read ending exactly on a frame boundary keeps the frames it carried', () async {
    final frames = List.generate(5, (i) => (kindJson, jsonPayload('$i', 200)));
    final firstReadEnd = lengthOfFirst(frames, 3);
    final result = await read(splitAt(streamOf(frames), [firstReadEnd]));
    expectFrames(result.frames, frames);
  });

  final mixedFrames = [
    (kindJson, jsonPayload('j', 20)),
    (kindBinary, binaryPayload(50, 1)),
    (kindJson, jsonPayload('k', 5)),
    (kindBinary, binaryPayload(0, 2)),
    (kindJson, jsonPayload('l', 30)),
  ];

  test('every split point of mixed json and binary frames gives the same frames', () async {
    final bytes = streamOf(mixedFrames);
    for (int offset = 1; offset < bytes.length; offset++) {
      final result = await read(splitAt(bytes, [offset]));
      expectFrames(result.frames, mixedFrames, reason: 'split at $offset');
    }
  });

  test('feeding one byte per read gives the same frames', () async {
    final bytes = streamOf(mixedFrames);
    final offsets = List.generate(bytes.length - 1, (i) => i + 1);
    final result = await read(splitAt(bytes, offsets));
    expectFrames(result.frames, mixedFrames);
  });

  test('random reads over big frames give the same frames and binary payloads keep their bytes', () async {
    final frames = [
      (kindJson, jsonPayload('m', 5000)),
      (kindBinary, binaryPayload(70000, 3)),
      (kindJson, jsonPayload('n', 10)),
      (kindBinary, binaryPayload(3, 4)),
      ...List.generate(30, (i) => (kindJson, jsonPayload('$i', 150))),
      (kindBinary, binaryPayload(9000, 5)),
      (kindJson, jsonPayload('o', 9000)),
    ];
    final bytes = streamOf(frames);
    final random = math.Random(7);
    for (int round = 0; round < 40; round++) {
      final offsets = <int>[];
      int offset = 0;
      while (true) {
        offset += 1 + random.nextInt(20000);
        if (offset >= bytes.length) break;
        offsets.add(offset);
      }
      final result = await read(splitAt(bytes, offsets));
      expectFrames(result.frames, frames, reason: 'round $round');
    }
  });

  test('zero length frames are skipped', () async {
    final payload = jsonPayload('z', 10);
    final bytes = Uint8List.fromList([0, 0, 0, 0, ...frameOf(kindJson, payload), 0, 0, 0, 0]);
    final result = await read([bytes]);
    expectFrames(result.frames, [(kindJson, payload)]);
  });

  test('a frame declared longer than the limit errors the stream, paired or not', () async {
    const tooLong = 256 * 1024 * 1024 + 1;
    final header = Uint8List.fromList([(tooLong >> 24) & 0xFF, (tooLong >> 16) & 0xFF, (tooLong >> 8) & 0xFF, tooLong & 0xFF, kindJson]);
    for (final isPaired in [true, false]) {
      final result = await read([header], isPaired: isPaired);
      expect(result.frames, isEmpty, reason: 'paired: $isPaired');
      expect(result.errors.single, isA<SocketException>(), reason: 'paired: $isPaired');
    }
  });

  group('unpaired limit', () {
    const unpairedLimit = 64 * 1024;
    final smallFrames = [
      (kindJson, jsonPayload('a', 100)),
      (kindBinary, binaryPayload(300, 6)),
      (kindJson, jsonPayload('b', 50)),
      (kindJson, jsonPayload('c', 10)),
    ];
    final atLimitFrame = (kindJson, jsonPayload('y', unpairedLimit - 9));
    final overLimitFrame = (kindJson, jsonPayload('x', unpairedLimit - 8));
    final bigBinaryFrame = (kindBinary, binaryPayload(unpairedLimit * 3, 7));
    final frames = [
      smallFrames[0],
      overLimitFrame,
      smallFrames[1],
      bigBinaryFrame,
      smallFrames[2],
      atLimitFrame,
      smallFrames[3],
    ];
    final unpairedFrames = [smallFrames[0], smallFrames[1], smallFrames[2], atLimitFrame, smallFrames[3]];

    test('the frames sit right at the limit', () {
      expect(atLimitFrame.$2.length + 1, unpairedLimit);
      expect(overLimitFrame.$2.length + 1, unpairedLimit + 1);
    });

    test('a paired reader takes every frame', () async {
      final result = await read([streamOf(frames)]);
      expectFrames(result.frames, frames);
      expect(result.errors, isEmpty);
    });

    test('an unpaired reader drops frames over the limit and keeps the ones around them, at random reads', () async {
      final bytes = streamOf(frames);
      final random = math.Random(11);
      for (int round = 0; round < 40; round++) {
        final offsets = <int>[];
        int offset = 0;
        while (true) {
          offset += 1 + random.nextInt(30000);
          if (offset >= bytes.length) break;
          offsets.add(offset);
        }
        final result = await read(splitAt(bytes, offsets), isPaired: false);
        expectFrames(result.frames, unpairedFrames, reason: 'round $round');
        expect(result.errors, isEmpty, reason: 'round $round');
      }
    });

    test('an unpaired reader splits right around the dropped frames', () async {
      final bytes = streamOf(frames);
      final dropBoundaries = [lengthOfFirst(frames, 1), lengthOfFirst(frames, 2), lengthOfFirst(frames, 3), lengthOfFirst(frames, 4)];
      for (final boundary in dropBoundaries) {
        for (int delta = -6; delta <= 6; delta++) {
          final splitOffset = boundary + delta;
          final result = await read(splitAt(bytes, [splitOffset]), isPaired: false);
          expectFrames(result.frames, unpairedFrames, reason: 'split at $splitOffset');
          expect(result.errors, isEmpty, reason: 'split at $splitOffset');
        }
      }
    });

    test('an unpaired reader never buffers a dropped frame, a paired one does', () {
      final bytes = frameOf(bigBinaryFrame.$1, bigBinaryFrame.$2);
      final firstPart = Uint8List.sublistView(bytes, 0, unpairedLimit);
      for (final isPaired in [true, false]) {
        final reader = debugCreateFrameReader(isPaired: isPaired);
        reader.addBytes(firstPart);
        final progress = reader.currentProgress.value;
        expect(progress != null, isPaired, reason: 'paired: $isPaired');
      }
    });

    test('a reader paired in the middle of a dropped frame drops the rest of it, then takes big frames', () async {
      final reader = debugCreateFrameReader(isPaired: false);
      final received = <(int, List<int>)>[];
      reader.frames.listen((frame) => received.add((frame.$1, Uint8List.fromList(frame.$2))));
      final bigFrameBytes = frameOf(overLimitFrame.$1, overLimitFrame.$2);
      final half = bigFrameBytes.length ~/ 2;
      reader.addBytes(Uint8List.fromList([...frameOf(smallFrames[0].$1, smallFrames[0].$2), ...bigFrameBytes.sublist(0, half)]));
      reader.allowLargeFrames();
      reader.addBytes(Uint8List.fromList([...bigFrameBytes.sublist(half), ...streamOf([bigBinaryFrame, smallFrames[1]])]));
      await Future<void>.delayed(Duration.zero);
      expectFrames(received, [smallFrames[0], bigBinaryFrame, smallFrames[1]]);
    });
  });

  test('closing in the middle of a frame reports the lost connection', () async {
    final bytes = frameOf(kindJson, jsonPayload('x', 100));
    final result = await read([Uint8List.sublistView(bytes, 0, 50)], closeAfter: true);
    expect(result.frames, isEmpty);
    expect(result.errors.single, isA<SocketException>());
  });

  group('dir file replace rule', () {
    const size = 1000;
    const mtimeMS = 1700000000000;

    bool isIncomingNewer({bool isNamedByContent = false, int incomingSize = size, required int incomingMtimeMS}) {
      return DirFileMessage.isIncomingNewer(
        isNamedByContent: isNamedByContent,
        existingSize: size,
        existingMtimeMS: mtimeMS,
        incomingSize: incomingSize,
        incomingMtimeMS: incomingMtimeMS,
      );
    }

    test('a newer copy of the same size replaces the existing one', () {
      expect(isIncomingNewer(incomingMtimeMS: mtimeMS + 60000), true);
      expect(isIncomingNewer(incomingMtimeMS: mtimeMS + 2001), true);
    });

    test('same size with mtimes within 2 seconds is the same file', () {
      expect(isIncomingNewer(incomingMtimeMS: mtimeMS), false);
      expect(isIncomingNewer(incomingMtimeMS: mtimeMS + 2000), false);
      expect(isIncomingNewer(incomingMtimeMS: mtimeMS - 2000), false);
    });

    test('the newer copy wins when sizes differ', () {
      expect(isIncomingNewer(incomingSize: size + 1, incomingMtimeMS: mtimeMS + 1), true);
      expect(isIncomingNewer(incomingSize: size - 1, incomingMtimeMS: mtimeMS - 1), false);
      expect(isIncomingNewer(incomingSize: size + 1, incomingMtimeMS: mtimeMS), false);
    });

    test('a same sized cache file named by its content is never replaced', () {
      expect(isIncomingNewer(isNamedByContent: true, incomingMtimeMS: mtimeMS + 60000), false);
      expect(isIncomingNewer(isNamedByContent: true, incomingSize: size + 1, incomingMtimeMS: mtimeMS + 60000), true);
    });

    test('an older copy never replaces the existing one', () {
      expect(isIncomingNewer(incomingMtimeMS: mtimeMS - 60000), false);
      expect(isIncomingNewer(incomingSize: size * 2, incomingMtimeMS: mtimeMS - 60000), false);
    });
  });
}
