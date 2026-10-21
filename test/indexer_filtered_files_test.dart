import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dirs_file_filter.dart';
import 'package:namida/core/extensions.dart';

void main() {
  late Directory userDataDir;
  late Directory root;

  String pathOf(String name) => [root.path, name].join(Platform.pathSeparator);

  final modified = DateTime(2020, 5, 17, 10, 30, 12);
  final modifiedMS = modified.millisecondsSinceEpoch;

  setUpAll(() async {
    userDataDir = Directory.systemTemp.createTempSync('namida_filtered_files_data');
    AppDirs.USER_DATA = '${userDataDir.path}${Platform.pathSeparator}';
    root = Directory.systemTemp.createTempSync('namida_filtered_files');

    const names = ['small.mp3', 'short.mp3', 'resized.mp3', 'touched.mp3', 'subsecond.mp3', 'new.mp3', 'indexed.mp3'];
    for (final name in names) {
      final file = File(pathOf(name));
      file.writeAsBytesSync(List.filled(100, 1));
      file.setLastModifiedSync(modified);
    }
    settings.directoriesToScan.replace([DirectoryIndexLocal(root.path)]);

    await File(AppPaths.TRACKS_FILTERED).writeAsJson({
      pathOf('small.mp3'): [100, modifiedMS, 0],
      pathOf('short.mp3'): [100, modifiedMS, 5000],
      pathOf('resized.mp3'): [90, modifiedMS, 0],
      pathOf('touched.mp3'): [100, modifiedMS - 5000, 0],
      pathOf('subsecond.mp3'): [100, modifiedMS + 400, 0],
      pathOf('gone.mp3'): [100, modifiedMS, 0],
      pathOf('indexed.mp3'): [100, modifiedMS, 0],
    });

    Indexer.inst.tracksInfoList.value.add(Track.explicit(pathOf('indexed.mp3')));
  });

  tearDownAll(() {
    root.deleteSync(recursive: true);
    userDataDir.deleteSync(recursive: true);
  });

  Future<IndexerFilesDiff> difference({required int minSize, required int minDurSec}) async {
    settings.indexMinFileSizeInB.save(minSize);
    settings.indexMinDurationInSec.save(minDurSec);
    final dirsFilterer = DirsFileFilter(extensions: NamidaFileExtensionsWrapper.audio, withStats: true);
    final currentFiles = await dirsFilterer.filterSync();
    return Indexer.inst.getPathsDifference(currentFiles);
  }

  Set<String> pathsOf(List<String> names) => names.map(pathOf).toSet();

  test('unchanged files still filtered are left out of new paths', () async {
    final diff = await difference(minSize: 1000, minDurSec: 10);
    expect(diff.filteredPaths, pathsOf(['small.mp3', 'short.mp3', 'subsecond.mp3']));
    expect(diff.newPaths, pathsOf(['resized.mp3', 'touched.mp3', 'new.mp3']));
  });

  test('lowering min size brings back files filtered only by size', () async {
    final diff = await difference(minSize: 50, minDurSec: 10);
    expect(diff.filteredPaths, pathsOf(['short.mp3']));
    expect(diff.newPaths, pathsOf(['small.mp3', 'resized.mp3', 'touched.mp3', 'subsecond.mp3', 'new.mp3']));
  });

  test('lowering min duration brings back the rest', () async {
    final diff = await difference(minSize: 50, minDurSec: 3);
    expect(diff.filteredPaths, <String>{});
    expect(diff.newPaths, pathsOf(['small.mp3', 'short.mp3', 'resized.mp3', 'touched.mp3', 'subsecond.mp3', 'new.mp3']));
  });
}
