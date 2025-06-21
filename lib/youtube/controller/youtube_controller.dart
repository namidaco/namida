import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:rhttp/rhttp.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/class/videos/video_result.dart';
import 'package:youtipie/class/youtipie_description/youtipie_description.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/core/url_utils.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/notification_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/download_progress.dart';
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/class/youtube_id_stats.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/parallel_downloads_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_ongoing_finished_downloads.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

part 'youtube_id_stats_manager.dart';
part 'yt_filename_rebuilder.dart';

class _YTNotificationDataHolder {
  late final _speedMapVideo = <DownloadTaskFilename, int>{};
  late final _speedMapAudio = <DownloadTaskFilename, int>{};

  late final _titlesLookupTemp = <DownloadTaskVideoId, String?>{};
  late final _imagesLookupTemp = <DownloadTaskVideoId, File?>{};

  FutureOr<String?> titleCallback(DownloadTaskVideoId videoId) {
    final valInMap = _titlesLookupTemp[videoId];
    if (valInMap != null) return valInMap;
    return YoutubeInfoController.utils.getVideoName(videoId.videoId).then(
          (value) => _titlesLookupTemp[videoId] = value,
        );
  }

  FutureOr<File?> imageCallback(DownloadTaskVideoId videoId) {
    final valInMap = _imagesLookupTemp[videoId];
    if (valInMap != null) return valInMap;
    return ThumbnailManager.inst.getYoutubeThumbnailFromCache(id: videoId.videoId, type: ThumbnailType.video).then(
          (value) => _imagesLookupTemp[videoId] = value,
        );
  }

  void clearAll() {
    _speedMapVideo.clear();
    _speedMapAudio.clear();
    _titlesLookupTemp.clear();
    _imagesLookupTemp.clear();
  }
}

class YoutubeController {
  static YoutubeController get inst => _instance;
  static final YoutubeController _instance = YoutubeController._internal();
  YoutubeController._internal();

  final statsManager = _YoutubeIDStatsManager();

  final isLoadingDownloadTasks = false.obs;

  final downloadsVideoProgressMap = <DownloadTaskVideoId, RxMap<DownloadTaskFilename, DownloadProgress>>{}.obs;

  final downloadsAudioProgressMap = <DownloadTaskVideoId, RxMap<DownloadTaskFilename, DownloadProgress>>{}.obs;

  final currentSpeedsInByte = <DownloadTaskVideoId, RxMap<DownloadTaskFilename, int>>{}.obs;

  final isDownloading = <DownloadTaskVideoId, RxMap<DownloadTaskFilename, bool>>{}.obs;

  final isFetchingData = <DownloadTaskVideoId, RxMap<DownloadTaskFilename, bool>>{}.obs;

  final _downloadClientsMap = <DownloadTaskGroupName, Map<DownloadTaskFilename, File>>{};

  /// {groupName: {filename: YoutubeItemDownloadConfig}}
  final youtubeDownloadTasksMap = <DownloadTaskGroupName, Map<DownloadTaskFilename, YoutubeItemDownloadConfig>>{}.obs;

  /// {groupName: {filename: bool}}
  /// - `true` -> is in queue, will be downloaded when reached.
  /// - `false` -> is paused. will be skipped when reached.
  /// - `null` -> not specified.
  final youtubeDownloadTasksInQueueMap = <DownloadTaskGroupName, Map<DownloadTaskFilename, bool?>>{}.obs;

  /// {groupName: dateMS}
  ///
  /// used to sort group names by latest edited.
  var latestEditedGroupDownloadTask = <DownloadTaskGroupName, int>{};

  /// Used to keep track of existing downloaded files, more performant than real-time checking.
  ///
  /// {groupName: {filename: File}}
  final downloadedFilesMap = <DownloadTaskGroupName, Map<DownloadTaskFilename, File?>>{}.obs;

  late final _notificationData = _YTNotificationDataHolder();
  late final _downloadTasksMainDBManager = DBWrapperMain(AppDirs.YT_DOWNLOAD_TASKS);

  /// [renameCacheFiles] requires you to stop the download first, otherwise it might result in corrupted files.
  Future<void> renameConfigFilename({
    required YoutubeItemDownloadConfig config,
    required DownloadTaskVideoId videoID,
    required String newFilename,
    required DownloadTaskGroupName groupName,
    required bool renameCacheFiles,
  }) async {
    final oldFilename = config.filename.filename;

    // ignore: invalid_use_of_protected_member
    config.rename(newFilename);
    final downloadTasksGroupDB = _downloadTasksMainDBManager.getDB(groupName.groupName);
    await downloadTasksGroupDB.put(config.filename.key, config.toJson());

    final directory = Directory(FileParts.joinPath(AppDirs.YOUTUBE_DOWNLOADS, groupName.groupName));
    final existingFile = FileParts.join(directory.path, oldFilename);
    if (await existingFile.exists()) {
      try {
        await existingFile.rename(FileParts.joinPath(directory.path, newFilename));
      } catch (_) {}
    }
    if (renameCacheFiles) {
      final aFile = File(_getTempAudioPath(groupName: groupName, fullFilename: oldFilename));
      final vFile = File(_getTempVideoPath(groupName: groupName, fullFilename: oldFilename));

      if (await aFile.exists()) {
        final newPath = _getTempAudioPath(groupName: groupName, fullFilename: newFilename);
        await aFile.rename(newPath);
      }
      if (await vFile.exists()) {
        final newPath = _getTempVideoPath(groupName: groupName, fullFilename: newFilename);
        await vFile.rename(newPath);
      }
    }

    YTOnGoingFinishedDownloads.inst.refreshList();
  }

  AudioStream? getPreferredAudioStream(List<AudioStream> audiostreams) {
    return audiostreams.firstWhereEff((e) => !e.isWebm && e.audioTrack?.langCode == 'en') ?? audiostreams.firstWhereEff((e) => !e.isWebm) ?? audiostreams.firstOrNull;
  }

  VideoStream? getPreferredStreamQuality(List<VideoStream> streams, {List<String> qualities = const [], bool preferIncludeWebm = false}) {
    if (streams.isEmpty) return null;
    final allowExperimentalCodecs = settings.youtube.allowExperimentalCodecs;

    final preferredQualities = (qualities.isNotEmpty ? qualities : settings.youtubeVideoQualities.value);
    VideoStream? plsLoop(bool webm, bool experimentalCodecs) {
      for (int i = 0; i < streams.length; i++) {
        final q = streams[i];
        if (!webm && q.isWebm) continue;
        if (!experimentalCodecs && q.codecInfo.isExperimentalCodec()) continue;
        if (preferredQualities.any((e) => e.settingLabeltoVideoLabel() == q.qualityLabel.splitFirst('p'))) {
          return q;
        }
      }
      return null;
    }

    VideoStream? plsLoopMain(bool webm) {
      if (allowExperimentalCodecs) {
        return plsLoop(webm, true);
      } else {
        return plsLoop(webm, false) ?? plsLoop(webm, true);
      }
    }

    if (preferIncludeWebm) {
      return plsLoopMain(true) ?? streams.last;
    } else {
      return plsLoopMain(false) ?? plsLoopMain(true) ?? streams.last;
    }
  }

