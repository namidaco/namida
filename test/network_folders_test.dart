// by claude
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opensubsonic_api/opensubsonic_api.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/core/constants.dart';

void main() {
  late Directory dir;
  late SplitArtistGenreConfigsWrapper splitConfig;
  const server = 'http://192.168.1.5:8096?namida_t=jellyfin&namida_u=me';

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_network_folders_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
    splitConfig = SplitArtistGenreConfigsWrapper(
      dbPath: '',
      artistsConfig: ArtistsSplitConfig(addFeatArtist: true, separators: const ['&'], separatorsBlacklist: const []),
      genresConfig: GenresSplitConfig(separators: const ['&'], separatorsBlacklist: const []),
      albumConfig: SimpleSplitConfig(),
      generalConfig: GeneralSplitConfig(),
    );
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  group('folder', () {
    final album = Folder.explicit(Folder.networkPathOf(server, 'music/Artist/Album'));

    test('root keeps the server key', () {
      expect(Folder.networkPathOf(server, null), server);
      expect(Folder.explicit(server).isNetworkRoot, true);
      expect(album.isNetwork, true);
      expect(album.isNetworkRoot, false);
    });

    test('name is the last server folder segment', () {
      expect(album.folderNameRaw, 'Album');
      expect(Folder.explicit(Folder.networkPathOf(server, 'C# Songs')).folderNameRaw, 'C# Songs');
    });

    test('parents walk up to the root, which has none', () {
      final artist = album.parent;
      expect(artist.path, Folder.networkPathOf(server, 'music/Artist'));
      final root = artist.parent.parent;
      expect(root.path, server);
      expect(root.parent.path, server);
    });

    test('inbetween folders start at the root and end at the folder itself', () {
      final paths = <String>[];
      album.performInbetweenFoldersBuild<Object>((f) {
        paths.add(f.path);
        return null;
      });
      expect(paths, [
        server,
        Folder.networkPathOf(server, 'music'),
        Folder.networkPathOf(server, 'music/Artist'),
        album.path,
      ]);
    });
  });

  group('server folder', () {
    TrackExtended jellyfinTrackOf(String? path) => debugJellyfinItemToTrack({'Id': 'jf1', 'Name': 'Song', 'Type': 'Audio', 'Path': path}, splitConfig: splitConfig, server: server);

    test('jellyfin absolute paths, unix and windows', () {
      expect(jellyfinTrackOf('/data/music/Artist/Album/01.flac').serverFolder, 'data/music/Artist/Album');
      expect(jellyfinTrackOf(r'D:\Music\Artist\01.flac').serverFolder, 'D:/Music/Artist');
      expect(jellyfinTrackOf('/01.flac').serverFolder, null);
      expect(jellyfinTrackOf(null).serverFolder, null);
    });

    test('subsonic relative paths', () {
      final trExt = debugSubsonicMediaToTrack(
        const MediaModel(id: 'so1', isDir: false, title: 'Song', path: 'Artist/Album/01.flac'),
        splitConfig: splitConfig,
        server: server,
      );
      expect(trExt.serverFolder, 'Artist/Album');
    });

    test('track folder path and name, also after a reload', () {
      final trExt = jellyfinTrackOf('/music/Artist/Album/01.flac');
      expect(trExt.folderPath, Folder.networkPathOf(server, 'music/Artist/Album'));
      expect(trExt.folderName, 'Album');
      final json = jsonDecode(jsonEncode(trExt.toJsonWithoutPath())) as Map<String, dynamic>;
      final reloaded = TrackExtended.fromJson(trExt.path, json, splitConfig: splitConfig);
      expect(reloaded.folderPath, trExt.folderPath);
    });

    test('tracks without a server folder stay in the server root', () {
      expect(jellyfinTrackOf(null).folderPath, server);
    });
  });
}
