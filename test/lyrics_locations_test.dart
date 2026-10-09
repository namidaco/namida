// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:namida/class/track.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_selectable.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';

const _kLyrics = '[00:01.00]line one\n[00:02.00]line two';
const _kJsonLyrics = '[{"text":[{"text":"line","part":false,"timestamp":1000,"endtime":2000}],"background":false,"timestamp":1000,"endtime":2000}]';

void main() {
  late Directory root;
  late String library;
  late String cache;
  late String lyricsFolder;

  setUp(() {
    root = Directory.systemTemp.createTempSync('namida_lyrics_test');
    library = p.join(root.path, 'Music');
    cache = p.join(root.path, 'Cache');
    lyricsFolder = p.join(root.path, 'Lyrics');
    Directory(p.join(library, 'Artist', 'Album')).createSync(recursive: true);
    Directory(cache).createSync();
    Directory(lyricsFolder).createSync();
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  String trackPath([String filename = 'song.flac']) => p.join(library, 'Artist', 'Album', filename);

  File write(String path, [String content = _kLyrics]) {
    final file = File(path);
    file.createSync(recursive: true);
    file.writeAsStringSync(content);
    return file;
  }

  LrcSearchUtilsSelectableIsolate utils({
    String? path,
    LyricsSaveLocation saveLocation = LyricsSaveLocation.cache,
    List<String> folders = const [],
  }) {
    return LrcSearchUtilsSelectableIsolate(
      kDummyExtendedTrack,
      Track.explicit(path ?? trackPath()),
      mainLyricsCacheDirectory: cache,
      locations: LyricsLocations(
        saveLocation: saveLocation,
        folders: folders,
        libraryDirectories: [library],
      ),
    );
  }

  group('track folder', () {
    test('nothing there', () async {
      expect(await utils().firstDeviceFiles().then((f) => f.lrc), isNull);
      expect(await utils().firstDeviceFiles().then((f) => f.txt), isNull);
      expect(await utils().allDeviceLyricsFiles(), isEmpty);
    });

    test('a file added after the first lookup is found', () async {
      expect(await utils().firstDeviceFiles().then((f) => f.lrc), isNull);
      final added = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      final found = await utils().firstDeviceFiles().then((f) => f.lrc);
      expect(found?.path, added.path);
    });

    test('a reused listing is refreshed once the directory changes', () async {
      // -- a listing is only reused when the directory was not modified right before it
      await Future.delayed(const Duration(milliseconds: 2200));
      expect(await utils().firstDeviceFiles().then((f) => f.lrc), isNull);
      expect(await utils().firstDeviceFiles().then((f) => f.lrc), isNull);

      final added = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      final found = await utils().firstDeviceFiles().then((f) => f.lrc);
      expect(found?.path, added.path);

      await Future.delayed(const Duration(milliseconds: 2200));
      expect(await utils().firstDeviceFiles().then((f) => f.lrc), isNotNull);
      final other = write(p.join(library, 'Artist', 'Album', 'other.lrc'));
      final foundOther = await utils(path: trackPath('other.flac')).firstDeviceFiles().then((f) => f.lrc);
      expect(foundOther?.path, other.path);
    });

    test('a file removed after the first lookup is gone', () async {
      final added = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      expect(await utils().firstDeviceFiles().then((f) => f.lrc), isNotNull);
      added.deleteSync();
      expect(await utils().firstDeviceFiles().then((f) => f.lrc), isNull);
    });

    test('extension and name case are ignored', () async {
      final added = write(p.join(library, 'Artist', 'Album', 'SONG.Lrc'));
      final found = await utils().firstDeviceFiles().then((f) => f.lrc);
      expect(found?.path, added.path);
    });

    test('name with the audio extension', () async {
      final added = write(p.join(library, 'Artist', 'Album', 'song.flac.lrc'));
      final found = await utils().firstDeviceFiles().then((f) => f.lrc);
      expect(found?.path, added.path);
    });

    test('lrc goes before other formats, without the audio extension first', () async {
      write(p.join(library, 'Artist', 'Album', 'song.srt'));
      write(p.join(library, 'Artist', 'Album', 'song.flac.lrc'));
      final preferred = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      final found = await utils().firstDeviceFiles().then((f) => f.lrc);
      expect(found?.path, preferred.path);
      expect(await utils().allDeviceLyricsFiles(), hasLength(3));
    });

    test('empty file is skipped', () async {
      write(p.join(library, 'Artist', 'Album', 'song.lrc'), '');
      final valid = write(p.join(library, 'Artist', 'Album', 'song.srt'));
      final found = await utils().firstDeviceFiles().then((f) => f.lrc);
      expect(found?.path, valid.path);
    });

    test('other tracks lyrics are not matched', () async {
      write(p.join(library, 'Artist', 'Album', 'song 2.lrc'));
      write(p.join(library, 'Artist', 'Album', 'son.lrc'));
      expect(await utils().firstDeviceFiles().then((f) => f.lrc), isNull);
    });

    test('name with dots', () async {
      final path = trackPath('01. song.name.flac');
      final added = write(p.join(library, 'Artist', 'Album', '01. song.name.lrc'));
      final found = await utils(path: path).firstDeviceFiles().then((f) => f.lrc);
      expect(found?.path, added.path);
    });

    test('plain lyrics are separate from synced', () async {
      final added = write(p.join(library, 'Artist', 'Album', 'song.txt'), 'plain lyrics');
      expect(await utils().firstDeviceFiles().then((f) => f.lrc), isNull);
      final found = await utils().firstDeviceFiles().then((f) => f.txt);
      expect(found?.path, added.path);
    });

    test('sync lookup', () {
      final added = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      final found = utils().firstDeviceFilesSync().lrc;
      expect(found?.path, added.path);
      expect(utils(path: trackPath('other.flac')).firstDeviceFilesSync().lrc, isNull);
    });

    test('network track', () async {
      final networkUtils = utils(path: 'https://server/song.flac', saveLocation: LyricsSaveLocation.trackFolder);
      expect(await networkUtils.firstDeviceFiles().then((f) => f.lrc), isNull);
      expect(await networkUtils.saveLyricsToDevice(_kLyrics, true), isNull);
    });
  });

  group('lyrics folders', () {
    test('same subfolders as the library', () async {
      final added = write(p.join(lyricsFolder, 'Artist', 'Album', 'song.lrc'));
      final found = await utils(folders: [lyricsFolder]).firstDeviceFiles().then((f) => f.lrc);
      expect(found?.path, added.path);
    });

    test('directly inside', () async {
      final added = write(p.join(lyricsFolder, 'song.lrc'));
      final found = await utils(folders: [lyricsFolder]).firstDeviceFiles().then((f) => f.lrc);
      expect(found?.path, added.path);
    });

    test('subfolder that does not exist', () async {
      expect(await utils(folders: [lyricsFolder]).firstDeviceFiles().then((f) => f.lrc), isNull);
      expect(utils(folders: [lyricsFolder]).firstDeviceFilesSync().lrc, isNull);
    });

    test('track right inside the library directory', () async {
      final path = p.join(library, 'song.flac');
      final added = write(p.join(lyricsFolder, 'song.lrc'));
      final found = await utils(path: path, folders: [lyricsFolder]).firstDeviceFiles().then((f) => f.lrc);
      expect(found?.path, added.path);
    });

    test('directory that only starts with the library name is outside of it', () {
      final locations = LyricsLocations(
        saveLocation: LyricsSaveLocation.customFolder,
        folders: [lyricsFolder],
        libraryDirectories: [library],
      );
      final outside = p.join('${library}2', 'Artist');
      expect(locations.directoryForSaving(outside), lyricsFolder);
      expect(locations.directoriesFor(outside), [lyricsFolder, outside]);
    });

    test('nested library directories use the deepest one', () {
      final locations = LyricsLocations(
        saveLocation: LyricsSaveLocation.customFolder,
        folders: [lyricsFolder],
        libraryDirectories: [library, p.join(library, 'Artist')],
      );
      final trackDir = p.join(library, 'Artist', 'Album');
      expect(locations.directoryForSaving(trackDir), p.join(lyricsFolder, 'Album'));
    });

    test('track folder goes first unless lyrics are saved in a lyrics folder', () async {
      final inTrackFolder = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      final inLyricsFolder = write(p.join(lyricsFolder, 'Artist', 'Album', 'song.lrc'));

      final foundDefault = await utils(folders: [lyricsFolder]).firstDeviceFiles().then((f) => f.lrc);
      expect(foundDefault?.path, inTrackFolder.path);

      final foundCustom = await utils(folders: [lyricsFolder], saveLocation: LyricsSaveLocation.customFolder).firstDeviceFiles().then((f) => f.lrc);
      expect(foundCustom?.path, inLyricsFolder.path);
    });
  });

  group('cache order', () {
    test('cache first when lyrics are saved in cache', () async {
      write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      final cached = write(p.join(cache, 'song.flac.lrc'));
      final found = await utils().firstLyricsFiles(includeTxt: true).then((f) => f.lrc);
      expect(found?.path, cached.path);
    });

    test('device first when lyrics are saved outside', () async {
      final inTrackFolder = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      write(p.join(cache, 'song.flac.lrc'));
      final found = await utils(saveLocation: LyricsSaveLocation.trackFolder).firstLyricsFiles(includeTxt: true).then((f) => f.lrc);
      expect(found?.path, inTrackFolder.path);
    });

    test('cache is still read when nothing is outside', () async {
      final cached = write(p.join(cache, 'song.flac.lrc'));
      final found = await utils(saveLocation: LyricsSaveLocation.trackFolder).firstLyricsFiles(includeTxt: true).then((f) => f.lrc);
      expect(found?.path, cached.path);
      expect(await utils(saveLocation: LyricsSaveLocation.trackFolder).hasLyrics(), true);
    });
  });

  group('saving', () {
    test('cache', () async {
      final saved = await utils().saveLyrics(_kLyrics, true);
      expect(saved.path, p.join(cache, 'song.flac.lrc'));
      expect(utils().isCacheFile(saved), true);
    });

    test('track folder, found right after', () async {
      final trackFolderUtils = utils(saveLocation: LyricsSaveLocation.trackFolder);
      expect(await trackFolderUtils.firstDeviceFiles().then((f) => f.lrc), isNull);

      final saved = await trackFolderUtils.saveLyrics(_kLyrics, true);
      expect(saved.path, p.join(library, 'Artist', 'Album', 'song.lrc'));
      expect(trackFolderUtils.isCacheFile(saved), false);
      expect(saved.readAsStringSync(), _kLyrics);

      final found = await trackFolderUtils.firstLyricsFiles(includeTxt: true).then((f) => f.lrc);
      expect(found?.path, saved.path);
    });

    test('plain lyrics', () async {
      final saved = await utils(saveLocation: LyricsSaveLocation.trackFolder).saveLyrics('plain lyrics', false);
      expect(saved.path, p.join(library, 'Artist', 'Album', 'song.txt'));
    });

    test('lyrics folder creates the subfolders', () async {
      final saved = await utils(saveLocation: LyricsSaveLocation.customFolder, folders: [lyricsFolder]).saveLyrics(_kLyrics, true);
      expect(saved.path, p.join(lyricsFolder, 'Artist', 'Album', 'song.lrc'));
      expect(saved.existsSync(), true);
    });

    test('lyrics folder without any folder goes to cache', () async {
      final saved = await utils(saveLocation: LyricsSaveLocation.customFolder).saveLyrics(_kLyrics, true);
      expect(saved.path, p.join(cache, 'song.flac.lrc'));
    });

    test('location that can not be written goes to cache and reports it', () async {
      final blocker = write(p.join(root.path, 'blocker'), 'a file where a folder is expected');
      final blockedUtils = utils(saveLocation: LyricsSaveLocation.customFolder, folders: [blocker.path]);
      File? failedFile;
      final savedToDevice = await blockedUtils.saveLyricsToDevice(_kLyrics, true, onFailed: (deviceFile) => failedFile = deviceFile);
      expect(savedToDevice, isNull);
      expect(failedFile?.path, p.join(blocker.path, 'Artist', 'Album', 'song.lrc'));

      final saved = await blockedUtils.saveLyrics(_kLyrics, true);
      expect(saved.path, p.join(cache, 'song.flac.lrc'));
    });

    test('nothing is reported when saving works', () async {
      File? failedFile;
      await utils(saveLocation: LyricsSaveLocation.trackFolder).saveLyricsToDevice(_kLyrics, true, onFailed: (deviceFile) => failedFile = deviceFile);
      expect(failedFile, isNull);
    });

    test('path longer than 260 characters', () async {
      final deepSubfolder = List.filled(12, 'a folder name of thirty chars!').join(Platform.pathSeparator);
      final path = p.join(library, deepSubfolder, 'song.flac');
      final longUtils = utils(path: path, saveLocation: LyricsSaveLocation.customFolder, folders: [lyricsFolder]);

      final saved = await longUtils.saveLyrics(_kLyrics, true);
      expect(saved.path.length, greaterThan(260));
      expect(saved.path, p.join(lyricsFolder, deepSubfolder, 'song.lrc'));

      final found = await longUtils.firstDeviceFiles();
      expect(found.lrc?.path, saved.path);
      expect(found.lrc?.readAsStringSync(), _kLyrics);
      expect(longUtils.firstDeviceFilesSync().lrc?.path, saved.path);

      await LrcSearchUtilsSelectable.deleteLyricsOfDeletedTracks([path], [], LyricsSaveLocation.values.toSet(), cacheDirectory: cache, locations: longUtils.locations);
      expect(saved.existsSync(), false);
    });
  });

  group('deleting with the track', () {
    LyricsLocations locations() {
      return LyricsLocations(
        saveLocation: LyricsSaveLocation.trackFolder,
        folders: [lyricsFolder],
        libraryDirectories: [library],
      );
    }

    Future<void> delete(List<String> deletedPaths, List<String> libraryPaths, {Set<LyricsSaveLocation>? deleteIn}) {
      return LrcSearchUtilsSelectable.deleteLyricsOfDeletedTracks(
        deletedPaths,
        libraryPaths,
        deleteIn ?? LyricsSaveLocation.values.toSet(),
        cacheDirectory: cache,
        locations: locations(),
      );
    }

    test('lyrics everywhere are deleted', () async {
      final inTrackFolder = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      final withExtension = write(p.join(library, 'Artist', 'Album', 'Song.flac.TXT'));
      final inSubfolder = write(p.join(lyricsFolder, 'Artist', 'Album', 'song.srt'));
      final inLyricsFolder = write(p.join(lyricsFolder, 'song.lrc'));
      final cachedLRC = write(p.join(cache, 'song.flac.lrc'));
      final cachedTxt = write(p.join(cache, 'song.flac.txt'));
      final ofOtherTrack = write(p.join(library, 'Artist', 'Album', 'other.lrc'));

      await delete([trackPath()], [trackPath('other.flac')]);

      expect(inTrackFolder.existsSync(), false);
      expect(withExtension.existsSync(), false);
      expect(inSubfolder.existsSync(), false);
      expect(inLyricsFolder.existsSync(), false);
      expect(cachedLRC.existsSync(), false);
      expect(cachedTxt.existsSync(), false);
      expect(ofOtherTrack.existsSync(), true);
    });

    test('a json named like the track is neither found as lyrics nor deleted with it, even in a lyrics json format', () async {
      final json = write(p.join(library, 'Artist', 'Album', 'song.json'), _kJsonLyrics);
      final jsonWithExtension = write(p.join(library, 'Artist', 'Album', 'song.flac.json'), _kJsonLyrics);
      expect(utils().firstDeviceFilesSync().lrc, isNull);
      final found = await utils().firstDeviceFiles();
      expect(found.lrc, isNull);
      expect(found.txt, isNull);
      expect(await utils().allDeviceLyricsFiles(), isEmpty);

      await delete([trackPath()], []);

      expect(json.existsSync(), true);
      expect(jsonWithExtension.existsSync(), true);
    });

    test('only in the chosen locations', () async {
      final inTrackFolder = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      final inSubfolder = write(p.join(lyricsFolder, 'Artist', 'Album', 'song.lrc'));
      final inLyricsFolder = write(p.join(lyricsFolder, 'song.lrc'));
      final cached = write(p.join(cache, 'song.flac.lrc'));

      await delete([trackPath()], [], deleteIn: {LyricsSaveLocation.trackFolder});
      expect(inTrackFolder.existsSync(), false);
      expect(inSubfolder.existsSync(), true);
      expect(inLyricsFolder.existsSync(), true);
      expect(cached.existsSync(), true);

      await delete([trackPath()], [], deleteIn: {LyricsSaveLocation.customFolder});
      expect(inSubfolder.existsSync(), false);
      expect(inLyricsFolder.existsSync(), false);
      expect(cached.existsSync(), true);

      await delete([trackPath()], [], deleteIn: {LyricsSaveLocation.cache});
      expect(cached.existsSync(), false);
    });

    test('track that still exists keeps its lyrics', () async {
      write(trackPath(), 'audio');
      final inTrackFolder = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      final cached = write(p.join(cache, 'song.flac.lrc'));

      await delete([trackPath()], []);

      expect(inTrackFolder.existsSync(), true);
      expect(cached.existsSync(), true);
    });

    test('deleted track that is still listed in the library', () async {
      final inTrackFolder = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      await delete([trackPath()], [trackPath()]);
      expect(inTrackFolder.existsSync(), false);
    });

    test('same name with another format in the same folder', () async {
      final shared = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      final sharedInSubfolder = write(p.join(lyricsFolder, 'Artist', 'Album', 'song.lrc'));
      final sharedInLyricsFolder = write(p.join(lyricsFolder, 'song.lrc'));
      final ofDeletedOnly = write(p.join(library, 'Artist', 'Album', 'song.flac.lrc'));
      final cached = write(p.join(cache, 'song.flac.lrc'));
      final cachedOfOther = write(p.join(cache, 'song.mp3.lrc'));

      await delete([trackPath()], [trackPath('song.mp3')]);

      expect(shared.existsSync(), true);
      expect(sharedInSubfolder.existsSync(), true);
      expect(sharedInLyricsFolder.existsSync(), true);
      expect(ofDeletedOnly.existsSync(), false);
      expect(cached.existsSync(), false);
      expect(cachedOfOther.existsSync(), true);
    });

    test('same filename in another folder', () async {
      final inTrackFolder = write(p.join(library, 'Artist', 'Album', 'song.lrc'));
      final inSubfolder = write(p.join(lyricsFolder, 'Artist', 'Album', 'song.lrc'));
      final inLyricsFolder = write(p.join(lyricsFolder, 'song.lrc'));
      final cached = write(p.join(cache, 'song.flac.lrc'));

      await delete([trackPath()], [p.join(library, 'Artist', 'Album 2', 'song.flac')]);

      expect(inTrackFolder.existsSync(), false);
      expect(inSubfolder.existsSync(), false);
      expect(inLyricsFolder.existsSync(), true);
      expect(cached.existsSync(), true);
    });
  });
}