  void _loopMapAndPostNotification({
    required Map<DownloadTaskVideoId, RxMap<DownloadTaskFilename, bool>> downloadingMap,
    required int Function(DownloadTaskFilename key, int progress) speedInBytes,
    required DateTime startTime,
    required bool isAudio,
    required FutureOr<String?> Function(DownloadTaskVideoId videoId) titleCallback,
    required FutureOr<File?> Function(DownloadTaskVideoId videoId) imageCallback,
  }) async {
    List<void Function()>? pendingFnsAfterLoop;
    final downloadingText = isAudio ? "Audio" : "Video";
    for (final bigEntry in downloadingMap.entries) {
      final map = bigEntry.value.value;
      final videoId = bigEntry.key;
      for (final entry in map.entries) {
        final filename = entry.key;
        final progressInfo = (isAudio ? downloadsAudioProgressMap : downloadsVideoProgressMap).value[videoId]?.value[filename];
        if (progressInfo == null) continue;

        final p = progressInfo.progress;
        final tp = progressInfo.totalProgress;
        final percentage = p / tp;
        if (percentage >= 1 || percentage.isNaN || percentage.isInfinite) continue;

        final isRunning = entry.value;
        if (isRunning == false) {
          pendingFnsAfterLoop ??= [];
          pendingFnsAfterLoop.add(() {
            downloadingMap[videoId]?.remove(filename); // to ensure next iteration wont post pause again --^
          });
        }

        final title = await titleCallback(videoId) ?? videoId;
        final speedB = speedInBytes(filename, progressInfo.progress);
        if (currentSpeedsInByte.value[videoId] == null) {
          currentSpeedsInByte.value[videoId] = <DownloadTaskFilename, int>{}.obs;
          currentSpeedsInByte.refresh();
        }

        currentSpeedsInByte.value[videoId]![filename] = speedB;
        var keyword = isRunning ? 'Downloading' : 'Paused';
        NotificationManager.instance.downloadYoutubeNotification(
          filenameWrapper: entry.key,
          title: "$keyword $downloadingText: $title",
          progress: p,
          total: tp,
          subtitle: (progressText) => "$progressText (${speedB.fileSizeFormatted}/s)",
          imagePath: (await imageCallback(videoId))?.path,
          displayTime: startTime,
          isRunning: isRunning,
        );
      }
    }
    if (pendingFnsAfterLoop != null) {
      pendingFnsAfterLoop.loop((fn) => fn());
      pendingFnsAfterLoop = null;
    }
  }

  void _doneDownloadingNotification({
    required DownloadTaskVideoId videoId,
    required String videoTitle,
    required DownloadTaskFilename nameIdentifier,
    required File? downloadedFile,
    required DownloadTaskFilename filename,
    required bool canceledByUser,
  }) async {
    if (downloadedFile == null) {
      if (!canceledByUser) {
        NotificationManager.instance.doneDownloadingYoutubeNotification(
          filenameWrapper: nameIdentifier,
          videoTitle: videoTitle,
          subtitle: 'Download Failed',
          imagePath: (await _notificationData.imageCallback(videoId))?.path,
          failed: true,
        );
      }
    } else {
      final size = downloadedFile.fileSizeFormatted();
      NotificationManager.instance.doneDownloadingYoutubeNotification(
        filenameWrapper: nameIdentifier,
        videoTitle: downloadedFile.path.getFilenameWOExt,
        subtitle: size == null ? '' : 'Downloaded: $size',
        imagePath: (await _notificationData.imageCallback(videoId))?.path,
        failed: false,
      );
      // -- remove progress only if succeeded.
      downloadsVideoProgressMap[videoId]?.remove(filename);
      downloadsAudioProgressMap[videoId]?.remove(filename);
    }
    _tryCancelDownloadNotificationTimer();
  }

  Timer? _downloadNotificationTimer;
  void _tryCancelDownloadNotificationTimer() {
    if (downloadsVideoProgressMap.isEmpty && downloadsAudioProgressMap.isEmpty) {
      _downloadNotificationTimer?.cancel();
      _downloadNotificationTimer = null;
      _notificationData.clearAll();
    }
  }

