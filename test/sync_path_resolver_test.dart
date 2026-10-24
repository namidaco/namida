// by claude
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/constants.dart';

void main() {
  const androidSong = '/storage/emulated/0/Music/Ultimate Library/Library/modus/Albums/2026 - REGNUM ULTRA/08 Stay With You.flac';
  const windowsSong = r'C:\Users\User\Music\Ultimate Library\Library\modus\Albums\2026 - REGNUM ULTRA\08 Stay With You.flac';

  var devicesCount = 0;

  /// the sender's fingerprints never match here, only the path end can.
  Future<String> buildDevice(List<String> localPaths, {List<String> senderPaths = const []}) async {
    Indexer.inst.allTracksMappedByPath = {
      for (final path in localPaths) path: kDummyExtendedTrack.copyWith(path: path, generatePathHash: false),
    };
    final senderDeviceId = 'device_${devicesCount++}';
    final entries = [
      for (final path in senderPaths) [path, -1, -1],
    ];
    await SyncPathResolver.buildForDevice(senderDeviceId, entries);
    return senderDeviceId;
  }

  test('a sender path the fingerprints miss resolves by its folders and file name', () async {
    final deviceId = await buildDevice([windowsSong], senderPaths: [androidSong]);
    expect(SyncPathResolver.resolvedTracksFor(deviceId).keys, [androidSong]);
    expect(SyncPathResolver.resolvePath(deviceId, androidSong), windowsSong);
  });

  test('paths missing from the sender fingerprints resolve too, ex: listens of files it removed', () async {
    final deviceId = await buildDevice([windowsSong]);
    expect(SyncPathResolver.resolvePath(deviceId, androidSong), windowsSong);
  });

  test('a path that exists here stays as is', () async {
    final deviceId = await buildDevice([windowsSong]);
    expect(SyncPathResolver.resolvePath(deviceId, windowsSong), isNull);
  });

  test('the file name alone is not enough', () async {
    final deviceId = await buildDevice([r'C:\Music\Other Album\01 Intro.flac']);
    expect(SyncPathResolver.resolvePath(deviceId, '/storage/Music/Album/01 Intro.flac'), isNull);
  });

  test('a file name in several folders goes to the one sharing the most folders, a tie matches none', () async {
    const artistA = r'C:\Music\Artist A\Album\01.flac';
    const artistB = r'C:\Music\Artist B\Album\01.flac';
    final deviceId = await buildDevice([artistA, artistB]);
    expect(SyncPathResolver.resolvePath(deviceId, '/storage/Music/artist b/album/01.FLAC'), artistB);
    expect(SyncPathResolver.resolvePath(deviceId, '/storage/Music/Artist C/Album/01.flac'), isNull);
  });

  group('queue files from another device', () {
    Uint8List queueFileBytes(List<String> paths) {
      final json = {'source': 'others', 'date': 1, 'isFav': false, 'tracks': paths};
      return utf8.encode(jsonEncode(json));
    }

    test('keep their bytes when no track changes', () {
      final bytes = queueFileBytes([androidSong]);
      final resolved = QueueController.resolveQueueFileBytes(bytes, (_) => null);
      expect(identical(resolved, bytes), isTrue);
    });

    test('get the local paths', () async {
      final deviceId = await buildDevice([windowsSong]);
      const missingSong = '/storage/emulated/0/Music/missing.flac';
      final bytes = queueFileBytes([androidSong, missingSong]);
      final resolved = QueueController.resolveQueueFileBytes(bytes, (track) => SyncPathResolver.resolveTrack(deviceId, track));
      final resolvedPaths = <String>[];
      QueueController.resolveQueueFileBytes(resolved, (track) {
        resolvedPaths.add(track.path);
        return null;
      });
      expect(resolvedPaths, [windowsSong, missingSong]);
    });
  });
}
