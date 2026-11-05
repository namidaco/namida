// by claude
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/class/taglib_res.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/translations/language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dataDir;
  late Directory root;
  final sep = Platform.pathSeparator;
  final indexer = Indexer.inst;

  String pathOf(String relativePath) => '${root.path}$sep${relativePath.replaceAll('/', sep)}';

  // -- same date for all, so equal copies are picked by path
  final modified = DateTime(2020, 5, 17, 10, 30, 12);
  void writeWav(String relativePath, {required int sampleRate, required int seconds}) {
    final file = File(pathOf(relativePath))..createSync(recursive: true);
    file.writeAsBytesSync(_silentWavBytes(sampleRate: sampleRate, seconds: seconds));
    file.setLastModifiedSync(modified);
  }

  Set<String> libraryPaths() => indexer.allTracksMappedByPath.keys.toSet();
  Set<String> skippedPaths() => indexer.getDuplicateGroups().expand((e) => e.copies).map((e) => e.path).toSet();
  Future<void> refresh({bool forceReIndex = false}) => indexer.refreshLibraryAndCheckForDiff(forceReIndex: forceReIndex, showFinishedSnackbar: false);

  setUpAll(() async {
    dataDir = Directory.systemTemp.createTempSync('namida_duplicates_data');
    AppDirs.USER_DATA = '${dataDir.path}$sep';
    root = Directory.systemTemp.createTempSync('namida_duplicates');
    settings.directoriesToScan.replace([DirectoryIndexLocal(root.path)]);
    settings.indexMinDurationInSec.save(0);
    settings.indexMinFileSizeInB.save(0);
    settings.preventDuplicatedTracks.save(true);
    Language.inst.update(language: NamidaLanguage.fromCode('en')); // -- for the snackbars
    await PlaylistController.inst.prepareAllPlaylists(); // -- sorting after indexing waits for it
  });
  tearDownAll(() {
    try {
      root.deleteSync(recursive: true);
      dataDir.deleteSync(recursive: true);
    } catch (_) {} // -- the tracks db can still hold the folder
  });

  test('full index keeps the best copy and skips the rest', () async {
    writeWav('a/song.wav', sampleRate: 16000, seconds: 3);
    writeWav('b/song.wav', sampleRate: 8000, seconds: 3);
    writeWav('c/song (slowed).wav', sampleRate: 8000, seconds: 3);
    writeWav('d/song.wav', sampleRate: 8000, seconds: 9);
    writeWav('f/Tune (Live).wav', sampleRate: 8000, seconds: 4);
    writeWav('g/tune [live].wav', sampleRate: 8000, seconds: 4);
    await refresh(forceReIndex: true);

    expect(libraryPaths(), {pathOf('a/song.wav'), pathOf('c/song (slowed).wav'), pathOf('d/song.wav'), pathOf('f/Tune (Live).wav')});
    expect(skippedPaths(), {pathOf('b/song.wav'), pathOf('g/tune [live].wav')});
    final keptPaths = indexer.getDuplicateGroups().map((e) => e.keptPath).toSet();
    expect(keptPaths, {pathOf('a/song.wav'), pathOf('f/Tune (Live).wav')});
    expect(indexer.duplicatedTracksLength.value, 2);
    expect(File(AppPaths.TRACKS_DUPLICATED).existsSync(), true);
  });

  test('unchanged copies stay out of new paths', () async {
    final currentFiles = await indexer.getAudioFilesForRefresh();
    final diff = await indexer.getPathsDifference(currentFiles);
    expect(diff.newPaths, <String>{});
    expect(diff.duplicatePaths, {pathOf('b/song.wav'), pathOf('g/tune [live].wav')});
  });

  test('a better new copy is skipped, the indexed copy wins', () async {
    writeWav('e/song.wav', sampleRate: 22050, seconds: 3);
    await refresh();
    expect(libraryPaths().contains(pathOf('e/song.wav')), false);
    expect(skippedPaths(), {pathOf('b/song.wav'), pathOf('e/song.wav'), pathOf('g/tune [live].wav')});
  });

  test('deleting the kept copy indexes the best skipped one', () async {
    File(pathOf('a/song.wav')).deleteSync();
    await refresh();
    expect(libraryPaths().contains(pathOf('e/song.wav')), true);
    expect(skippedPaths(), {pathOf('b/song.wav'), pathOf('g/tune [live].wav')});
    final songGroup = indexer.getDuplicateGroups().firstWhere((e) => e.copies.single.path == pathOf('b/song.wav'));
    expect(songGroup.keptPath, pathOf('e/song.wav'));
  });

  test('disabling indexes every copy back', () async {
    settings.preventDuplicatedTracks.save(false);
    await indexer.onPreventDuplicatedTracksChanged(false);
    expect(libraryPaths().containsAll([pathOf('b/song.wav'), pathOf('e/song.wav'), pathOf('g/tune [live].wav')]), true);
    expect(skippedPaths(), <String>{});
    expect(File(AppPaths.TRACKS_DUPLICATED).existsSync(), false);
  });

  test('enabling keeps the best copy of each track', () async {
    settings.preventDuplicatedTracks.save(true);
    await indexer.onPreventDuplicatedTracksChanged(true);
    expect(libraryPaths().contains(pathOf('e/song.wav')), true);
    expect(libraryPaths().contains(pathOf('b/song.wav')), false);
    expect(skippedPaths(), {pathOf('b/song.wav'), pathOf('g/tune [live].wav')});
  });

  test('different recording ids are versions, an unknown id is still a copy', () async {
    TrackExtended versionOf(String relativePath, {required int bitrate, String? recordingId}) {
      return kDummyExtendedTrack.copyWith(
        path: pathOf(relativePath),
        title: 'Help',
        originalArtist: 'The Beatles',
        durationMS: 140000,
        bitrate: bitrate,
        extraTags: recordingId == null ? null : {TagLibField.MUSICBRAINZ_TRACKID: recordingId},
        generatePathHash: false,
      );
    }

    final versions = [
      versionOf('versions/mono.flac', bitrate: 900, recordingId: 'mono-recording'),
      versionOf('versions/stereo.flac', bitrate: 1000, recordingId: 'stereo-recording'),
      versionOf('versions/untagged.mp3', bitrate: 320),
    ];
    for (final trExt in versions) {
      indexer.allTracksMappedByPath[trExt.path] = trExt;
      indexer.tracksInfoList.value.add(trExt.asTrack());
    }
    await indexer.onPreventDuplicatedTracksChanged(true);

    expect(libraryPaths().containsAll([pathOf('versions/mono.flac'), pathOf('versions/stereo.flac')]), true);
    expect(libraryPaths().contains(pathOf('versions/untagged.mp3')), false);
    expect(skippedPaths().contains(pathOf('versions/untagged.mp3')), true);
  });
}

Uint8List _silentWavBytes({required int sampleRate, required int seconds}) {
  final dataLength = sampleRate * 2 * seconds;
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
