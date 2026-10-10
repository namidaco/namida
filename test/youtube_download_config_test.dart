// by claude
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';

void main() {
  YoutubeItemDownloadConfig createConfig({required DateTime? fileDate, bool cacheOnly = false}) {
    return YoutubeItemDownloadConfig(
      id: const DownloadTaskVideoId(videoId: 'dQw4w9WgXcQ'),
      groupName: DownloadTaskGroupName(groupName: 'group'),
      filename: DownloadTaskFilename.create(initialFilename: 'title.m4a'),
      ffmpegTags: {'title': 'Title', 'comment': null},
      fileDate: fileDate,
      videoStream: null,
      audioStream: null,
      streamInfoItem: null,
      prefferedVideoQualityID: '1080p',
      prefferedAudioQualityID: '140',
      fetchMissingAudio: true,
      fetchMissingVideo: false,
      originalIndex: 3,
      totalLength: 10,
      playlistId: 'PL123',
      playlistInfo: null,
      addedAt: DateTime.fromMicrosecondsSinceEpoch(1700000000123456),
      addAudioToLocalLibrary: true,
      autoExtractTitleAndArtist: false,
      keepCachedVersionsIfDownloaded: true,
      downloadFilesWriteUploadDate: true,
      deleteOldFile: false,
      removeSponsorSegments: true,
      splitByChapters: true,
      chapter: const YoutubeDownloadChapter(startMS: 1000, endMS: 5000, title: 'intro', number: 1, total: 4),
      sponsorSegmentsCategories: ['sponsor', 'selfpromo'],
      localPlaylistName: 'local',
      cacheOnly: cacheOnly,
    );
  }

  Map<String, dynamic> saved(YoutubeItemDownloadConfig config) {
    final encoded = jsonEncode(config.toJson());
    return jsonDecode(encoded) as Map<String, dynamic>;
  }

  test('every field survives saving and loading', () {
    final fileDate = DateTime.fromMillisecondsSinceEpoch(1600000000123);
    final config = createConfig(fileDate: fileDate, cacheOnly: true);
    final json = saved(config);
    final loaded = YoutubeItemDownloadConfig.fromJson(json);

    expect(loaded, config);
    expect(loaded.filename.filename, 'title.m4a');
    expect(loaded.fileDate, fileDate);
    expect(loaded.addedAt, config.addedAt);
    expect(loaded.cacheOnly, true);
    expect(loaded.toJson(), config.toJson());
  });

  test('an unknown file date stays unknown instead of becoming 1970', () {
    final config = createConfig(fileDate: null);
    final json = saved(config);
    expect(YoutubeItemDownloadConfig.fromJson(json).fileDate, null);

    final legacyJson = {...json, 'fileDate': 0};
    expect(YoutubeItemDownloadConfig.fromJson(legacyJson).fileDate, null);
  });
}
