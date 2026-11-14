// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late String musicDirectory;
  final controller = PlaylistController.inst;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_m3u_rename_test');
    AppDirs.INTERNAL_STORAGE = dir.path;
    AppDirs.USER_DATA = dir.path;
    Directory(AppDirs.M3UBackup).createSync(recursive: true);
    Directory(AppDirs.M3UPlaylists).createSync(recursive: true);
    musicDirectory = p.join(dir.path, 'Music');
    File(p.join(musicDirectory, 'a.flac')).createSync(recursive: true);
    settings.enableM3USync.save(true);
    settings.enableM3USyncStartup.save(false);
  });
  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {} // -- latest played db stays open
  });
  tearDown(controller.playlistsMap.value.clear);

  String writeM3U(String directory, String filename, {List<String> headerLines = const []}) {
    final m3uPath = p.join(directory, filename);
    final trackPath = p.join(musicDirectory, 'a.flac');
    final m3uFile = File(m3uPath)..createSync(recursive: true);
    m3uFile.writeAsStringSync(['#EXTM3U', ...headerLines, trackPath].join('\n'));
    return m3uPath;
  }

  void writeArtwork(String playlistName) {
    final file = controller.getArtworkFileForPlaylist(playlistName);
    file.createSync(recursive: true);
    file.writeAsBytesSync([1, 2, 3]);
  }

  bool hasArtwork(String playlistName) => controller.getArtworkFileForPlaylist(playlistName).existsSync();

  Future<void> refresh() async {
    await controller.prepareM3UPlaylists();
    await pumpEventQueue();
  }

  Future<void> restart() async {
    await Future.delayed(const Duration(milliseconds: 500));
    controller.playlistsMap.value.clear();
    await controller.prepareAllPlaylists();
    await pumpEventQueue();
  }

  test('a namida playlist renamed in namida keeps its tracks and artwork', () async {
    await controller.addNewPlaylist('json old');
    writeArtwork('json old');

    final didRename = await controller.renamePlaylist('json old', 'json new');
    expect(didRename, isTrue);
    expect(controller.getPlaylist('json new'), isNotNull);
    expect(hasArtwork('json new'), isTrue);

    await restart();
    expect(controller.getPlaylist('json new'), isNotNull);
    expect(controller.getPlaylist('json old'), isNull);
  });

  for (final isLinked in [false, true]) {
    for (final hasNameHeader in [false, true]) {
      final where = isLinked ? 'a linked file' : 'the m3u folder';
      final header = hasNameHeader ? ' with a name header' : '';
      test('an m3u playlist in $where$header renamed in namida keeps its file, metadata and artwork', () async {
        final prefix = '${isLinked ? 'linked' : 'own'}${hasNameHeader ? ' header' : ''}';
        final oldName = hasNameHeader ? '$prefix old' : '$prefix file';
        final newName = '$prefix new';
        final m3uDirectory = isLinked ? musicDirectory : AppDirs.M3UPlaylists;
        final headerLines = ['#TAGS:Kept', if (hasNameHeader) '#PLAYLIST:$oldName'];
        final m3uPath = writeM3U(m3uDirectory, '$prefix file.m3u', headerLines: headerLines);
        await controller.prepareM3UPlaylists(forPaths: {m3uPath});
        await pumpEventQueue();
        expect(controller.getPlaylist(oldName)?.m3uPath, m3uPath);
        writeArtwork(oldName);

        final didRename = await controller.renamePlaylist(oldName, newName);
        expect(didRename, isTrue);
        expect(controller.getPlaylist(newName)?.m3uPath, m3uPath);
        expect(controller.getPlaylist(newName)?.moods, ['Kept']);
        expect(controller.getPlaylist(oldName), isNull);
        expect(hasArtwork(newName), isTrue);
        expect(hasArtwork(oldName), isFalse);

        await restart();
        expect(controller.getPlaylist(newName)?.m3uPath, m3uPath);
        expect(controller.getPlaylist(newName)?.moods, ['Kept']);
        expect(controller.getPlaylist(oldName), isNull);

        // -- without a name header the old name is still the file's own name, a same-named file gets its folder as a prefix
        if (!hasNameHeader) return;
        final freedNamePath = writeM3U(p.join(m3uDirectory, 'freed'), '$oldName.m3u');
        await controller.prepareM3UPlaylists(forPaths: {freedNamePath});
        await pumpEventQueue();
        expect(controller.getPlaylist(oldName)?.m3uPath, freedNamePath);
        expect(controller.getPlaylist(oldName)?.moods, isEmpty);
        expect(controller.getPlaylist(newName)?.m3uPath, m3uPath);
      });
    }
  }

  test('a file renamed outside namida keeps the old artwork, renaming the file back restores it', () async {
    final oldPath = writeM3U(AppDirs.M3UPlaylists, 'ext a.m3u');
    final newPath = p.join(AppDirs.M3UPlaylists, 'ext b.m3u');
    await refresh();
    expect(controller.getPlaylist('ext a')?.m3uPath, oldPath);
    writeArtwork('ext a');

    File(oldPath).renameSync(newPath);
    await refresh();
    expect(controller.getPlaylist('ext a'), isNull);
    expect(controller.getPlaylist('ext b')?.m3uPath, newPath);
    expect(hasArtwork('ext a'), isTrue);

    File(newPath).renameSync(oldPath);
    await refresh();
    expect(controller.getPlaylist('ext a')?.m3uPath, oldPath);
    expect(controller.getPlaylist('ext b'), isNull);
    expect(hasArtwork('ext a'), isTrue);
  });

  test('a file renamed outside namida gets the old artwork when renamed in namida to the old name', () async {
    final oldPath = writeM3U(AppDirs.M3UPlaylists, 'back a.m3u');
    final newPath = p.join(AppDirs.M3UPlaylists, 'back b.m3u');
    await refresh();
    writeArtwork('back a');
    File(oldPath).renameSync(newPath);
    await refresh();
    expect(controller.getPlaylist('back b')?.m3uPath, newPath);

    final didRename = await controller.renamePlaylist('back b', 'back a');
    expect(didRename, isTrue);
    expect(controller.getPlaylist('back a')?.m3uPath, newPath);
    expect(hasArtwork('back a'), isTrue);

    await restart();
    expect(controller.getPlaylist('back a')?.m3uPath, newPath);
    expect(controller.getPlaylist('back b'), isNull);
  });
}
