import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dirs_file_filter.dart';
import 'package:namida/core/extensions.dart';

void main() {
  late Directory settingsDir;
  late Directory root;

  String pathOf(List<String> parts) => [root.path, ...parts].join(Platform.pathSeparator);

  void createFile(List<String> parts, {int size = 16, DateTime? modified}) {
    final file = File(pathOf(parts));
    file.createSync(recursive: true);
    file.writeAsBytesSync(List.filled(size, 1));
    if (modified != null) file.setLastModifiedSync(modified);
  }

  setUpAll(() {
    settingsDir = Directory.systemTemp.createTempSync('namida_dirs_filter_settings');
    AppDirs.USER_DATA = '${settingsDir.path}${Platform.pathSeparator}';
    root = Directory.systemTemp.createTempSync('namida_dirs_filter');

    createFile(['a.mp3'], size: 100, modified: DateTime(2020, 5, 17, 10, 30, 12));
    createFile(['b.FLAC'], size: 0);
    createFile(['.hidden.mp3']);
    createFile(['notes.txt']);
    createFile(['cover.jpg']);
    createFile(['sub1', 'c.m4a'], size: 2048, modified: DateTime(2001, 1, 1, 0, 0, 1));
    createFile(['sub1', 'image.jpg']);
    createFile(['sub1', 'Folder.png']);
    createFile(['sub1', 'deep', 'd.mp3']);
    createFile(['nomedia', '.nomedia'], size: 0);
    createFile(['nomedia', 'e.mp3']);
    createFile(['nomedia', 'child', 'f.mp3']);
    createFile(['nomedia sibling', 'i.mp3']);
    createFile(['excluded', 'g.mp3']);
    createFile(['日本語 ñ', 'sóng 🎵.mp3'], size: 7);
    final longDirName = 'long' * 30;
    createFile([longDirName, longDirName, longDirName, 'h.mp3'], size: 9);
    Directory(pathOf(['empty'])).createSync();

    settings.directoriesToScan.replace([
      DirectoryIndexLocal(root.path),
      DirectoryIndexLocal(pathOf(['sub1'])),
      DirectoryIndexLocal(pathOf(['missing'])),
    ]);
    settings.directoriesToExclude.replace([
      DirectoryIndexLocal(pathOf(['excluded'])),
    ]);
  });

  tearDownAll(() {
    root.deleteSync(recursive: true);
    settingsDir.deleteSync(recursive: true);
  });

  Future<DirsFileFilterResult> filter({required bool useNativeLister, bool strictNoMedia = true}) {
    final dirsFilterer = DirsFileFilter(
      extensions: NamidaFileExtensionsWrapper.audioAndVideo,
      imageExtensions: NamidaFileExtensionsWrapper.image,
      strictNoMedia: strictNoMedia,
      withStats: true,
      useNativeLister: useNativeLister,
    );
    return dirsFilterer.filterSync();
  }

  Map<String, (int, int)> statsByPath(DirsFileFilterResult result) {
    final stats = result.stats!;
    final statsMap = <String, (int, int)>{};
    int index = 0;
    for (final path in result.allPaths) {
      expect(stats.isKnownAt(index), true, reason: path);
      statsMap[path] = (stats.sizeAt(index), stats.modifiedMSAt(index) ~/ 1000);
      index++;
    }
    return statsMap;
  }

  // -- dart can't list long paths on windows, it should only skip them
  bool isLongPath(String path) => path.length > 260;

  void expectSameResults(DirsFileFilterResult native, DirsFileFilterResult dart) {
    final nativeStats = statsByPath(native);
    final longPaths = native.allPaths.where(isLongPath).toList();
    expect(longPaths.length, 1);
    expect(nativeStats[longPaths.first]?.$1, 9);
    expect(dart.allPaths.any(isLongPath), false);
    nativeStats.remove(longPaths.first);

    expect(nativeStats.keys.toSet(), dart.allPaths);
    expect(native.excludedByNoMedia, dart.excludedByNoMedia);
    final nativeCovers = {for (final e in native.folderCovers.entries) e.key.path: e.value};
    final dartCovers = {for (final e in dart.folderCovers.entries) e.key.path: e.value};
    expect(nativeCovers, dartCovers);
    expect(nativeStats, statsByPath(dart));
  }

  for (final respectNoMedia in [false, true]) {
    for (final strictNoMedia in [false, true]) {
      test('native lister matches the dart one, respectNoMedia: $respectNoMedia, strictNoMedia: $strictNoMedia', () async {
        settings.respectNoMedia.save(respectNoMedia);
        final native = await filter(useNativeLister: true, strictNoMedia: strictNoMedia);
        final dart = await filter(useNativeLister: false, strictNoMedia: strictNoMedia);
        expectSameResults(native, dart);

        final expectedExcluded = <String>{
          if (respectNoMedia) pathOf(['nomedia', 'e.mp3']),
          if (respectNoMedia && strictNoMedia) pathOf(['nomedia', 'child', 'f.mp3']),
        };
        expect(native.excludedByNoMedia, expectedExcluded);
        expect(native.allPaths.contains(pathOf(['a.mp3'])), true);
        expect(native.allPaths.contains(pathOf(['b.FLAC'])), true);
        expect(native.allPaths.contains(pathOf(['日本語 ñ', 'sóng 🎵.mp3'])), true);
        expect(native.allPaths.contains(pathOf(['nomedia sibling', 'i.mp3'])), true);
        expect(native.allPaths.any((path) => path.getFilename == 'g.mp3'), false);
        expect(native.allPaths.any((path) => path.getFilename == '.hidden.mp3'), false);
      });
    }
  }

  test('stats match the files', () async {
    final result = await filter(useNativeLister: true);
    final statsMap = statsByPath(result);
    final modified = DateTime(2020, 5, 17, 10, 30, 12).millisecondsSinceEpoch ~/ 1000;
    expect(statsMap[pathOf(['a.mp3'])], (100, modified));
    expect(statsMap[pathOf(['b.FLAC'])]?.$1, 0);
    expect(statsMap[pathOf(['sub1', 'c.m4a'])]?.$1, 2048);

    final stats = result.stats!;
    int index = 0;
    for (final path in result.allPaths) {
      final fileStat = File(path).statSync();
      final fileStats = stats.toStatsAt(index)!;
      expect(fileStats.size, fileStat.size, reason: path);
      expect(fileStats.modifiedMS! ~/ 1000, fileStat.modified.millisecondsSinceEpoch ~/ 1000, reason: path);
      expect(fileStats.creationDateMS! ~/ 1000, fileStat.creationDate.millisecondsSinceEpoch ~/ 1000, reason: path);
      index++;
    }
  });

  test('no stats unless requested', () async {
    final dirsFilterer = DirsFileFilter(extensions: NamidaFileExtensionsWrapper.audio);
    final result = await dirsFilterer.filterSync();
    expect(result.stats, null);
    expect(result.allPaths.isNotEmpty, true);
  });
}