  void _startNotificationTimer() {
    if (_downloadNotificationTimer == null) {
      final startTime = DateTime.now();

      _downloadNotificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _loopMapAndPostNotification(
          startTime: startTime,
          isAudio: false,
          downloadingMap: isDownloading.value,
          speedInBytes: (key, newProgress) {
            final previousProgress = _notificationData._speedMapVideo[key] ?? 0;
            final speed = newProgress - previousProgress;
            _notificationData._speedMapVideo[key] = newProgress;
            return speed;
          },
          titleCallback: _notificationData.titleCallback,
          imageCallback: _notificationData.imageCallback,
        );
        _loopMapAndPostNotification(
          startTime: startTime,
          isAudio: true,
          downloadingMap: isDownloading.value,
          speedInBytes: (key, newProgress) {
            final previousProgress = _notificationData._speedMapAudio[key] ?? 0;
            final speed = newProgress - previousProgress;
            _notificationData._speedMapAudio[key] = newProgress;
            return speed;
          },
          titleCallback: _notificationData.titleCallback,
          imageCallback: _notificationData.imageCallback,
        );
      });
    }
  }

  // -- things here are not refreshed. should be called in startup only.
  Future<void> loadDownloadTasksInfoFileAsync() async {
    isLoadingDownloadTasks.value = true;
    final params = _DownloadTasksLoadParams(tasksDatabasesPath: AppDirs.YT_DOWNLOAD_TASKS, downloadLocation: AppDirs.YOUTUBE_DOWNLOADS);
    final res = await _IsolateFunctions.loadDownloadTasksInfoFileSync.thready(params);
    // -- assign loaded data and update it with any modified data if any.
    youtubeDownloadTasksMap.value = res.youtubeDownloadTasksMap.._addAllEntries(youtubeDownloadTasksMap.value);
    downloadedFilesMap.value = res.downloadedFilesMap.._addAllEntries(downloadedFilesMap.value);
    downloadsVideoProgressMap.value = res.downloadsVideoProgressMap.._addAllEntries(downloadsVideoProgressMap.value);
    downloadsAudioProgressMap.value = res.downloadsAudioProgressMap.._addAllEntries(downloadsAudioProgressMap.value);
    latestEditedGroupDownloadTask = res.latestEditedGroupDownloadTask..addAll(latestEditedGroupDownloadTask);
    isLoadingDownloadTasks.value = false;
  }

  File? doesIDHasFileDownloaded(String id) {
    for (final e in youtubeDownloadTasksMap.value.entries) {
      for (final config in e.value.values) {
        final groupName = e.key;
        if (config.id.videoId == id) {
          final file = downloadedFilesMap.value[groupName]?[config.filename];
          if (file != null) {
            return file;
          }
        }
      }
    }
    return null;
  }

  void _matchIDsForItemConfig({
    required List<DownloadTaskVideoId> videosIds,
    required void Function(DownloadTaskGroupName groupName, YoutubeItemDownloadConfig config) onMatch,
  }) {
    for (final e in youtubeDownloadTasksMap.value.entries) {
      for (final config in e.value.values) {
        final groupName = e.key;
        videosIds.loop((e) {
          if (e == config.id) {
            onMatch(groupName, config);
          }
        });
      }
    }
  }

  void resumeDownloadTaskForIDs({
    required DownloadTaskGroupName groupName,
    List<DownloadTaskVideoId> videosIds = const [],
  }) {
    _matchIDsForItemConfig(
      videosIds: videosIds,
      onMatch: (groupName, config) {
        downloadYoutubeVideos(
          useCachedVersionsIfAvailable: true,
          autoExtractTitleAndArtist: settings.youtube.autoExtractVideoTagsFromInfo.value,
          keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
          downloadFilesWriteUploadDate: settings.downloadFilesWriteUploadDate.value,
          itemsConfig: [config],
          groupName: groupName,
        );
      },
    );
  }

  Future<void> resumeDownloadTasks({
    required DownloadTaskGroupName groupName,
    List<YoutubeItemDownloadConfig> itemsConfig = const [],
    bool skipExistingFiles = true,
  }) async {
    final finalItems = itemsConfig.isNotEmpty ? itemsConfig : youtubeDownloadTasksMap.value[groupName]?.values.toList() ?? [];
    if (skipExistingFiles) {
      finalItems.removeWhere((element) => YoutubeController.inst.downloadedFilesMap[groupName]?[element.filename] != null);
    }
    if (finalItems.isNotEmpty) {
      await downloadYoutubeVideos(
        useCachedVersionsIfAvailable: true,
        autoExtractTitleAndArtist: settings.youtube.autoExtractVideoTagsFromInfo.value,
        keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
        downloadFilesWriteUploadDate: settings.downloadFilesWriteUploadDate.value,
        itemsConfig: finalItems,
        groupName: groupName,
      );
    }
  }

  void pauseDownloadTask({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    required DownloadTaskGroupName groupName,
    List<DownloadTaskVideoId> videosIds = const [],
    bool allInGroupName = false,
  }) {
    youtubeDownloadTasksInQueueMap[groupName] ??= {};
    void onMatch(DownloadTaskGroupName groupName, YoutubeItemDownloadConfig config) {
      youtubeDownloadTasksInQueueMap[groupName]![config.filename] = false;
      _downloadManager.stopDownload(file: _downloadClientsMap[groupName]?[config.filename]);
      _downloadClientsMap[groupName]?.remove(config.filename);
      _breakRetrievingInfoRequest(config);
    }

    if (allInGroupName) {
      final groupClients = _downloadClientsMap[groupName];
      if (groupClients != null) {
        _downloadManager.stopDownloads(files: groupClients.values.toList());
        _downloadClientsMap.remove(groupName);
      }
      final groupConfigs = youtubeDownloadTasksMap.value[groupName];
      if (groupConfigs != null) {
        for (final c in groupConfigs.values) {
          onMatch(groupName, c);
        }
      }
    } else if (videosIds.isNotEmpty) {
      _matchIDsForItemConfig(
        videosIds: videosIds,
        onMatch: onMatch,
      );
    } else {
      itemsConfig.loop((c) => onMatch(groupName, c));
    }
    youtubeDownloadTasksInQueueMap.refresh();
  }

  void _breakRetrievingInfoRequest(YoutubeItemDownloadConfig c) {
    _completersVAI[c]?.completeErrorIfWasnt(const _UserCanceledException());
    _completersVAI[c] = null;
  }

  Future<void> cancelDownloadTask({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    required DownloadTaskGroupName groupName,
    bool allInGroupName = false,
    bool keepInList = false,
    required bool delete,
  }) async {
    await _updateDownloadTask(
      itemsConfig: itemsConfig,
      groupName: groupName,
      remove: true,
      delete: delete,
      keepInListIfRemoved: keepInList,
      allInGroupName: allInGroupName,
    );
  }

  Future<void> _updateDownloadTask({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    required DownloadTaskGroupName groupName,
    bool remove = false,
    bool delete = false,
    bool keepInListIfRemoved = false,
    bool allInGroupName = false,
  }) async {
    final downloadTasksGroupDB = _downloadTasksMainDBManager.getDB(
      groupName.groupName,
      config: const DBConfig(createIfNotExist: true),
    );

    youtubeDownloadTasksMap.value[groupName] ??= {};
    youtubeDownloadTasksInQueueMap[groupName] ??= {};
    if (remove) {
      final directory = Directory(FileParts.joinPath(AppDirs.YOUTUBE_DOWNLOADS, groupName.groupName));
      final itemsToCancel = allInGroupName
          ? youtubeDownloadTasksMap.value[groupName]!.values.toList()
          : List<YoutubeItemDownloadConfig>.from(itemsConfig); // copy bcz we can remove if from original list
      for (int i = 0; i < itemsToCancel.length; i++) {
        var c = itemsToCancel[i];
        _downloadManager.stopDownload(file: _downloadClientsMap[groupName]?[c.filename]);
        _downloadClientsMap[groupName]?.remove(c.filename);
        _breakRetrievingInfoRequest(c);
        NotificationManager.instance.removeDownloadingYoutubeNotification(filenameWrapper: c.filename);
        downloadTasksGroupDB.delete(c.filename.key);
        if (!keepInListIfRemoved) {
          youtubeDownloadTasksMap.value[groupName]?.remove(c.filename);
          youtubeDownloadTasksInQueueMap[groupName]?.remove(c.filename);
          YTOnGoingFinishedDownloads.inst.youtubeDownloadTasksTempList.remove((groupName, c));
        }
        if (delete) {
          try {
            await FileParts.join(directory.path, c.filename.filename).delete();
          } catch (_) {}
        }
        downloadedFilesMap[groupName]?[c.filename] = null;
      }
      downloadTasksGroupDB.claimFreeSpace();

      // -- remove groups if emptied.
      if (youtubeDownloadTasksMap.value[groupName]?.isEmpty == true) {
        youtubeDownloadTasksMap.value.remove(groupName);
        downloadTasksGroupDB.deleteEverything();
        // await downloadTasksGroupDB.fileInfo.file.delete(); // db.deleteEverything() leaves leftovers.
      }
    } else {
      await downloadTasksGroupDB.putAll(
        itemsConfig,
        (c) {
          youtubeDownloadTasksMap.value[groupName]![c.filename] = c;
          youtubeDownloadTasksInQueueMap[groupName]![c.filename] = true; // hehe
          final key = c.filename.key;
          return MapEntry(key, c.toJson());
        },
      );
    }

    youtubeDownloadTasksMap.refresh();
    downloadedFilesMap.refresh();

    latestEditedGroupDownloadTask[groupName] = DateTime.now().millisecondsSinceEpoch;
  }

  final _completersVAI = <YoutubeItemDownloadConfig, Completer<VideoStreamsResult?>?>{};

  Future<void> downloadYoutubeVideos({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    DownloadTaskGroupName groupName = const DownloadTaskGroupName.defaulty(),
    int parallelDownloads = 1,
    required bool useCachedVersionsIfAvailable,
    required bool downloadFilesWriteUploadDate,
    required bool keepCachedVersionsIfDownloaded,
    required bool autoExtractTitleAndArtist,
    bool deleteOldFile = true,
    bool addAudioToLocalLibrary = true,
    bool audioOnly = false,
    List<String> preferredQualities = const [],
    Future<void> Function(File? downloadedFile)? onOldFileDeleted,
    Future<void> Function(File? deletedFile)? onFileDownloaded,
    Directory? saveDirectory,
    PlaylistBasicInfo? playlistInfo,
  }) async {
    await _updateDownloadTask(groupName: groupName, itemsConfig: itemsConfig);
    YoutubeParallelDownloadsHandler.inst.setMaxParalellDownloads(parallelDownloads);

    Future<void> downloady(YoutubeItemDownloadConfig config) async {
      final videoID = config.id;

      final completerInMap = _completersVAI[config];
      if (completerInMap == null ? true : (completerInMap.isCompleted && (await completerInMap.future) == null)) {
        // reset completer if it was null or had a null value;
        _completersVAI[config] = Completer<VideoStreamsResult?>();
      }
      final completer = _completersVAI[config]!;
      if (!completer.isCompleted) {
        // pls dont try to refactor this
        YoutubeInfoController.video.fetchVideoStreams(videoID.videoId, forceRequest: true).catchError((_) => null).then((value) => _completersVAI[config]?.complete(value));
      }

      if (isFetchingData.value[videoID] == null) {
        isFetchingData.value[videoID] = <DownloadTaskFilename, bool>{}.obs;
        isFetchingData.refresh();
      }
      isFetchingData.value[videoID]![config.filename] = true;

      VideoStreamsResult? streams;

      try {
        if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();

        streams = await completer.future;
        if (streams == null) throw Exception('null streams result');

        // -- video
        if (audioOnly == false && config.fetchMissingVideo == true) {
          final videos = streams.videoStreams;

          if (config.videoStream != null) {
            // -- refresh the current audio stream (vip to avoid outdated links after restarts/etc)
            config.videoStream = videos.firstWhereEff((e) => e.itag == config.videoStream!.itag);
          }
          if (config.prefferedVideoQualityID != null) {
            config.videoStream = videos.firstWhereEff((e) => e.itag.toString() == config.prefferedVideoQualityID);
          }
          // `config.videoStream?.buildUrl()?.host.isNotEmpty != true` means if null || empty || fkedup then assign
          if (config.videoStream == null || config.videoStream?.buildUrl()?.host.isNotEmpty != true) {
            final webm = config.filename.filename.endsWith('.webm') || config.filename.filename.endsWith('.WEBM');
            config.videoStream = getPreferredStreamQuality(videos, qualities: preferredQualities, preferIncludeWebm: webm);
          }
        }

        if (config.fetchMissingAudio == true) {
          // -- audio
          final audios = streams.audioStreams;

          if (config.audioStream != null) {
            // -- refresh the current audio stream (vip to avoid outdated links after restarts/etc)
            config.audioStream = audios.firstWhereEff((e) => e.itag == config.audioStream!.itag);
          }
          if (config.prefferedAudioQualityID != null) {
            config.audioStream = audios.firstWhereEff((e) => e.itag.toString() == config.prefferedAudioQualityID);
          }
          if (config.audioStream == null || config.audioStream?.buildUrl()?.host.isNotEmpty != true) {
            config.audioStream = audios.firstNonWebm() ?? audios.firstOrNull;
          }
        }

        // -- meta info
        if (config.ffmpegTags.isEmpty || config.ffmpegTags.values.any((element) => element != null && filenameBuilder.paramRegex.hasMatch(element))) {
          final info = streams.info;
          final meta = await YTUtils.getMetadataInitialMap(
            videoID.videoId,
            config.streamInfoItem,
            config.videoStream,
            config.audioStream,
            streams,
            playlistInfo,
            playlistInfo?.id ?? config.playlistId,
            config.originalIndex,
            config.totalLength,
            autoExtract: autoExtractTitleAndArtist,
            initialBuilding: config.ffmpegTags,
          );
          config.ffmpegTags.addAll(meta);
          config.fileDate = info?.publishDate.date ?? info?.uploadDate.date;
        }
      } catch (e) {
        if (e is! _UserCanceledException) {
          printy(e, isError: true);
          snackyy(title: lang.ERROR, message: e.toString(), isError: true);
        }
        // -- force break
        isFetchingData.value[videoID]?[config.filename] = false;
        return;
      }

      isFetchingData.value[videoID]?[config.filename] = false;
      _updateDownloadTask(groupName: groupName, itemsConfig: [config]); // to refresh with new data

      final pageResult = await YoutubeInfoController.video.fetchVideoPage(videoID.videoId).catchError((_) => null);
      final downloadedFile = await _downloadYoutubeVideoRaw(
        groupName: groupName,
        id: videoID,
        config: config,
        useCachedVersionsIfAvailable: useCachedVersionsIfAvailable,
        saveDirectory: saveDirectory,
        fileExtension: config.videoStream?.codecInfo.container ?? config.audioStream?.codecInfo.container ?? 'm4a',
        streams: streams,
        pageResult: pageResult,
        playlistInfo: playlistInfo,
        videoStream: config.videoStream,
        audioStream: config.audioStream,
        merge: true,
        deleteOldFile: deleteOldFile,
        onOldFileDeleted: onOldFileDeleted,
        keepCachedVersionsIfDownloaded: keepCachedVersionsIfDownloaded,
        onInitialVideoFileSize: (initialFileSize) {},
        onInitialAudioFileSize: (initialFileSize) {},
        ffmpegTags: config.ffmpegTags,
        onAudioFileReady: (audioFile) async {
          final videoId = videoID.videoId;
          File? thumbnailFile;
          bool isTempThumbnail = false;
          try {
            // -- try getting cropped version if required
            final channelName = await YoutubeInfoController.utils.getVideoChannelName(videoId);
            const topic = '- Topic';
            if (channelName != null && channelName.endsWith(topic)) {
              final thumbFilePath = FileParts.joinPath(Directory.systemTemp.path, '$videoId.png');
              final thumbFile = await YoutubeInfoController.video.fetchMusicVideoThumbnailToFile(videoId, thumbFilePath);
              if (thumbFile != null) {
                thumbnailFile = thumbFile;
                isTempThumbnail = true;
              }
            }
          } catch (_) {}
          thumbnailFile ??= await ThumbnailManager.inst.getYoutubeThumbnailAndCache(
            id: videoId,
            isImportantInCache: true,
            type: ThumbnailType.video,
          );
          await YTUtils.writeAudioMetadata(
            videoId: videoId,
            audioFile: audioFile,
            thumbnailFile: thumbnailFile,
            tagsMap: config.ffmpegTags,
          );
          if (isTempThumbnail) {
            thumbnailFile?.tryDeleting();
          }
        },
        onVideoFileReady: (videoFile) async {
          await NamidaFFMPEG.inst.editMetadata(
            path: videoFile.path,
            tagsMap: config.ffmpegTags,
          );
        },
      );

      if (downloadFilesWriteUploadDate && downloadedFile != null) {
        final d = config.fileDate;
        if (d != null && d != DateTime(0)) {
          try {
            await downloadedFile.setLastAccessed(d);
            await downloadedFile.setLastModified(d);
          } catch (_) {}
        }
      }

      // -- adding to library, if audio or audio+video downloaded
      if (addAudioToLocalLibrary && config.audioStream != null) {
        if (downloadedFile != null && await File(downloadedFile.path).exists()) {
          Indexer.inst.convertPathsToTracksAndAddToLists([downloadedFile.path]);
        }
      }

      final dfmg = downloadedFilesMap.value[groupName] ??= {};
      dfmg[config.filename] = downloadedFile;
      downloadedFilesMap.refresh();
      final dtqmg = youtubeDownloadTasksInQueueMap.value[groupName] ??= {};
      dtqmg[config.filename] = null;
      downloadedFilesMap.refresh();
      YTOnGoingFinishedDownloads.inst.refreshList();
      await onFileDownloaded?.call(downloadedFile);
    }

    bool checkIfCanSkip(YoutubeItemDownloadConfig config) {
      final isCanceled = youtubeDownloadTasksMap.value[groupName]?[config.filename] == null;
      final isPaused = youtubeDownloadTasksInQueueMap.value[groupName]?[config.filename] == false;
      if (isCanceled || isPaused) {
        if (kDebugMode) printy('Download Skipped for "${config.filename.filename}" bcz: ${[if (isCanceled) 'canceled', if (isPaused) 'paused'].join(' & ')}');
        return true;
      }
      return false;
    }

    for (final config in itemsConfig) {
      // if paused, or removed (canceled), we skip it
      if (checkIfCanSkip(config)) continue;

      await YoutubeParallelDownloadsHandler.inst.waitForParallelCompleter;

      // we check again bcz we been waiting...
      if (checkIfCanSkip(config)) continue;

      YoutubeParallelDownloadsHandler.inst.inc();
      await downloady(config).then((value) {
        YoutubeParallelDownloadsHandler.inst.dec();
      });
    }
  }

  String _getTempAudioPath({
    required DownloadTaskGroupName groupName,
    required String fullFilename,
    Directory? saveDir,
  }) {
    return _getTempDownloadPath(
      groupName: groupName.groupName,
      fullFilename: fullFilename,
      prefix: '.tempa_',
      saveDir: saveDir,
    );
  }

  String _getTempVideoPath({
    required DownloadTaskGroupName groupName,
    required String fullFilename,
    Directory? saveDir,
  }) {
    return _getTempDownloadPath(
      groupName: groupName.groupName,
      fullFilename: fullFilename,
      prefix: '.tempv_',
      saveDir: saveDir,
    );
  }

  /// [directoryPath] must NOT end with `/`
  String _getTempDownloadPath({
    required String groupName,
    required String fullFilename,
    required String prefix,
    Directory? saveDir,
  }) {
    final saveDirPath = saveDir?.path ?? FileParts.joinPath(AppDirs.YOUTUBE_DOWNLOADS, groupName);
    return FileParts.joinPath(saveDirPath, "$prefix$fullFilename");
  }

  static final filenameBuilder = _YtFilenameRebuilder();

  Future<File?> _downloadYoutubeVideoRaw({
    required DownloadTaskVideoId id,
    required DownloadTaskGroupName groupName,
    required YoutubeItemDownloadConfig config,
    required bool useCachedVersionsIfAvailable,
    required Directory? saveDirectory,
    required String fileExtension,
    required VideoStreamsResult? streams,
    required YoutiPieVideoPageResult? pageResult,
    required PlaylistBasicInfo? playlistInfo,
    required VideoStream? videoStream,
    required AudioStream? audioStream,
    required Map<String, String?> ffmpegTags,
    required bool merge,
    required bool keepCachedVersionsIfDownloaded,
    required bool deleteOldFile,
    required void Function(int initialFileSize) onInitialVideoFileSize,
    required void Function(int initialFileSize) onInitialAudioFileSize,
    required Future<void> Function(File videoFile) onVideoFileReady,
    required Future<void> Function(File audioFile) onAudioFileReady,
    required Future<void> Function(File? deletedFile)? onOldFileDeleted,
  }) async {
    if (id.videoId.isEmpty) return null;

    final finalFilenameWrapper = config.filename;
    String finalFilenameTemp = finalFilenameWrapper.filename;
    bool requiresRenaming = false;

    if (finalFilenameTemp.isEmpty || finalFilenameTemp == fileExtension || finalFilenameTemp == '.$fileExtension') {
      finalFilenameTemp = settings.youtube.defaultFilenameBuilder;
      requiresRenaming = true;
    }

    final finalFilenameTempRebuilt = filenameBuilder.rebuildFilenameWithDecodedParams(
        finalFilenameTemp, id.videoId, streams, pageResult, config.streamInfoItem, playlistInfo, videoStream, audioStream, config.originalIndex, config.totalLength);
    if (finalFilenameTempRebuilt != null && finalFilenameTempRebuilt.isNotEmpty) {
      finalFilenameTemp = finalFilenameTempRebuilt;
      requiresRenaming = true;
    }

    if (!finalFilenameTemp.endsWith('.$fileExtension')) {
      finalFilenameTemp += '.$fileExtension';
      requiresRenaming = true;
    }

    final filenameCleanTemp = DownloadTaskFilename.cleanupFilename(finalFilenameTemp);
    if (filenameCleanTemp != finalFilenameTemp) {
      finalFilenameTemp = filenameCleanTemp;
      requiresRenaming = true;
    }

    if (requiresRenaming) {
      await renameConfigFilename(
        videoID: id,
        groupName: groupName,
        config: config,
        newFilename: finalFilenameTemp,
        renameCacheFiles: false, // no worries we still gonna do the job.
      );
    }

    if (isDownloading.value[id] == null) {
      isDownloading.value[id] = <DownloadTaskFilename, bool>{}.obs;
      isDownloading.refresh();
    }
    isDownloading.value[id]![config.filename] = true;

    _startNotificationTimer();

    saveDirectory ??= Directory(FileParts.joinPath(AppDirs.YOUTUBE_DOWNLOADS, groupName.groupName));
    await saveDirectory.create(recursive: true);

    File? df;
    final file = FileParts.join(saveDirectory.path, finalFilenameTemp);
    final fileAlreadyDownloaded = await file.exists();

    if (fileAlreadyDownloaded) {
      if (deleteOldFile) {
        try {
          await file.delete();
          onOldFileDeleted?.call(file);
        } catch (_) {}
      } else {
        df = file;
      }
    }

    if (df == null) {
      // -- only download if file wasnt downloaded before

      Future<bool> fileSizeQualified({
        required File file,
        required int targetSize,
        int allowanceBytes = 1024,
      }) async {
        try {
          final fileStats = await file.stat();
          final ok = fileStats.size >= targetSize - allowanceBytes; // it can be bigger cuz metadata and artwork may be added later
          return ok;
        } catch (_) {
          return false;
        }
      }

      File? videoFile;
      File? audioFile;

      bool isVideoFileCached = false;
      bool isAudioFileCached = false;

      bool skipAudio = false; // if video fails or stopped

      if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();

      try {
        // --------- Downloading Choosen Video.
        if (videoStream != null) {
          final filecache = await videoStream.getCachedFile(id.videoId);
          if (useCachedVersionsIfAvailable && filecache != null && await fileSizeQualified(file: filecache, targetSize: videoStream.sizeInBytes)) {
            videoFile = filecache;
            isVideoFileCached = true;
          } else {
            int bytesLength = 0;
            if (downloadsVideoProgressMap.value[id] == null) {
              downloadsVideoProgressMap.value[id] = <DownloadTaskFilename, DownloadProgress>{}.obs;
              downloadsVideoProgressMap.refresh();
            }
            final downloadedFile = await _checkFileAndDownload(
              groupName: groupName,
              url: videoStream.buildUrl(),
              targetSize: videoStream.sizeInBytes,
              filename: finalFilenameWrapper,
              destinationFilePath: _getTempVideoPath(
                groupName: groupName,
                fullFilename: finalFilenameTemp,
                saveDir: saveDirectory,
              ),
              onInitialFileSize: (initialFileSize) {
                onInitialVideoFileSize(initialFileSize);
                bytesLength = initialFileSize;
              },
              downloadingStream: (downloadedBytesLength) {
                bytesLength += downloadedBytesLength;
                downloadsVideoProgressMap[id]![finalFilenameWrapper] = DownloadProgress(
                  progress: bytesLength,
                  totalProgress: videoStream.sizeInBytes,
                );
              },
            );
            videoFile = downloadedFile;
          }

          final qualified = await fileSizeQualified(file: videoFile, targetSize: videoStream.sizeInBytes);
          if (qualified) {
            await onVideoFileReady(videoFile);

            // if we should keep as a cache, we copy the downloaded file to cache dir
            // -- [!isVideoFileCached] is very important, otherwise it will copy to itself (0 bytes result).
            if (isVideoFileCached == false && keepCachedVersionsIfDownloaded) {
              await videoFile.copy(videoStream.cachePath(id.videoId));
            }
          } else {
            skipAudio = true;
            videoFile = null;
          }
        }
        // -----------------------------------

        // --------- Downloading Choosen Audio.
        if (skipAudio == false && audioStream != null) {
          downloadsVideoProgressMap[id]?.remove(finalFilenameWrapper); // remove video progress so that audio progress is shown

          final filecache = await audioStream.getCachedFile(id.videoId);
          if (useCachedVersionsIfAvailable && filecache != null && await fileSizeQualified(file: filecache, targetSize: audioStream.sizeInBytes)) {
            audioFile = filecache;
            isAudioFileCached = true;
          } else {
            int bytesLength = 0;

            if (downloadsAudioProgressMap.value[id] == null) {
              downloadsAudioProgressMap.value[id] = <DownloadTaskFilename, DownloadProgress>{}.obs;
              downloadsAudioProgressMap.refresh();
            }
            final downloadedFile = await _checkFileAndDownload(
              groupName: groupName,
              url: audioStream.buildUrl(),
              targetSize: audioStream.sizeInBytes,
              filename: finalFilenameWrapper,
              destinationFilePath: _getTempAudioPath(
                groupName: groupName,
                fullFilename: finalFilenameTemp,
                saveDir: saveDirectory,
              ),
              onInitialFileSize: (initialFileSize) {
                onInitialAudioFileSize(initialFileSize);
                bytesLength = initialFileSize;
              },
              downloadingStream: (downloadedBytesLength) {
                bytesLength += downloadedBytesLength;
                downloadsAudioProgressMap[id]![finalFilenameWrapper] = DownloadProgress(
                  progress: bytesLength,
                  totalProgress: audioStream.sizeInBytes,
                );
              },
            );
            audioFile = downloadedFile;
          }
          final qualified = await fileSizeQualified(file: audioFile, targetSize: audioStream.sizeInBytes);

          if (qualified) {
            await onAudioFileReady(audioFile);

            // if we should keep as a cache, we copy the downloaded file to cache dir
            // -- [!isAudioFileCached] is very important, otherwise it will copy to itself (0 bytes result).
            if (isAudioFileCached == false && keepCachedVersionsIfDownloaded) {
              await audioFile.copy(audioStream.cachePath(id.videoId));
            }
          } else {
            audioFile = null;
          }
        }
        // -----------------------------------

        // ----- merging if both video & audio were downloaded
        final output = FileParts.joinPath(saveDirectory.path, finalFilenameWrapper.filename);
        if (merge && videoFile != null && audioFile != null) {
          bool didMerge = await NamidaFFMPEG.inst.mergeAudioAndVideo(
            videoPath: videoFile.path,
            audioPath: audioFile.path,
            outputPath: output,
          );
          if (!didMerge) {
            // -- sometimes, no extension is specified, which causes failure
            didMerge = await NamidaFFMPEG.inst.mergeAudioAndVideo(
              videoPath: videoFile.path,
              audioPath: audioFile.path,
              outputPath: "$output.mp4",
            );
          }
          if (didMerge) {
            Future.wait([
              if (isVideoFileCached == false) videoFile.tryDeleting(),
              if (isAudioFileCached == false) audioFile.tryDeleting(),
            ]); // deleting temp files since they got merged
          }
          if (await File(output).exists()) df = File(output);
        } else {
          // -- renaming files, or copying if cached
          Future<void> renameOrCopy({required File file, required String path, required bool isCachedVersion}) async {
            if (isCachedVersion) {
              await file.copy(path);
            } else {
              await file.move(path);
            }
          }

          await Future.wait([
            if (videoFile != null && videoStream != null)
              renameOrCopy(
                file: videoFile,
                path: output,
                isCachedVersion: isVideoFileCached,
              ),
            if (audioFile != null && audioStream != null)
              renameOrCopy(
                file: audioFile,
                path: output,
                isCachedVersion: isAudioFileCached,
              ),
          ]);
          if (await File(output).exists()) df = File(output);
        }
      } on _UserCanceledException catch (_) {
      } catch (e, st) {
        printy('Error Downloading YT Video: $e', isError: true);
        snackyy(title: 'Error Downloading', message: e.toString(), isError: true);
        logger.error('YoutubeController.downloadYoutubeVideoRaw: Error Downloading', e: e, st: st);
      }
    }

    isDownloading[id]![finalFilenameWrapper] = false;

    final wasPaused = youtubeDownloadTasksInQueueMap[groupName]?[finalFilenameWrapper] == false;
    _doneDownloadingNotification(
      videoId: id,
      videoTitle: finalFilenameWrapper.filename,
      nameIdentifier: finalFilenameWrapper,
      filename: finalFilenameWrapper,
      downloadedFile: df,
      canceledByUser: wasPaused,
    );
    return df;
  }

  /// the file returned may not be complete if the client was closed.
  Future<File> _checkFileAndDownload({
    required Uri? url,
    required int targetSize,
    required DownloadTaskGroupName groupName,
    required DownloadTaskFilename filename,
    required String destinationFilePath,
    required void Function(int initialFileSize) onInitialFileSize,
    required void Function(int downloadedBytesLength) downloadingStream,
  }) async {
    int downloadStartRange = 0;

    final file = await File(destinationFilePath).create(); // retrieving the temp file (or creating a new one).
    int initialFileSizeOnDisk = 0;
    try {
      initialFileSizeOnDisk = await file.length(); // fetching current size to be used as a range bytes for download request
    } catch (_) {}
    onInitialFileSize(initialFileSizeOnDisk);
    // only download if the download is incomplete, useful sometimes when file 'moving' fails.
    Object? downloadException;
    if (initialFileSizeOnDisk < targetSize) {
      downloadStartRange = initialFileSizeOnDisk;
      _downloadManager.stopDownload(file: _downloadClientsMap[groupName]?[filename]);
      _downloadClientsMap[groupName] ??= {};
      _downloadClientsMap[groupName]![filename] = file;
      downloadException = await _downloadManager.download(
        url: url,
        file: file,
        downloadStartRange: downloadStartRange,
        downloadingStream: downloadingStream,
      );
    }
    _downloadManager.stopDownload(file: file);
    _downloadClientsMap[groupName]?.remove(filename);
    if (downloadException != null) {
      throw downloadException;
    }
    return File(destinationFilePath);
  }

  final _downloadManager = _YTDownloadManager();
  File? _latestSingleDownloadingFile;
  Future<NamidaVideo?> downloadYoutubeVideo({
    required String id,
    required VideoStream stream,
    required DateTime? creationDate,
    required void Function(List<VideoStream> availableStreams) onAvailableQualities,
    required void Function(VideoStream choosenStream) onChoosingQuality,
    required void Function(int downloadedBytesLength) downloadingStream,
    required void Function(int initialFileSize) onInitialFileSize,
    required bool Function() canStartDownloading,
  }) async {
    if (id == '') return null;
    NamidaVideo? dv;
    try {
      // --------- Getting Video to Download.
      VideoStream erabaretaStream = stream;

      onChoosingQuality(erabaretaStream);
      // ------------------------------------

      // --------- Downloading Choosen Video.
      String getVPath(bool isTemp) {
        return isTemp ? erabaretaStream.cachePathTemp(id) : erabaretaStream.cachePath(id);
      }

      final erabaretaStreamSizeInBytes = erabaretaStream.sizeInBytes;

      final file = await File(getVPath(true)).create(); // retrieving the temp file (or creating a new one).
      int initialFileSizeOnDisk = 0;
      try {
        initialFileSizeOnDisk = await file.length(); // fetching current size to be used as a range bytes for download request
      } catch (_) {}
      onInitialFileSize(initialFileSizeOnDisk);

      bool downloaded = false;
      final newFilePath = getVPath(false);
      if (initialFileSizeOnDisk >= erabaretaStreamSizeInBytes) {
        try {
          final movedFile = await file.move(
            newFilePath,
            goodBytesIfCopied: (newFileLength) async => (await file.length()) > newFileLength - 1024,
          );
          downloaded = movedFile != null;
        } catch (_) {}
      } else {
        // only download if the download is incomplete, useful sometimes when file 'moving' fails.
        if (!canStartDownloading()) return null;
        final downloadStartRange = initialFileSizeOnDisk;

        _downloadManager.stopDownload(file: _latestSingleDownloadingFile); // disposing old download process
        _latestSingleDownloadingFile = file;

        if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();

        final downloadException = await _downloadManager.download(
          url: erabaretaStream.buildUrl(),
          file: file,
          downloadStartRange: downloadStartRange,
          downloadingStream: downloadingStream,
          moveTo: newFilePath,
          moveToRequiredBytes: erabaretaStreamSizeInBytes,
        );
        downloaded = downloadException == null;

        if (downloadException != null) {
          throw downloadException;
        }
      }

      if (downloaded) {
        dv = NamidaVideo(
          path: newFilePath,
          ytID: id,
          nameInCache: newFilePath.getFilenameWOExt,
          height: erabaretaStream.height,
          width: erabaretaStream.width,
          sizeInBytes: erabaretaStreamSizeInBytes,
          frameratePrecise: erabaretaStream.fps.toDouble(),
          creationTimeMS: creationDate?.millisecondsSinceEpoch ?? 0,
          durationMS: erabaretaStream.duration?.inMilliseconds ?? 0,
          bitrate: erabaretaStream.bitrate,
        );
      }
    } on _UserCanceledException catch (_) {
    } catch (e, st) {
      printy('Error Downloading YT Video: $e', isError: true);
      snackyy(title: 'Error Downloading', message: e.toString(), isError: true);
      logger.error('YoutubeController.downloadYoutubeVideo: Error Downloading', e: e, st: st);
    }

    return dv;
  }

  void dispose({bool closeCurrentDownloadClient = true, bool closeAllClients = false}) {
    if (closeCurrentDownloadClient) {
      _downloadManager.stopDownload(file: _latestSingleDownloadingFile);
    }

    if (closeAllClients) {
      for (final c in _downloadClientsMap.values) {
        for (final file in c.values) {
          _downloadManager.stopDownload(file: file);
        }
      }
    }
  }
}

