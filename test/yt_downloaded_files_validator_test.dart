// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

void main() {
  late Directory dir;
  late String downloadsPath;
  final sep = Platform.pathSeparator;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_yt_validator_test');
    AppDirs.USER_DATA = '${dir.path}$sep';
    downloadsPath = '${dir.path}${sep}downloads';
    Directory(downloadsPath).createSync();
    settings.youtube.ytDownloadLocation.save('$downloadsPath$sep');
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  setUp(() {
    YoutubeController.inst.youtubeDownloadTasksMap.value.clear();
    YoutubeController.inst.downloadedFilesMap.value.clear();
    Indexer.inst.allTracksMappedByYTID.clear();
  });

  YoutubeItemDownloadConfig createConfig(DownloadTaskGroupName groupName, String videoId, String filename, {bool splitByChapters = false}) {
    return YoutubeItemDownloadConfig(
      id: DownloadTaskVideoId(videoId: videoId),
      groupName: groupName,
      filename: DownloadTaskFilename.create(initialFilename: filename),
      ffmpegTags: {},
      fileDate: null,
      videoStream: null,
      audioStream: null,
      streamInfoItem: null,
      prefferedVideoQualityID: null,
      prefferedAudioQualityID: null,
      fetchMissingAudio: true,
      fetchMissingVideo: false,
      originalIndex: null,
      totalLength: null,
      playlistId: null,
      playlistInfo: null,
      addedAt: null,
      addAudioToLocalLibrary: false,
      autoExtractTitleAndArtist: false,
      keepCachedVersionsIfDownloaded: false,
      downloadFilesWriteUploadDate: false,
      deleteOldFile: false,
      removeSponsorSegments: false,
      splitByChapters: splitByChapters,
      chapter: null,
      sponsorSegmentsCategories: null,
      localPlaylistName: null,
      cacheOnly: false,
    );
  }

  String groupDirPath(DownloadTaskGroupName groupName) => groupName.groupName.isEmpty ? downloadsPath : '$downloadsPath$sep${groupName.groupName}';

  /// creates each file and registers it as a finished download, [fileOf] picks the file that marks it as done.
  void addFinishedTasks(DownloadTaskGroupName groupName, List<YoutubeItemDownloadConfig> configs, {File Function(YoutubeItemDownloadConfig config)? fileOf}) {
    final tasks = YoutubeController.inst.youtubeDownloadTasksMap.value[groupName] ??= {};
    final files = YoutubeController.inst.downloadedFilesMap.value[groupName] ??= {};
    for (final config in configs) {
      final file = fileOf?.call(config) ?? File('${groupDirPath(groupName)}$sep${config.filename.filename}');
      file.createSync(recursive: true);
      tasks[config.filename] = config;
      files[config.filename] = file;
    }
  }

  File? fileInMap(DownloadTaskGroupName groupName, YoutubeItemDownloadConfig config) => YoutubeController.inst.downloadedFilesMap.value[groupName]?[config.filename];

  group('validateDownloadedFiles', () {
    test('files deleted from the group folder are dropped, the rest stay', () async {
      final groupName = DownloadTaskGroupName(groupName: 'deleted_files');
      final kept = createConfig(groupName, 'aaaaaaaaaaa', 'kept.m4a');
      final deleted = createConfig(groupName, 'bbbbbbbbbbb', 'deleted.m4a');
      addFinishedTasks(groupName, [kept, deleted]);

      File('${groupDirPath(groupName)}${sep}deleted.m4a').deleteSync();
      final didFindMissing = await YoutubeController.inst.validateDownloadedFiles(groupName);

      expect(didFindMissing, true);
      expect(fileInMap(groupName, kept), isNotNull);
      expect(fileInMap(groupName, deleted), isNull);
    });

    test('a deleted group folder drops every file of the group', () async {
      final groupName = DownloadTaskGroupName(groupName: 'deleted_folder');
      final configs = [
        createConfig(groupName, 'aaaaaaaaaaa', 'first.m4a'),
        createConfig(groupName, 'bbbbbbbbbbb', 'second.m4a'),
      ];
      addFinishedTasks(groupName, configs);

      Directory(groupDirPath(groupName)).deleteSync(recursive: true);
      final didFindMissing = await YoutubeController.inst.validateDownloadedFiles(groupName);

      expect(didFindMissing, true);
      for (final config in configs) {
        expect(fileInMap(groupName, config), isNull, reason: config.filename.filename);
      }
    });

    test('nothing missing reports no change', () async {
      final groupName = DownloadTaskGroupName(groupName: 'untouched');
      final config = createConfig(groupName, 'aaaaaaaaaaa', 'song.m4a');
      addFinishedTasks(groupName, [config]);

      final didFindMissing = await YoutubeController.inst.validateDownloadedFiles(groupName);

      expect(didFindMissing, false);
      expect(fileInMap(groupName, config), isNotNull);
    });

    test('split downloads stay while their chapters folder exists, and drop with it', () async {
      final groupName = DownloadTaskGroupName(groupName: 'chapters');
      final config = createConfig(groupName, 'aaaaaaaaaaa', 'album.m4a', splitByChapters: true);
      final chaptersDirPath = '${groupDirPath(groupName)}${sep}album';
      addFinishedTasks(groupName, [config], fileOf: (_) => File('$chaptersDirPath${sep}01 intro.m4a'));

      expect(await YoutubeController.inst.validateDownloadedFiles(groupName), false);
      expect(fileInMap(groupName, config), isNotNull);

      Directory(chaptersDirPath).deleteSync(recursive: true);
      expect(await YoutubeController.inst.validateDownloadedFiles(groupName), true);
      expect(fileInMap(groupName, config), isNull);
    });

    test('validating every group drops missing files across groups', () async {
      final firstGroup = DownloadTaskGroupName(groupName: 'all_first');
      final secondGroup = DownloadTaskGroupName(groupName: 'all_second');
      final firstConfig = createConfig(firstGroup, 'aaaaaaaaaaa', 'one.m4a');
      final secondConfig = createConfig(secondGroup, 'bbbbbbbbbbb', 'two.m4a');
      addFinishedTasks(firstGroup, [firstConfig]);
      addFinishedTasks(secondGroup, [secondConfig]);

      File('${groupDirPath(secondGroup)}${sep}two.m4a').deleteSync();
      await YoutubeController.inst.validateAllDownloadedFiles();

      expect(fileInMap(firstGroup, firstConfig), isNotNull);
      expect(fileInMap(secondGroup, secondConfig), isNull);
    });
  });

  group('library fallback', () {
    void addLibraryTrack(String videoId, String path) {
      final tracks = Indexer.inst.allTracksMappedByYTID[videoId] ??= [];
      tracks.add(Track.explicit(path));
    }

    test('library tracks inside the group folder count as downloaded without any task', () {
      final groupName = DownloadTaskGroupName(groupName: 'library');
      addLibraryTrack('aaaaaaaaaaa', '${groupDirPath(groupName)}${sep}song.m4a');
      addLibraryTrack('bbbbbbbbbbb', '${dir.path}${sep}elsewhere${sep}song.m4a');
      addLibraryTrack('ccccccccccc', '${groupDirPath(groupName)}${sep}sub${sep}song.m4a');

      final downloadedIds = YoutubeController.inst.getDownloadedVideoIdsInGroup(['aaaaaaaaaaa', 'bbbbbbbbbbb', 'ccccccccccc', 'ddddddddddd'], groupName);

      expect(downloadedIds, {'aaaaaaaaaaa'});
    });

    test('the default group matches tracks directly inside the downloads folder only', () {
      const defaultGroup = DownloadTaskGroupName.defaulty();
      addLibraryTrack('aaaaaaaaaaa', '$downloadsPath${sep}song.m4a');
      addLibraryTrack('bbbbbbbbbbb', '$downloadsPath${sep}Favourites${sep}song.m4a');

      final downloadedIds = YoutubeController.inst.getDownloadedVideoIdsInGroup(['aaaaaaaaaaa', 'bbbbbbbbbbb'], defaultGroup);

      expect(downloadedIds, {'aaaaaaaaaaa'});
    });

    test('any group counts for a video when its track is anywhere inside the downloads folder', () {
      addLibraryTrack('aaaaaaaaaaa', '$downloadsPath${sep}Favourites${sep}song.m4a');
      addLibraryTrack('bbbbbbbbbbb', '${dir.path}${sep}downloads_other${sep}song.m4a');

      expect(YoutubeController.inst.doesIDHasFileDownloaded(const DownloadTaskVideoId(videoId: 'aaaaaaaaaaa')), isNotNull);
      expect(YoutubeController.inst.doesIDHasFileDownloaded(const DownloadTaskVideoId(videoId: 'bbbbbbbbbbb')), isNull);
    });
  });
}
