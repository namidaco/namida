// by claude
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/class/taglib_res.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  final sep = Platform.pathSeparator;
  final indexer = Indexer.inst;
  Map<String, List<Track>> ytIds() => indexer.allTracksMappedByYTID;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_indexer_upkeep_test');
    AppDirs.USER_DATA = '${dir.path}$sep';
  });
  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {} // -- the tracks db can still hold the folder
  });

  Future<Track> addTrack(String relativePath) async {
    final file = File('${dir.path}$sep$relativePath')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_silentWavBytes());
    final tracks = await indexer.convertPathsToTracksAndAddToLists([file.path]);
    return tracks.single;
  }

  group('youtube ids map', () {
    test('tracks without a link are not listed under an empty id', () async {
      final plain = await addTrack('plain${sep}song.wav');
      final linked = await addTrack('plain${sep}song id=aaaaaaaaaaa.wav');
      expect(plain.youtubeID, '');
      expect(ytIds().containsKey(''), false);
      expect(ytIds()['aaaaaaaaaaa'], [linked]);
    });

    test('removing one of two tracks with the same id keeps the other', () async {
      final first = await addTrack('removing${sep}a${sep}first id=bbbbbbbbbbb.wav');
      final second = await addTrack('removing${sep}b${sep}second id=bbbbbbbbbbb.wav');
      expect(ytIds()['bbbbbbbbbbb'], [first, second]);
      await indexer.removeTracksFromLibrary([first], isFromDelete: false);
      expect(ytIds()['bbbbbbbbbbb'], [second]);
      await indexer.removeTracksFromLibrary([second], isFromDelete: false);
      expect(ytIds().containsKey('bbbbbbbbbbb'), false);
    });

    test('reindexing a track keeps the other tracks with its id, listed once each', () async {
      final first = await addTrack('reindexing${sep}a${sep}first id=ccccccccccc.wav');
      final second = await addTrack('reindexing${sep}b${sep}second id=ccccccccccc.wav');
      await indexer.reindexTracks(
        tracks: [PhysicalMedia.fromTrack(first)],
        onProgress: (_) {},
        onFinish: (_) {},
      );
      expect(ytIds()['ccccccccccc'], [first, second]);
    });

    test('a changed link moves the track to its new id once, other tag edits keep it', () async {
      final track = await addTrack('editing${sep}song id=ddddddddddd.wav');
      Future<void> writeAndReindex(Map<String, List<String>> properties) async {
        TagLibRes.writeSync(track.path, newPropertiesMap: properties, ratingPercentage: null, artwork: null, chapters: null);
        await indexer.reindexTracks(tracks: [PhysicalMedia.fromTrack(track)], onProgress: (_) {}, onFinish: (_) {});
      }

      await writeAndReindex({
        'COMMENT': ['https://www.youtube.com/watch?v=eeeeeeeeeee'],
      });
      expect(ytIds().containsKey('ddddddddddd'), false);
      expect(ytIds()['eeeeeeeeeee'], [track]);

      await writeAndReindex({
        'TITLE': ['Other'],
      });
      expect(track.title, 'Other');
      expect(ytIds()['eeeeeeeeeee'], [track]);

      await writeAndReindex({'COMMENT': []});
      expect(ytIds().containsKey('eeeeeeeeeee'), false);
      expect(ytIds()['ddddddddddd'], [track]);
    });
  });

  test('added tracks reach the tracks db and removed ones leave it', () async {
    final kept = await addTrack('db${sep}kept.wav');
    final toRemove = await addTrack('db${sep}removed.wav');
    await indexer.removeTracksFromLibrary([toRemove], isFromDelete: false);
    await Future.delayed(const Duration(milliseconds: 600));

    final db = DBWrapper.openFromInfoSync(fileInfo: AppPaths.TRACKS_DB_INFO, config: const DBConfig(autoDisposeTimerDuration: null));
    try {
      expect(db.get(kept.path), isNotNull);
      expect(db.get(toRemove.path), isNull);
    } finally {
      db.close();
    }
  });
}

/// a second of 8 kHz 16 bit mono silence, readable without tags.
Uint8List _silentWavBytes() {
  const sampleRate = 8000;
  const dataLength = sampleRate * 2;
  final bytes = ByteData(44 + dataLength);
  void ascii(int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);
  return bytes.buffer.asUint8List();
}