class _YTDownloadManager with PortsProvider<SendPort> {
  final _downloadCompleters = <String, Completer<Object?>?>{}; // file path
  final _progressPorts = <String, RawReceivePort?>{}; // file path

  /// if [file] is temp, u can provide [moveTo] to move/rename the temp file to it.
  Future<Object?> download({
    required Uri? url,
    required File file,
    String? moveTo,
    int? moveToRequiredBytes,
    required int downloadStartRange,
    required void Function(int downloadedBytesLength) downloadingStream,
  }) async {
    if (url == null || url.host.isEmpty) return false;

    final filePath = file.path;
    if (_downloadCompleters[filePath] != null) return _downloadCompleters[filePath]!.future;
    _downloadCompleters[filePath]?.completeIfWasnt(null);
    _downloadCompleters[filePath] = Completer<Object?>();

    _progressPorts[filePath]?.close();
    final progressPort = _progressPorts[filePath] = RawReceivePort((message) {
      downloadingStream(message as int);
    });
    final p = {
      'url': url,
      'filePath': filePath,
      'moveTo': moveTo,
      'moveToRequiredBytes': moveToRequiredBytes,
      'downloadStartRange': downloadStartRange,
      'progressPort': progressPort.sendPort,
    };
    if (!isInitialized) await initialize();
    await sendPort(p);
    final res = await _downloadCompleters[filePath]?.future;
    _onFileFinish(filePath, null);
    return res;
  }

