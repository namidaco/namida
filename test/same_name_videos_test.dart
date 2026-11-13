// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/search_matcher.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dirs_file_filter.dart';

void main() {
  group('matcher', () {
    String? matchOne(String trackName, String videoName) {
      final matcher = SameNameVideosMatcher<String>();
      matcher.addTrack(trackName, trackName);
      return matcher.matchVideo(videoName);
    }

    const sameNames = {
      '1-02. Mushroom Cup Intro': ['1-02. Mushroom Cup Intro', '1-02 Mushroom Cup Intro', '1-02. MUSHROOM cup intro', '1-02. Mushroom Cup Intro (480p)', '1-02. Mushroom Cup Intro [1080p] (x264)'],
      'Sóng Biển': ['Song Bien', 'sóng biển {official}'],
      '夜に駆ける': ['夜に駆ける', '夜に駆ける (MV)'],
      'أغنية جميلة': ['أغنية جميلة', 'أغنية جميلة [HD]'],
      "Don't Stop": ['Dont Stop', "don't stop (Live)"],
    };
    for (final MapEntry(key: trackName, value: videoNames) in sameNames.entries) {
      for (final videoName in videoNames) {
        test('"$videoName" belongs to "$trackName"', () => expect(matchOne(trackName, videoName), trackName));
      }
    }

    const otherNames = {
      'Song': ['Song Two', 'Two Song', 'Song - Remix', '(480p) Song'],
      'Song (Live)': ['Song'],
      '1-02. Intro': ['1-03. Intro', 'Intro'],
    };
    for (final MapEntry(key: trackName, value: videoNames) in otherNames.entries) {
      for (final videoName in videoNames) {
        test('"$videoName" does not belong to "$trackName"', () => expect(matchOne(trackName, videoName), null));
      }
    }

    test('the full name wins over a shorter track name', () {
      final matcher = SameNameVideosMatcher<String>();
      matcher.addTrack('Song', 'studio');
      matcher.addTrack('Song (Live)', 'live');
      expect(matcher.matchVideo('Song (Live)'), 'live');
      expect(matcher.matchVideo('Song (Live) (720p)'), 'live');
      expect(matcher.matchVideo('Song (Official Video)'), 'studio');
    });

    test('folder videos map to the track they are named after', () {
      final files = [
        '/m/Song.mp3', '/m/Song (480p).mp4', '/m/Song (Live).flac', '/m/Song (Live) [1080p].mkv', //
        '/m/Other.mp4', '/m/Song.lrc', '/m/Cover.jpg', '/m/Cover.mp4',
        '/m/.Hidden.mp3', '/m/Hidden.mp4', '/m/Apple.mp3', '/m/._Apple.mp4',
        '/m/Blocked.wma', '/m/Blocked.webm',
      ];
      final trackExtensions = NamidaFileExtensionsWrapper.audioAndVideo.without(['wma']);
      final trackByVideo = SameNameVideosMatcher.matchFolder(files, (path) => path, trackExtensions: trackExtensions);
      expect(trackByVideo, {
        '/m/Song (480p).mp4': '/m/Song.mp3',
        '/m/Song (Live) [1080p].mkv': '/m/Song (Live).flac',
      });
    });

    test('folder without matches gives null', () {
      final audioOnly = ['/m/a.mp3', '/m/b.flac'];
      final videosOnly = ['/m/a.mp4', '/m/a (480p).mkv'];
      const trackExtensions = NamidaFileExtensionsWrapper.audioAndVideo;
      expect(SameNameVideosMatcher.matchFolder(audioOnly, (path) => path, trackExtensions: trackExtensions), null);
      expect(SameNameVideosMatcher.matchFolder(videosOnly, (path) => path, trackExtensions: trackExtensions), null);
    });

    test('sure track videos keep their old results', () {
      final videos = ['/v/Song (480p).mp4', '/v/Song.mkv', '/v/Song Two.mp4', '/v/Other [dQw4w9WgXcQ].mp4'];
      final sure = FilePathMatcher.getSureTrackVideos(videoPaths: videos, trackFilenameWOExt: 'Song', trackYTID: 'dQw4w9WgXcQ');
      expect(sure, {'/v/Song (480p).mp4', '/v/Song.mkv', '/v/Other [dQw4w9WgXcQ].mp4'});
    });
  });

  test('server videos cleared by an empty list', () {
    const video = NamidaVideo(
      path: 'https://server/?d=Song.mp4',
      height: 0,
      width: 0,
      sizeInBytes: 10,
      frameratePrecise: 0,
      creationTimeMS: 0,
      durationMS: 0,
      bitrate: 0,
    );
    final withVideos = kDummyExtendedTrack.copyWith(generatePathHash: false, serverVideos: [video]);
    expect(withVideos.serverVideos?.single.path, video.path);
    expect(withVideos.toJsonWithoutPath()['serverVideos'], hasLength(1));

    final cleared = withVideos.copyWith(generatePathHash: false, serverVideos: const []);
    expect(cleared.serverVideos, null);
    expect(cleared.toJsonWithoutPath().containsKey('serverVideos'), false);
  });

  group('local folders', () {
    late Directory settingsDir;
    late Directory root;
    final sep = Platform.pathSeparator;

    String pathOf(List<String> parts) => [root.path, ...parts].join(sep);

    void createFile(List<String> parts, {int size = 16}) {
      final file = File(pathOf(parts));
      file.createSync(recursive: true);
      file.writeAsBytesSync(List.filled(size, 1));
    }

    final videoExtensions = NamidaFileExtensionsWrapper.video.extensions.toList();
    final audioExtensions = NamidaFileExtensionsWrapper.audio.extensions.toList();
    final attachedVideos = <List<String>>[];
    final keptVideos = <List<String>>[];

    setUpAll(() {
      settingsDir = Directory.systemTemp.createTempSync('namida_same_name_settings');
      AppDirs.USER_DATA = '${settingsDir.path}$sep';
      root = Directory.systemTemp.createTempSync('namida_same_name');

      // -- every video extension next to an audio file of the same name, audio extensions rotate
      for (int i = 0; i < videoExtensions.length; i++) {
        final videoExt = videoExtensions[i];
        final audioExt = audioExtensions[i % audioExtensions.length];
        final upperVideoExt = i.isEven ? videoExt.toUpperCase() : videoExt;
        createFile(['pairs', 'track $i.$audioExt']);
        final video = ['pairs', 'track $i (720p).$upperVideoExt'];
        createFile(video, size: 100 + i);
        attachedVideos.add(video);
      }

      createFile(['mixed', '1-02. Mushroom Cup Intro.flac']);
      for (final v in [
        ['mixed', '1-02. Mushroom Cup Intro.mp4'],
        ['mixed', '1-02. Mushroom Cup Intro (1080p).mkv'],
      ]) {
        createFile(v);
        attachedVideos.add(v);
      }
      for (final v in [
        ['mixed', 'standalone video.mp4'],
        ['other folder', '1-02. Mushroom Cup Intro.mp4'],
        ['blacklisted', 'song.mp4'],
        ['hidden', 'song.mp4'],
        ['video only', 'a.mp4'],
        ['video only', 'a (480p).mkv'],
      ]) {
        createFile(v);
        keptVideos.add(v);
      }
      createFile(['blacklisted', 'song.wma']);
      createFile(['hidden', '.song.mp3']);

      settings.directoriesToScan.replace([DirectoryIndexLocal(root.path)]);
      settings.directoriesToExclude.replace([]);
    });

    tearDownAll(() {
      root.deleteSync(recursive: true);
      settingsDir.deleteSync(recursive: true);
    });

    Future<DirsFileFilterResult> filter({required bool useNativeLister, required bool skipSameNameVideos}) {
      final dirsFilterer = DirsFileFilter(
        extensions: NamidaFileExtensionsWrapper.audioAndVideo,
        blacklistExtensions: ['wma'],
        withStats: true,
        useNativeLister: useNativeLister,
        skipSameNameVideos: skipSameNameVideos,
      );
      return dirsFilterer.filterSync();
    }

    for (final useNativeLister in [true, false]) {
      test('videos named after audio next to them are skipped, native lister: $useNativeLister', () async {
        final all = await filter(useNativeLister: useNativeLister, skipSameNameVideos: false);
        final result = await filter(useNativeLister: useNativeLister, skipSameNameVideos: true);
        final attachedPaths = attachedVideos.map(pathOf).toSet();
        expect(result.allPaths, all.allPaths.difference(attachedPaths));
        for (final v in keptVideos) {
          expect(result.allPaths, contains(pathOf(v)));
        }
        for (final v in attachedVideos) {
          expect(all.allPaths, contains(pathOf(v)));
        }

        final stats = result.stats!;
        int index = 0;
        for (final path in result.allPaths) {
          expect(stats.sizeAt(index), File(path).lengthSync(), reason: path);
          index++;
        }
      });
    }
  });
}
