// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/constants.dart';

void main() {
  final windows = p.Context(style: p.Style.windows, current: r'C:\cwd');
  final posix = p.Context(style: p.Style.posix, current: '/cwd');

  ({String path, bool isResolved}) resolve(String line, String m3uDirectory, p.Context context, Set<String> existingPaths) {
    return PlaylistController.resolveM3UEntryLine(line, m3uDirectory, context, existingPaths.contains);
  }

  String exportLine(String path, String m3uDirectory, p.Context context) => PlaylistController.m3uEntryLine(path, m3uDirectory, context);

  String roundTrip(String path, String m3uDirectory, p.Context context) {
    final line = exportLine(path, m3uDirectory, context);
    return resolve(line, m3uDirectory, context, {path}).path;
  }

  group('export then parse keeps the paths', () {
    test('relative to the m3u folder', () {
      const m3uDirectory = r'C:\m\pl';
      final paths = [r'C:\m\a.mp3', r'C:\m\sub\b.mp3', r'C:\m\pl\c.mp3'];
      final lines = paths.map((e) => exportLine(e, m3uDirectory, windows)).toList();
      expect(lines, [r'..\a.mp3', r'..\sub\b.mp3', 'c.mp3']);
      expect(paths.map((e) => roundTrip(e, m3uDirectory, windows)), paths);
    });

    test('relative to the m3u folder on posix', () {
      const m3uDirectory = '/storage/emulated/0/Playlists';
      final paths = ['/storage/emulated/0/Music/a.mp3', '/storage/1234-5678/b.mp3'];
      final lines = paths.map((e) => exportLine(e, m3uDirectory, posix)).toList();
      expect(lines, ['../Music/a.mp3', '../../../1234-5678/b.mp3']);
      expect(paths.map((e) => roundTrip(e, m3uDirectory, posix)), paths);
    });

    test('another drive stays absolute', () {
      expect(exportLine(r'D:\music\a.mp3', r'C:\m\pl', windows), r'D:\music\a.mp3');
      expect(roundTrip(r'D:\music\a.mp3', r'C:\m\pl', windows), r'D:\music\a.mp3');
    });

    test('urls stay as they are', () {
      const urls = ['http://192.168.1.2:4533/rest/stream?id=a/b&c=d', 'https://example.com/music/a%20b.mp3'];
      for (final url in urls) {
        expect(exportLine(url, r'C:\m\pl', windows), url);
        expect(exportLine(url, '/m/pl', posix), url);
        expect(resolve(url, r'C:\m\pl', windows, {}), (path: url, isResolved: true));
        expect(resolve(url, '/m/pl', posix, {}), (path: url, isResolved: true));
      }
    });
  });

  group('parsing', () {
    test('relative lines resolve against the m3u folder, not the working directory', () {
      final res = resolve('a.mp3', '/m/pl', posix, {'a.mp3', '/cwd/a.mp3', '/m/pl/a.mp3'});
      expect(res, (path: '/m/pl/a.mp3', isResolved: true));
    });

    test('root relative lines use the drive of the m3u folder', () {
      final res = resolve(r'\music\a.mp3', r'D:\pl', windows, {r'\music\a.mp3', r'C:\music\a.mp3', r'D:\music\a.mp3'});
      expect(res, (path: r'D:\music\a.mp3', isResolved: true));
    });

    test('unc paths stay unc on windows', () {
      for (final line in [r'\\nas\music\a.mp3', '//nas/music/a.mp3']) {
        final res = resolve(line, r'C:\pl', windows, {r'\\nas\music\a.mp3'});
        expect(res, (path: r'\\nas\music\a.mp3', isResolved: true));
      }
      final inShare = resolve(r'sub\b.mp3', r'\\nas\music\pl', windows, {r'\\nas\music\pl\sub\b.mp3'});
      expect(inShare, (path: r'\\nas\music\pl\sub\b.mp3', isResolved: true));
      expect(exportLine(r'\\nas\music\a.mp3', r'C:\pl', windows), r'\\nas\music\a.mp3');
      expect(roundTrip(r'\\nas\music\a.mp3', r'\\nas\music\pl', windows), r'\\nas\music\a.mp3');
    });

    test('file uris become paths', () {
      final windowsRes = resolve('file:///C:/Music/My%20Song.mp3', r'D:\pl', windows, {r'C:\Music\My Song.mp3'});
      expect(windowsRes, (path: r'C:\Music\My Song.mp3', isResolved: true));
      final posixRes = resolve('file:///home/u/My%20Song.mp3', '/pl', posix, {'/home/u/My Song.mp3'});
      expect(posixRes, (path: '/home/u/My Song.mp3', isResolved: true));
    });

    test('primary prefix is dropped and mixed separators are normalized', () {
      final primary = resolve('primary/Music/a.mp3', '/storage/emulated/0', posix, {'/storage/emulated/0/Music/a.mp3'});
      expect(primary, (path: '/storage/emulated/0/Music/a.mp3', isResolved: true));
      final mixedOnWindows = resolve(r'..\Music/sub\a.mp3', r'C:\m\pl', windows, {r'C:\m\Music\sub\a.mp3'});
      expect(mixedOnWindows, (path: r'C:\m\Music\sub\a.mp3', isResolved: true));
      final windowsOnPosix = resolve(r'..\Music\a.mp3', '/storage/emulated/0/Playlists', posix, {'/storage/emulated/0/Music/a.mp3'});
      expect(windowsOnPosix, (path: '/storage/emulated/0/Music/a.mp3', isResolved: true));
    });

    test('posix lines missing their leading slash fall back to the root after the m3u folder', () {
      const line = 'storage/emulated/0/Music/a.mp3';
      const m3uDirectory = '/storage/emulated/0/Playlists';
      final rooted = resolve(line, m3uDirectory, posix, {'/storage/emulated/0/Music/a.mp3'});
      expect(rooted, (path: '/storage/emulated/0/Music/a.mp3', isResolved: true));
      final inM3UFolder = resolve(line, m3uDirectory, posix, {'/storage/emulated/0/Music/a.mp3', '$m3uDirectory/$line'});
      expect(inM3UFolder, (path: '$m3uDirectory/$line', isResolved: true));
    });

    test('windows lines never fall back to the root', () {
      final res = resolve(r'music\a.mp3', r'D:\pl', windows, {r'\music\a.mp3', r'D:\music\a.mp3'});
      expect(res, (path: r'D:\pl\music\a.mp3', isResolved: false));
    });

    test('missing files are left to the library lookup', () {
      final res = resolve('../gone/a.mp3', '/m/pl', posix, {});
      expect(res, (path: '/m/gone/a.mp3', isResolved: false));
    });
  });

  group('playlist names', () {
    Map<String, String> startupNames(Map<String, Map<String, dynamic>> m3uProperties, Set<String> m3uPaths, p.Context context) {
      final savedNames = PlaylistController.getSavedM3UNamesByPath(m3uProperties, m3uPaths);
      return PlaylistController.allocateM3UPlaylistNames(m3uPaths, savedNames, context);
    }

    Map<String, dynamic> savedAt(String m3uPath) => {'m3uPath': m3uPath};

    test('same-named files all get their folder as a prefix', () {
      final names = PlaylistController.allocateM3UPlaylistNames({r'C:\X\a.m3u', r'C:\Y\a.m3u', r'C:\Z\a.m3u', r'C:\X\b.m3u'}, const {}, windows);
      expect(names, {r'C:\X\a.m3u': 'X - a', r'C:\Y\a.m3u': 'Y - a', r'C:\Z\a.m3u': 'Z - a', r'C:\X\b.m3u': 'b'});
    });

    test('same-named folders get a counter', () {
      final names = PlaylistController.allocateM3UPlaylistNames({'/1/X/a.m3u', '/2/X/a.m3u'}, const {}, posix);
      expect(names, {'/1/X/a.m3u': 'X - a', '/2/X/a.m3u': 'X - a (2)'});
    });

    test('a refreshed file keeps the name of its playlist', () {
      final names = PlaylistController.allocateM3UPlaylistNames({r'C:\X\a.m3u'}, {r'C:\X\a.m3u': 'X - a', r'C:\Y\a.m3u': 'Y - a'}, windows);
      expect(names, {r'C:\X\a.m3u': 'X - a'});
    });

    test('a new file does not take the playlist name of another file', () {
      final names = PlaylistController.allocateM3UPlaylistNames({r'C:\Z\a.m3u'}, {r'C:\X\a.m3u': 'a'}, windows);
      expect(names, {r'C:\Z\a.m3u': 'Z - a'});
    });

    test('files keep the names they were saved with', () {
      const path = r'C:\M3U Playlists\Rating _ 4.m3u';
      final names = startupNames({'Rating > 4': savedAt(path)}, {path}, windows);
      expect(names, {path: 'Rating > 4'});
    });

    test('same-named files keep their saved names', () {
      final paths = {'/A/p.m3u', '/B/p.m3u', '/C/p.m3u'};
      final names = startupNames({'A - p': savedAt('/A/p.m3u'), 'B - p': savedAt('/B/p.m3u'), 'p': savedAt('/C/p.m3u')}, paths, posix);
      expect(names, {'/A/p.m3u': 'A - p', '/B/p.m3u': 'B - p', '/C/p.m3u': 'p'});
    });

    test('names saved for missing files are free for others', () {
      final names = startupNames({'p': savedAt('/old/p.m3u')}, {'/new/p.m3u'}, posix);
      expect(names, {'/new/p.m3u': 'p'});
    });

    test('a path saved under several names keeps the last one', () {
      final names = startupNames({'p': savedAt('/X/p.m3u'), 'X - p': savedAt('/X/p.m3u')}, {'/X/p.m3u'}, posix);
      expect(names, {'/X/p.m3u': 'X - p'});
    });
  });

  group('m3u file names', () {
    String linuxPath(String name) => PlaylistController.getUniqueM3UFilePath(name, '/m', posix, shouldReplaceReservedChars: false, isTaken: (_) => false);
    String androidPath(String name) => PlaylistController.getUniqueM3UFilePath(name, '/m', posix, shouldReplaceReservedChars: true, isTaken: (_) => false);
    String windowsPath(String name, [Set<String> takenPaths = const {}]) {
      return PlaylistController.getUniqueM3UFilePath(name, r'C:\m', windows, shouldReplaceReservedChars: true, isTaken: takenPaths.contains);
    }

    test('posix only replaces the separator', () {
      expect(linuxPath('Rating > 4'), '/m/Rating > 4.m3u');
      expect(linuxPath('Mix: "a" | b? *'), '/m/Mix: "a" | b? *.m3u');
      expect(linuxPath(r'AC\DC'), r'/m/AC\DC.m3u');
      expect(linuxPath('a/b'), '/m/a_b.m3u');
    });

    test('windows and android replace reserved chars', () {
      expect(windowsPath('Rating > 4'), r'C:\m\Rating _ 4.m3u');
      expect(windowsPath(r'a<b>c:d"e/f\g|h?i*j'), r'C:\m\a_b_c_d_e_f_g_h_i_j.m3u');
      expect(windowsPath('a\tb\x7Fc'), r'C:\m\a_b_c.m3u');
      expect(androidPath('Rating > 4'), '/m/Rating _ 4.m3u');
      expect(androidPath(r'AC\DC'), '/m/AC_DC.m3u');
    });

    test('names sharing a file get numbered', () {
      final first = windowsPath('Plays > 10');
      final second = windowsPath('Plays < 10', {first});
      final third = windowsPath('Plays | 10', {first, second});
      expect([first, second, third], [r'C:\m\Plays _ 10.m3u', r'C:\m\Plays _ 10 (2).m3u', r'C:\m\Plays _ 10 (3).m3u']);
    });
  });

  group('m3u file of a playlist name', () {
    late Directory dir;

    setUpAll(() {
      dir = Directory.systemTemp.createTempSync('namida_m3u_playlists_test');
      AppDirs.INTERNAL_STORAGE = dir.path;
      AppDirs.USER_DATA = dir.path;
    });
    tearDownAll(() => dir.deleteSync(recursive: true));

    LocalPlaylist playlistOf(String name, {String? m3uPath}) {
      return LocalPlaylist(name: name, tracks: [], creationDate: 0, modifiedDate: 0, comment: '', moods: [], isFav: false, m3uPath: m3uPath, sortsType: null, sortReverse: false);
    }

    test('stays inside the m3u folder', () {
      final m3uDirectory = p.normalize(AppDirs.M3UPlaylists);
      const names = ['../../evil', r'..\..\evil', '/etc/passwd', r'C:\Windows\evil', 'a/b', '..', 'a:b', 'a<b>c|d?e*f"g'];
      for (final name in names) {
        final path = PlaylistController.getUnusedM3uFilePathInStorage(name);
        expect(p.dirname(path), m3uDirectory, reason: name);
      }
    });

    test('keeps safe names as they are', () {
      final path = PlaylistController.getUnusedM3uFilePathInStorage('Workout #1 (2024)!');
      expect(p.basename(path), 'Workout #1 (2024)!.m3u');
    });

    test('a name sharing its file name with another file gets its own file', () {
      File(p.join(AppDirs.M3UPlaylists, 'x_y.m3u')).createSync(recursive: true);
      final path = PlaylistController.getUnusedM3uFilePathInStorage('x/y');
      expect(path, p.join(AppDirs.M3UPlaylists, 'x_y (2).m3u'));
    });

    test('a playlist keeps its own m3u file in the m3u folder', () {
      final ownPath = p.join(AppDirs.M3UPlaylists, 'saved before.m3u');
      final externalPath = p.join(dir.path, 'Music', 'external.m3u');
      final playlists = PlaylistController.inst.playlistsMap.value;
      playlists['own'] = playlistOf('own', m3uPath: ownPath);
      playlists['external'] = playlistOf('external', m3uPath: externalPath);
      addTearDown(playlists.clear);
      expect(PlaylistController.getUnusedM3uFilePathInStorage('own'), ownPath);
      expect(PlaylistController.getUnusedM3uFilePathInStorage('external'), p.join(AppDirs.M3UPlaylists, 'external.m3u'));
    });

    test('exported names sharing a file name get their own files', () async {
      final playlists = PlaylistController.inst.playlistsMap.value;
      playlists['a/b'] = playlistOf('a/b');
      playlists['a_b'] = playlistOf('a_b');
      addTearDown(playlists.clear);
      final exportDirectory = p.join(dir.path, 'Export');
      final exportedCount = await PlaylistController.inst.exportPlaylistsToM3UFiles(['a/b', 'a_b'], exportDirectory);
      final filenames = Directory(exportDirectory).listSync().map((e) => p.basename(e.path)).toSet();
      expect(exportedCount, 2);
      expect(filenames, {'a_b.m3u', 'a_b (2).m3u'});
    });
  });
}