  Future<void> stopDownload({required File? file}) async {
    if (file == null) return;
    final filePath = file.path;
    _onFileFinish(filePath, null);
    final p = {
      'files': [file],
      'stop': true
    };
    await sendPort(p);
  }

  Future<void> stopDownloads({required List<File> files}) async {
    if (files.isEmpty) return;
    files.loop((e) => _onFileFinish(e.path, null));
    final p = {'files': files, 'stop': true};
    await sendPort(p);
  }

  static void _prepareDownloadResources(SendPort sendPort) async {
    await Rhttp.init();
    final requester = HttpClientWrapper.createSync();

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    final cancelTokensMap = <String, CancelToken?>{}; // filePath

    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        for (final canceltoken in cancelTokensMap.values) {
          canceltoken?.cancel();
        }
        cancelTokensMap.clear();
        recievePort.close();
        streamSub?.cancel();
        return;
      } else {
        p as Map;
        final stop = p['stop'] as bool?;
        if (stop == true) {
          final files = p['files'] as List<File>?;
          if (files != null) {
            for (int i = 0; i < files.length; i++) {
              var path = files[i].path;
              cancelTokensMap[path]?.cancel();
              cancelTokensMap[path] = null;
            }
          }
        } else {
          final filePath = p['filePath'] as String;
          try {
            final url = p['url'] as Uri;
            final downloadStartRange = p['downloadStartRange'] as int;
            final moveTo = p['moveTo'] as String?;
            final moveToRequiredBytes = p['moveToRequiredBytes'] as int?;
            final progressPort = p['progressPort'] as SendPort;

            cancelTokensMap[filePath] = CancelToken();
            final file = File(filePath);
            file.createSync(recursive: true);
            final fileStream = file.openWrite(mode: FileMode.writeOnlyAppend);

            try {
              final cancelToken = cancelTokensMap[filePath]!; // always non null tho
              final headers = {'range': 'bytes=$downloadStartRange-'};
              final response = await requester.getStream(url.toString(), headers: headers, cancelToken: cancelToken);
              final downloadStream = response.body;

              await for (final data in downloadStream) {
                fileStream.add(data);
                progressPort.send(data.length);
              }
              Object? movedException;
              if (moveTo != null && moveToRequiredBytes != null) {
                try {
                  final fileSize = file.fileSizeSync() ?? 0;
                  const allowance = 1024; // 1KB allowance
                  if (fileSize >= moveToRequiredBytes - allowance) {
                    final movedFile = file.moveSync(
                      moveTo,
                      goodBytesIfCopied: (fileLength) => fileLength >= moveToRequiredBytes - allowance,
                    );
                    if (movedFile == null) {
                      movedException = FileSystemException("Error moving $file to $moveTo");
                    }
                  }
                } catch (e) {
                  movedException = e;
                }
              }
              return sendPort.send(MapEntry(filePath, movedException));
            } on RhttpCancelException catch (_) {
              // client force closed
              return sendPort.send(MapEntry(filePath, null));
            } finally {
              try {
                final req = cancelTokensMap.remove(filePath);
                await req?.cancel();
              } catch (_) {}
              try {
                await fileStream.flush();
                await fileStream.close(); // closing file.
              } catch (_) {}
            }
          } catch (e) {
            return sendPort.send(MapEntry(filePath, e)); // general error
          }
        }
      }
    });

    sendPort.send(null); // prepared
  }

  @override
  void onResult(dynamic result) {
    if (result is MapEntry) {
      _onFileFinish(result.key, result.value);
    }
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_prepareDownloadResources, port);
  }

  void _onFileFinish(String path, Object? exception) {
    _downloadCompleters[path]?.completeIfWasnt(exception);
    _downloadCompleters[path] = null; // important
    _progressPorts[path]?.close();
    _progressPorts[path] = null;
  }
}

