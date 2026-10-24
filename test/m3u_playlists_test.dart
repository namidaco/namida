// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';

void main() {
  final windows = p.Context(style: p.Style.windows, current: r'C:\cwd');
  final posix = p.Context(style: p.Style.posix, current: '/cwd');
  const otherAppHeader = [
    '#EXTENC:UTF-8', '#PLAYLIST:Paloquequieras', '#UUID:', '#LOCKED:false', '#CATEGORY:', '#TAGS:Fav;Fiio', //
    '#TRACKTAGS:', '#PLAYLISTSIZE:37', '#DURATION:9586.32', '#AUTHOR:Playlist-Manager-SMP', '#DESCRIPTION:A playlist for a friend', //
  ];

  ({String path, bool isResolved}) resolve(String line, String m3uDirectory, p.Context context, Set<String> existingPaths) {
    return M3UFiles.resolveEntryLine(line, m3uDirectory, context, existingPaths.contains);
  }

  String exportLine(String path, String m3uDirectory, p.Context context) => M3UFiles.toEntryLine(path, m3uDirectory, context);

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
      final savedNames = M3UFiles.getSavedNamesByPath(m3uProperties, m3uPaths);
      return M3UFiles.allocatePlaylistNames(m3uPaths, savedNames, context);
    }

    Map<String, dynamic> savedAt(String m3uPath) => {'m3uPath': m3uPath};

    test('same-named files all get their folder as a prefix', () {
      final names = M3UFiles.allocatePlaylistNames({r'C:\X\a.m3u', r'C:\Y\a.m3u', r'C:\Z\a.m3u', r'C:\X\b.m3u'}, const {}, windows);
      expect(names, {r'C:\X\a.m3u': 'X - a', r'C:\Y\a.m3u': 'Y - a', r'C:\Z\a.m3u': 'Z - a', r'C:\X\b.m3u': 'b'});
    });

    test('same-named folders get a counter', () {
      final names = M3UFiles.allocatePlaylistNames({'/1/X/a.m3u', '/2/X/a.m3u'}, const {}, posix);
      expect(names, {'/1/X/a.m3u': 'X - a', '/2/X/a.m3u': 'X - a (2)'});
    });

    test('a refreshed file keeps the name of its playlist', () {
      final names = M3UFiles.allocatePlaylistNames({r'C:\X\a.m3u'}, {r'C:\X\a.m3u': 'X - a', r'C:\Y\a.m3u': 'Y - a'}, windows);
      expect(names, {r'C:\X\a.m3u': 'X - a'});
    });

    test('a new file does not take the playlist name of another file', () {
      final names = M3UFiles.allocatePlaylistNames({r'C:\Z\a.m3u'}, {r'C:\X\a.m3u': 'a'}, windows);
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

  group('headers', () {
    List<String> rewrite(List<String> lines, {String name = 'n', List<String> moods = const [], List<String> tags = const [], String description = ''}) {
      return M3UFiles.rewriteHeaderLines(lines, name: name, moods: moods, tags: tags, description: description, tracksCount: 2, computeDurationMS: () => 90500);
    }

    test('parses the values of other apps', () {
      final header = M3UFiles.parseHeaderLines(otherAppHeader);
      expect(header.name, 'Paloquequieras');
      expect(header.moods, ['Fav', 'Fiio']);
      expect(header.tags, isEmpty);
      expect(header.description, 'A playlist for a friend');
      expect(header.artUrl, isNull);
    });

    test('splits, trims and dedupes the lists', () {
      final header = M3UFiles.parseHeaderLines(['#TAGS: a ; b;;a ', '#CATEGORY:x / y; z', '#EXTALBUMARTURL: cover.jpg']);
      expect(header.moods, ['a', 'b']);
      expect(header.tags, ['x/y', 'z']);
      expect(header.artUrl, 'cover.jpg');
    });

    test('missing lines are null and empty lines are empty', () {
      final missing = M3UFiles.parseHeaderLines(['#PLAYLIST:n', '#UUID:x']);
      expect(missing.moods, isNull);
      expect(missing.tags, isNull);
      expect(missing.description, isNull);

      final empty = M3UFiles.parseHeaderLines(['#TAGS:', '#CATEGORY: ; ', '#DESCRIPTION:']);
      expect(empty.moods, isEmpty);
      expect(empty.tags, isEmpty);
      expect(empty.description, '');
    });

    test('the first of a repeated key is used', () {
      final header = M3UFiles.parseHeaderLines(['#PLAYLIST:first', '#PLAYLIST:second']);
      expect(header.name, 'first');
    });

    test('rewrites the values in place and keeps the other lines', () {
      final lines = rewrite(otherAppHeader, name: 'Paloquequieras', moods: ['Fav', 'Mine'], description: 'edited');
      expect(lines, [
        '#EXTENC:UTF-8', '#PLAYLIST:Paloquequieras', '#UUID:', '#LOCKED:false', '#CATEGORY:', '#TAGS:Fav;Mine', //
        '#TRACKTAGS:', '#PLAYLISTSIZE:2', '#DURATION:90.50', '#AUTHOR:Playlist-Manager-SMP', '#DESCRIPTION:edited', //
      ]);
    });

    test('adds the missing values that are not empty', () {
      final lines = rewrite(['#EXTALBUMARTURL:cover.jpg'], name: 'n', tags: ['a/b', 'c']);
      expect(lines, ['#EXTALBUMARTURL:cover.jpg', '#PLAYLIST:n', '#CATEGORY:a/b;c']);
    });

    test('size and duration are written only when the file had them', () {
      final lines = rewrite(const []);
      expect(lines, ['#PLAYLIST:n']);
    });

    test('parsing a rewritten header gives back the same values', () {
      final lines = rewrite(const [], name: 'n', moods: ['m1', 'm2'], tags: ['t/1'], description: 'd');
      final header = M3UFiles.parseHeaderLines(lines);
      expect(header.name, 'n');
      expect(header.moods, ['m1', 'm2']);
      expect(header.tags, ['t/1']);
      expect(header.description, 'd');
      expect(rewrite(lines, name: 'n', moods: ['m1', 'm2'], tags: ['t/1'], description: 'd'), lines);
    });

    group('merging', () {
      test('without a baseline both sides are joined', () {
        expect(M3UFiles.mergeHeaderItems(['a', 'b'], ['b', 'c'], null), ['a', 'b', 'c']);
        expect(M3UFiles.mergeHeaderItems(['a'], ['a'], null), isNull);
      });

      test('removing in another app sticks', () {
        expect(M3UFiles.mergeHeaderItems(['a', 'b'], ['a'], ['a', 'b']), ['a']);
      });

      test('adding in another app is joined with what namida added', () {
        expect(M3UFiles.mergeHeaderItems(['a', 'n'], ['a', 'x'], ['a']), ['a', 'n', 'x']);
      });

      test('removing in namida is kept while the file still has it', () {
        expect(M3UFiles.mergeHeaderItems(['a'], ['a', 'b'], ['a', 'b']), isNull);
      });

      test('nothing changed in the file keeps namida values', () {
        expect(M3UFiles.mergeHeaderItems(['n'], ['a'], ['a']), isNull);
      });

      test('text from the file is used only when it changed there', () {
        expect(M3UFiles.mergeHeaderText('mine', 'old', 'old'), isNull);
        expect(M3UFiles.mergeHeaderText('mine', 'new', 'old'), 'new');
        expect(M3UFiles.mergeHeaderText('', 'file', null), 'file');
        expect(M3UFiles.mergeHeaderText('mine', 'file', null), isNull);
        expect(M3UFiles.mergeHeaderText('same', 'same', 'old'), isNull);
      });

      test('a missing line keeps namida values', () {
        expect(M3UFiles.mergeHeaderItems(['a', 'b'], null, ['a', 'b']), isNull);
        expect(M3UFiles.mergeHeaderItems(['a'], null, null), isNull);
        expect(M3UFiles.mergeHeaderText('mine', null, 'mine'), isNull);
        expect(M3UFiles.mergeHeaderText('', null, null), isNull);
      });

      test('an empty line clears what the file had', () {
        expect(M3UFiles.mergeHeaderItems(['a', 'b'], const [], ['a', 'b']), isEmpty);
        expect(M3UFiles.mergeHeaderText('mine', '', 'mine'), '');
      });
    });
  });

  group('headers sync', () {
    late Directory dir;

    setUpAll(() {
      dir = Directory.systemTemp.createTempSync('namida_m3u_headers_test');
      AppDirs.INTERNAL_STORAGE = dir.path;
      AppDirs.USER_DATA = dir.path;
      Directory(AppDirs.M3UBackup).createSync(recursive: true);
      settings.enableM3USync.save(true);
    });
    tearDownAll(() => dir.deleteSync(recursive: true));

    test('edits from namida and from other apps both stay', () async {
      final musicDirectory = p.join(dir.path, 'Music');
      for (final name in ['a.flac', 'b.flac']) {
        File(p.join(musicDirectory, name)).createSync(recursive: true);
      }
      final m3uPath = p.join(musicDirectory, 'friend.m3u8');
      final m3uFile = File(m3uPath);
      final entryLines = ['#EXTINF:249,A - a', 'a.flac', '#EXTINF:222,B - b', 'b.flac'];
      m3uFile.writeAsStringSync(['#EXTM3U', ...otherAppHeader, ...entryLines].join('\r\n'));

      final controller = PlaylistController.inst;
      addTearDown(controller.playlistsMap.value.clear);
      Future<LocalPlaylist> prepare() async {
        await controller.prepareM3UPlaylists(forPaths: {m3uPath});
        await pumpEventQueue();
        return controller.getPlaylist('Paloquequieras')!;
      }

      var playlist = await prepare();
      expect(playlist.moods, ['Fav', 'Fiio']);
      expect(playlist.comment, 'A playlist for a friend');
      expect(playlist.tracks.length, 2);

      await controller.updatePlaylistsMetadata({
        playlist.name: const PlaylistMetadataEdit(moods: ['Fav', 'Fiio', 'Mine'], tags: ['shared/friends']),
      });
      await Future.delayed(const Duration(milliseconds: 2500));
      final writtenLines = m3uFile.readAsLinesSync();
      expect(writtenLines.take(12), [
        '#EXTM3U', '#EXTENC:UTF-8', '#PLAYLIST:Paloquequieras', '#UUID:', '#LOCKED:false', '#CATEGORY:shared/friends', //
        '#TAGS:Fav;Fiio;Mine', '#TRACKTAGS:', '#PLAYLISTSIZE:2', '#DURATION:0.00', '#AUTHOR:Playlist-Manager-SMP', '#DESCRIPTION:A playlist for a friend', //
      ]);
      expect(writtenLines.where((e) => e.isNotEmpty && !e.startsWith('# ')).skip(12), entryLines);

      final externallyEdited = writtenLines.map((e) => e.startsWith('#TAGS:') ? '#TAGS:Mine;Ext' : e).join('\n');
      m3uFile.writeAsStringSync(externallyEdited);
      playlist = await prepare();
      expect(playlist.moods, ['Mine', 'Ext']);
      expect(playlist.tags, ['shared/friends']);

      playlist = await prepare();
      expect(playlist.moods, ['Mine', 'Ext']);
    });

    test('lines dropped by other apps keep namida values, empty lines clear them', () async {
      final musicDirectory = p.join(dir.path, 'Converted');
      File(p.join(musicDirectory, 'a.flac')).createSync(recursive: true);
      final m3uPath = p.join(musicDirectory, 'converted.m3u8');
      final m3uFile = File(m3uPath);
      const entryLines = ['#EXTINF:249,A - a', 'a.flac'];
      void writeFile(List<String> headerLines) => m3uFile.writeAsStringSync(['#EXTM3U', ...headerLines, ...entryLines].join('\n'));
      writeFile(const []);

      final controller = PlaylistController.inst;
      addTearDown(controller.playlistsMap.value.clear);
      Future<LocalPlaylist> prepare() async {
        await controller.prepareM3UPlaylists(forPaths: {m3uPath});
        await pumpEventQueue();
        return controller.getPlaylist('converted')!;
      }

      void expectNamidaValues(LocalPlaylist playlist) {
        expect(playlist.moods, ['Chill', 'Night']);
        expect(playlist.tags, ['mine/weekly']);
        expect(playlist.comment, 'set in namida');
      }

      var playlist = await prepare();
      await controller.updatePlaylistsMetadata({
        playlist.name: const PlaylistMetadataEdit(moods: ['Chill', 'Night'], tags: ['mine/weekly'], comment: 'set in namida'),
      });
      await Future.delayed(const Duration(milliseconds: 2500));
      expect(m3uFile.readAsLinesSync(), containsAll(['#TAGS:Chill;Night', '#CATEGORY:mine/weekly', '#DESCRIPTION:set in namida']));

      writeFile(const ['#PLAYLIST:converted']);
      playlist = await prepare();
      expectNamidaValues(playlist);

      controller.playlistsMap.value.clear();
      playlist = await prepare();
      expectNamidaValues(playlist);

      writeFile(const ['#TAGS:', '#CATEGORY:other']);
      playlist = await prepare();
      expect(playlist.moods, isEmpty);
      expect(playlist.tags, ['other']);
      expect(playlist.comment, 'set in namida');
    });

    test('a linked file outside the scanned folders stays after a full refresh', () async {
      settings.enableM3USyncStartup.save(false);
      final outsideDirectory = p.join(dir.path, 'Outside');
      File(p.join(outsideDirectory, 'c.flac')).createSync(recursive: true);
      final m3uPath = p.join(outsideDirectory, 'outside.m3u');
      File(m3uPath).writeAsStringSync(['#EXTM3U', 'c.flac'].join('\n'));

      final controller = PlaylistController.inst;
      addTearDown(controller.playlistsMap.value.clear);
      await controller.prepareM3UPlaylists(forPaths: {m3uPath});
      await pumpEventQueue();
      expect(controller.getPlaylist('outside')?.m3uPath, m3uPath);

      await controller.prepareM3UPlaylists();
      await pumpEventQueue();
      expect(controller.getPlaylist('outside')?.m3uPath, m3uPath);
    });
  });

  group('tracks common folder', () {
    final windows = p.Context(style: p.Style.windows, current: r'C:\cwd');
    final posix = p.Context(style: p.Style.posix, current: '/cwd');

    String? commonOf(List<String> paths, p.Context context) {
      final tracks = paths.map((e) => TrackWithDate(dateAdded: 0, track: Track.explicit(e))).toList();
      return M3UFiles.getCommonTracksDirectory(tracks, context);
    }

    test('deepest folder holding all tracks', () {
      expect(commonOf([r'C:\M\a\1.mp3', r'C:\M\b\2.mp3', r'C:\M\a\c\3.mp3'], windows), r'C:\M');
      expect(commonOf([r'C:\M\a\1.mp3', r'C:\M\a\2.mp3'], windows), r'C:\M\a');
      expect(commonOf(['/storage/emulated/0/Music/a.mp3', '/storage/emulated/0/Download/b.mp3'], posix), '/storage/emulated/0');
    });

    test('a folder name prefix is not a common folder', () {
      expect(commonOf(['/m/ab/1.mp3', '/m/a/2.mp3'], posix), '/m');
    });

    test('different drives, drive roots and server tracks have none', () {
      expect(commonOf([r'C:\M\1.mp3', r'D:\M\2.mp3'], windows), isNull);
      expect(commonOf([r'C:\1.mp3', r'C:\M\2.mp3'], windows), isNull);
      expect(commonOf(['/a/1.mp3', '/b/2.mp3'], posix), isNull);
      expect(commonOf(['/m/1.mp3', 'https://server/2.mp3'], posix), isNull);
      expect(commonOf(const [], posix), isNull);
    });
  });

  group('m3u file names', () {
    String linuxPath(String name) => M3UFiles.getUniqueFilePath(name, '/m', posix, shouldReplaceReservedChars: false, isTaken: (_) => false);
    String androidPath(String name) => M3UFiles.getUniqueFilePath(name, '/m', posix, shouldReplaceReservedChars: true, isTaken: (_) => false);
    String windowsPath(String name, [Set<String> takenPaths = const {}]) {
      return M3UFiles.getUniqueFilePath(name, r'C:\m', windows, shouldReplaceReservedChars: true, isTaken: takenPaths.contains);
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