class _IsolateFunctions {
  static _DownloadTaskInitWrapper loadDownloadTasksInfoFileSync(_DownloadTasksLoadParams params) {
    NamicoDBWrapper.initialize();

    late final downloadTasksMainDBManager = DBWrapperMainSync(params.tasksDatabasesPath);

    final youtubeDownloadTasksMap = <DownloadTaskGroupName, Map<DownloadTaskFilename, YoutubeItemDownloadConfig>>{};
    final downloadedFilesMap = <DownloadTaskGroupName, Map<DownloadTaskFilename, File?>>{};
    final downloadsVideoProgressMap = <DownloadTaskVideoId, RxMap<DownloadTaskFilename, DownloadProgress>>{};
    final downloadsAudioProgressMap = <DownloadTaskVideoId, RxMap<DownloadTaskFilename, DownloadProgress>>{};
    final latestEditedGroupDownloadTask = <DownloadTaskGroupName, int>{};

    final allFiles = Directory(params.tasksDatabasesPath).listSyncSafe();
    final oldJsonFiles = <File>[];
    final newDBFiles = <File>[];
    allFiles.loop((item) {
      if (item is File) item.path.endsWith('.json') ? oldJsonFiles.add(item) : newDBFiles.add(item);
    });

    DownloadTaskGroupName fileToGroupName(File file) {
      final filenameWOExt = file.path.getFilenameWOExt;
      return filenameWOExt.startsWith('.') ? DownloadTaskGroupName.defaulty() : DownloadTaskGroupName(groupName: filenameWOExt);
    }

    // -- migrating old .json files to .db
    oldJsonFiles.loop(
      (file) {
        final group = fileToGroupName(file);

        try {
          final res = file.readAsJsonSync(ensureExists: false) as Map<String, dynamic>?;
          if (res != null) {
            final downloadTasksGroupDB = downloadTasksMainDBManager.getDB(
              group.groupName,
              config: const DBConfig(createIfNotExist: true, autoDisposeTimerDuration: null),
            );
            for (final r in res.entries) {
              downloadTasksGroupDB.put(r.key, r.value);
            }
            final downloadTasksGroupDBFile = downloadTasksGroupDB.fileInfo.file;
            final dbWasJustCreated = newDBFiles.firstWhereEff((f) => f.path == downloadTasksGroupDBFile.path) == null;
            if (dbWasJustCreated) newDBFiles.add(downloadTasksGroupDBFile);
            try {
              final originalFileDates = file.statSync();
              downloadTasksGroupDBFile.setLastModifiedSync(originalFileDates.modified);
              downloadTasksGroupDBFile.setLastAccessedSync(originalFileDates.accessed);
            } catch (_) {}
          }
        } catch (_) {}

        try {
          file.deleteSync();
        } catch (_) {}
      },
    );

    bool hadEmptyGroups = false;
    final dbsThatHadError = <DownloadTaskGroupName, bool>{};

    newDBFiles.loop(
      (dbFile) {
        final group = fileToGroupName(dbFile);

        if (youtubeDownloadTasksMap[group] == null) {
          final fileModified = dbFile.statSync().modified;
          youtubeDownloadTasksMap[group] = {};
          downloadedFilesMap[group] = {};
          if (fileModified != DateTime(1970)) {
            latestEditedGroupDownloadTask[group] ??= fileModified.millisecondsSinceEpoch;
          }
        }

        try {
          final downloadTasksGroupDB = downloadTasksMainDBManager.getDB(group.groupName, config: const DBConfig(autoDisposeTimerDuration: null));
          downloadTasksGroupDB.loadEverything((itemMap) {
            final ytitem = YoutubeItemDownloadConfig.fromJson(itemMap);
            final saveDirPath = FileParts.joinPath(params.downloadLocation, group.groupName);
            final file = FileParts.join(saveDirPath, ytitem.filename.filename);
            final fileExists = file.existsSync();
            final itemFileName = ytitem.filename;
            youtubeDownloadTasksMap[group]![itemFileName] = ytitem;
            downloadedFilesMap[group]![itemFileName] = fileExists ? file : null;
            if (!fileExists) {
              final aFile = FileParts.join(saveDirPath, ".tempa_${itemFileName.filename}");
              final vFile = FileParts.join(saveDirPath, ".tempv_${itemFileName.filename}");
              if (aFile.existsSync()) {
                downloadsAudioProgressMap[ytitem.id] ??= <DownloadTaskFilename, DownloadProgress>{}.obs;
                downloadsAudioProgressMap[ytitem.id]!.value[itemFileName] = DownloadProgress(
                  progress: aFile.fileSizeSync() ?? 0,
                  totalProgress: 0,
                );
              }
              if (vFile.existsSync()) {
                downloadsVideoProgressMap[ytitem.id] ??= <DownloadTaskFilename, DownloadProgress>{}.obs;
                downloadsVideoProgressMap[ytitem.id]!.value[itemFileName] = DownloadProgress(
                  progress: vFile.fileSizeSync() ?? 0,
                  totalProgress: 0,
                );
              }
            }
          });
        } catch (_) {
          dbsThatHadError[group] = true;
        }
        if (!hadEmptyGroups && (youtubeDownloadTasksMap[group]?.isEmpty ?? true)) {
          hadEmptyGroups = true;
        }
      },
    );

    // we loop again to give a chance for duplicated groups, if any.
    if (hadEmptyGroups) {
      newDBFiles.loop((dbFile) {
        final group = fileToGroupName(dbFile);
        if (dbsThatHadError[group] != true && (youtubeDownloadTasksMap[group]?.isEmpty ?? true)) {
          // db is empty, delete it. we don't delete immediately at runtime bcz it might be accessed again after deleting and many bad things would happen.
          youtubeDownloadTasksMap.remove(group);
          downloadedFilesMap.remove(group);
          latestEditedGroupDownloadTask.remove(group);
          try {
            dbFile.deleteSync();
          } catch (_) {}
        }
      });
    }

    downloadTasksMainDBManager.closeAll();

    return _DownloadTaskInitWrapper(
      youtubeDownloadTasksMap: youtubeDownloadTasksMap,
      downloadedFilesMap: downloadedFilesMap,
      downloadsVideoProgressMap: downloadsVideoProgressMap,
      downloadsAudioProgressMap: downloadsAudioProgressMap,
      latestEditedGroupDownloadTask: latestEditedGroupDownloadTask,
    );
  }
}

class _DownloadTaskInitWrapper {
  final Map<DownloadTaskGroupName, Map<DownloadTaskFilename, YoutubeItemDownloadConfig>> youtubeDownloadTasksMap;
  final Map<DownloadTaskGroupName, Map<DownloadTaskFilename, File?>> downloadedFilesMap;
  final Map<DownloadTaskVideoId, RxMap<DownloadTaskFilename, DownloadProgress>> downloadsVideoProgressMap;
  final Map<DownloadTaskVideoId, RxMap<DownloadTaskFilename, DownloadProgress>> downloadsAudioProgressMap;
  final Map<DownloadTaskGroupName, int> latestEditedGroupDownloadTask;

  const _DownloadTaskInitWrapper({
    required this.youtubeDownloadTasksMap,
    required this.downloadedFilesMap,
    required this.downloadsVideoProgressMap,
    required this.downloadsAudioProgressMap,
    required this.latestEditedGroupDownloadTask,
  });
}

class _DownloadTasksLoadParams {
  final String tasksDatabasesPath;
  final String downloadLocation;

  const _DownloadTasksLoadParams({
    required this.tasksDatabasesPath,
    required this.downloadLocation,
  });
}

extension _MapUtils<MK, K, V> on Map<MK, Map<K, V>> {
  void _addAllEntries(Map<MK, Map<K, V>> other) {
    final mainMap = this;
    for (final entry in other.entries) {
      for (final e in entry.value.entries) {
        mainMap[entry.key] ??= <K, V>{};
        mainMap[entry.key]![e.key] = e.value;
      }
    }
  }
}

extension _RxMapUtils<MK, K, V> on Map<MK, RxMap<K, V>> {
  void _addAllEntries(Map<MK, RxMap<K, V>> other) {
    final mainMap = this;
    for (final entry in other.entries) {
      for (final e in entry.value.entries) {
        mainMap[entry.key] ??= <K, V>{}.obs;
        mainMap[entry.key]![e.key] = e.value;
      }
    }
  }
}

class _UserCanceledException implements Exception {
  const _UserCanceledException();
}
