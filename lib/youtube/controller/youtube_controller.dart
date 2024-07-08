import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/notification_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/download_progress.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/parallel_downloads_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_ongoing_finished_downloads.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeController {
  static YoutubeController get inst => _instance;
  static final YoutubeController _instance = YoutubeController._internal();
  YoutubeController._internal();

  /// {id: <filename, DownloadProgress>{}}
  final downloadsVideoProgressMap = <String, RxMap<String, DownloadProgress>>{}.obs;

  /// {id: <filename, DownloadProgress>{}}
  final downloadsAudioProgressMap = <String, RxMap<String, DownloadProgress>>{}.obs;

  /// {id: <filename, int>{}}
  final currentSpeedsInByte = <String, RxMap<String, int>>{}.obs;

  /// {id: <filename, bool>{}}
  final isDownloading = <String, RxMap<String, bool>>{}.obs;

  /// {id: <filename, bool>{}}
  final isFetchingData = <String, RxMap<String, bool>>{}.obs;

  /// {groupName: <File>{}}
  final _downloadClientsMap = <String, Map<String, File>>{};

  /// {groupName: {filename: YoutubeItemDownloadConfig}}
  final youtubeDownloadTasksMap = <String, Map<String, YoutubeItemDownloadConfig>>{}.obs;

  /// {groupName: {filename: bool}}
  /// - `true` -> is in queue, will be downloaded when reached.
  /// - `false` -> is paused. will be skipped when reached.
  /// - `null` -> not specified.
  final youtubeDownloadTasksInQueueMap = <String, Map<String, bool?>>{}.obs;

  /// {groupName: dateMS}
  ///
  /// used to sort group names by latest edited.
  final latestEditedGroupDownloadTask = <String, int>{};

  /// Used to keep track of existing downloaded files, more performant than real-time checking.
  ///
  /// {groupName: {filename: File}}
  final downloadedFilesMap = <String, Map<String, File?>>{}.obs;

  /// [renameCacheFiles] requires you to stop the download first, otherwise it might result in corrupted files.
  Future<void> renameConfigFilename({
    required YoutubeItemDownloadConfig config,
    required String videoID,
    required String newFilename,
    required String groupName,
    required bool renameCacheFiles,
  }) async {
    final oldFilename = config.filename;

    config.filename = newFilename;

    downloadsVideoProgressMap[videoID]?.reAssign(oldFilename, newFilename);
    downloadsAudioProgressMap[videoID]?.reAssign(oldFilename, newFilename);
    currentSpeedsInByte[videoID]?.reAssign(oldFilename, newFilename);
    isDownloading[videoID]?.reAssign(oldFilename, newFilename);
    isFetchingData[videoID]?.reAssign(oldFilename, newFilename);

    downloadsVideoProgressMap.refresh();
    downloadsAudioProgressMap.refresh();
    currentSpeedsInByte.refresh();
    isDownloading.refresh();
    isFetchingData.refresh();

    // =============

    _downloadClientsMap[groupName]?.reAssign(oldFilename, newFilename);
    youtubeDownloadTasksMap[groupName]?.reAssign(oldFilename, newFilename);
    youtubeDownloadTasksInQueueMap[groupName]?.reAssignNullable(oldFilename, newFilename);
    downloadedFilesMap[groupName]?.reAssignNullable(oldFilename, newFilename);

    youtubeDownloadTasksMap.refresh();
    youtubeDownloadTasksInQueueMap.refresh();
    downloadedFilesMap.refresh();

    final directory = Directory("${AppDirs.YOUTUBE_DOWNLOADS}$groupName");
    final existingFile = File("${directory.path}/${config.filename}");
    if (existingFile.existsSync()) {
      try {
        existingFile.renameSync("${directory.path}/$newFilename");
      } catch (_) {}
    }
    if (renameCacheFiles) {
      final aFile = File(_getTempAudioPath(groupName: groupName, fullFilename: oldFilename));
      final vFile = File(_getTempVideoPath(groupName: groupName, fullFilename: oldFilename));

      if (aFile.existsSync()) {
        final newPath = _getTempAudioPath(groupName: groupName, fullFilename: newFilename);
        aFile.renameSync(newPath);
      }
      if (vFile.existsSync()) {
        final newPath = _getTempVideoPath(groupName: groupName, fullFilename: newFilename);
        vFile.renameSync(newPath);
      }
    }

    NotificationService.inst.removeDownloadingYoutubeNotification(notificationID: oldFilename);

    YTOnGoingFinishedDownloads.inst.refreshList();

    await _writeTaskGroupToStorage(groupName: groupName);
  }

  VideoStream getPreferredStreamQuality(List<VideoStream> streams, {List<String> qualities = const [], bool preferIncludeWebm = false}) {
    final preferredQualities = (qualities.isNotEmpty ? qualities : settings.youtubeVideoQualities.value).map((element) => element.settingLabeltoVideoLabel());
    VideoStream? plsLoop(bool webm) {
      for (int i = 0; i < streams.length; i++) {
        final q = streams[i];
        final webmCondition = webm ? true : !q.isWebm;
        if (webmCondition && preferredQualities.contains(q.qualityLabel.splitFirst('p'))) {
          return q;
        }
      }
      return null;
    }

    if (preferIncludeWebm) {
      return plsLoop(true) ?? streams.last;
    } else {
      return plsLoop(false) ?? plsLoop(true) ?? streams.last;
    }
  }

  void _loopMapAndPostNotification({
    required Map<String, RxMap<String, DownloadProgress>> bigMap,
    required int Function(String key, int progress) speedInBytes,
    required DateTime startTime,
    required bool isAudio,
    required String? Function(String videoId) titleCallback,
  }) {
    final downloadingText = isAudio ? "Audio" : "Video";
    for (final bigEntry in bigMap.entries.toList()) {
      final map = bigEntry.value.value;
      final videoId = bigEntry.key;
      for (final entry in map.entries.toList()) {
        final p = entry.value.progress;
        final tp = entry.value.totalProgress;
        final title = titleCallback(videoId) ?? videoId;
        final speedB = speedInBytes(videoId, entry.value.progress);
        currentSpeedsInByte.value[videoId] ??= <String, int>{}.obs;
        currentSpeedsInByte.value[videoId]![entry.key] = speedB;
        if (p / tp >= 1) {
          map.remove(entry.key);
        } else {
          NotificationService.inst.downloadYoutubeNotification(
            notificationID: entry.key,
            title: "Downloading $downloadingText: $title",
            progress: p,
            total: tp,
            subtitle: (progressText) => "$progressText (${speedB.fileSizeFormatted}/s)",
            imagePath: ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(id: videoId)?.path,
            displayTime: startTime,
          );
        }
      }
    }
  }

  void _doneDownloadingNotification({
    required String videoId,
    required String videoTitle,
    required String nameIdentifier,
    required File? downloadedFile,
    required String filename,
    required bool canceledByUser,
  }) {
    if (downloadedFile == null) {
      if (!canceledByUser) {
        NotificationService.inst.doneDownloadingYoutubeNotification(
          notificationID: nameIdentifier,
          videoTitle: videoTitle,
          subtitle: 'Download Failed',
          imagePath: ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(id: videoId)?.path,
          failed: true,
        );
      }
    } else {
      final size = downloadedFile.fileSizeFormatted();
      NotificationService.inst.doneDownloadingYoutubeNotification(
        notificationID: nameIdentifier,
        videoTitle: downloadedFile.path.getFilenameWOExt,
        subtitle: size == null ? '' : 'Downloaded: $size',
        imagePath: ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(id: videoId)?.path,
        failed: false,
      );
    }
    _tryCancelDownloadNotificationTimer();

    // this removes progress when pausing.
    // downloadsVideoProgressMap[videoId]?.remove(filename);
    // downloadsAudioProgressMap[videoId]?.remove(filename);
  }

  final _speedMapVideo = <String, int>{};
  final _speedMapAudio = <String, int>{};

  Timer? _downloadNotificationTimer;
  void _tryCancelDownloadNotificationTimer() {
    if (downloadsVideoProgressMap.isEmpty && downloadsAudioProgressMap.isEmpty) {
      _downloadNotificationTimer?.cancel();
      _downloadNotificationTimer = null;
    }
  }

  void _startNotificationTimer() {
    if (_downloadNotificationTimer == null) {
      final startTime = DateTime.now();
      String? title;
      String? titleCallback(String videoId) {
        title ??= YoutubeInfoController.utils.getVideoName(videoId);
        return title;
      }

      _downloadNotificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _loopMapAndPostNotification(
          startTime: startTime,
          isAudio: false,
          bigMap: downloadsVideoProgressMap.value,
          speedInBytes: (key, newProgress) {
            final previousProgress = _speedMapVideo[key] ?? 0;
            final speed = newProgress - previousProgress;
            _speedMapVideo[key] = newProgress;
            return speed;
          },
          titleCallback: titleCallback,
        );
        _loopMapAndPostNotification(
          startTime: startTime,
          isAudio: true,
          bigMap: downloadsAudioProgressMap.value,
          speedInBytes: (key, newProgress) {
            final previousProgress = _speedMapAudio[key] ?? 0;
            final speed = newProgress - previousProgress;
            _speedMapAudio[key] = newProgress;
            return speed;
          },
          titleCallback: titleCallback,
        );
      });
    }
  }

  String cleanupFilename(String filename) => filename.replaceAll(RegExp(r'[*#\$|/\\!^:"]', caseSensitive: false), '_');

  Future<void> loadDownloadTasksInfoFile() async {
    await for (final f in Directory(AppDirs.YT_DOWNLOAD_TASKS).list()) {
      if (f is File) {
        final groupName = f.path.getFilename.splitFirst('.');
        final res = await f.readAsJson() as Map<String, dynamic>?;
        if (res != null) {
          final fileModified = f.statSync().modified;
          youtubeDownloadTasksMap[groupName] ??= {};
          downloadedFilesMap[groupName] ??= {};
          if (fileModified != DateTime(1970)) {
            latestEditedGroupDownloadTask[groupName] ??= fileModified.millisecondsSinceEpoch;
          }
          for (final v in res.entries) {
            final ytitem = YoutubeItemDownloadConfig.fromJson(v.value as Map<String, dynamic>);
            final saveDirPath = "${AppDirs.YOUTUBE_DOWNLOADS}$groupName";
            final file = File("$saveDirPath/${ytitem.filename}");
            final fileExists = file.existsSync();
            youtubeDownloadTasksMap[groupName]![v.key] = ytitem;
            downloadedFilesMap[groupName]![v.key] = fileExists ? file : null;
            if (!fileExists) {
              final aFile = File("$saveDirPath/.tempa_${ytitem.filename}");
              final vFile = File("$saveDirPath/.tempv_${ytitem.filename}");
              if (aFile.existsSync()) {
                downloadsAudioProgressMap.value[ytitem.id] ??= <String, DownloadProgress>{}.obs;
                downloadsAudioProgressMap.value[ytitem.id]![ytitem.filename] = DownloadProgress(
                  progress: aFile.fileSizeSync() ?? 0,
                  totalProgress: 0,
                );
              }
              if (vFile.existsSync()) {
                downloadsVideoProgressMap.value[ytitem.id] ??= <String, DownloadProgress>{}.obs;
                downloadsVideoProgressMap.value[ytitem.id]![ytitem.filename] = DownloadProgress(
                  progress: vFile.fileSizeSync() ?? 0,
                  totalProgress: 0,
                );
              }
            }
          }
        }
      }
    }
    youtubeDownloadTasksMap.refresh();
    downloadedFilesMap.refresh();
  }

  File? doesIDHasFileDownloaded(String id) {
    for (final e in youtubeDownloadTasksMap.entries) {
      for (final config in e.value.values) {
        final groupName = e.key;
        if (config.id == id) {
          final file = downloadedFilesMap[groupName]?[config.filename];
          if (file != null) {
            return file;
          }
        }
      }
    }
    return null;
  }

  void _matchIDsForItemConfig({
    required List<String> videosIds,
    required void Function(String groupName, YoutubeItemDownloadConfig config) onMatch,
  }) {
    for (final e in youtubeDownloadTasksMap.entries) {
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
    required String groupName,
    List<String> videosIds = const [],
  }) {
    _matchIDsForItemConfig(
      videosIds: videosIds,
      onMatch: (groupName, config) {
        downloadYoutubeVideos(
          useCachedVersionsIfAvailable: true,
          autoExtractTitleAndArtist: settings.ytAutoExtractVideoTagsFromInfo.value,
          keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
          downloadFilesWriteUploadDate: settings.downloadFilesWriteUploadDate.value,
          itemsConfig: [config],
          groupName: groupName,
        );
      },
    );
  }

  Future<void> resumeDownloadTasks({
    required String groupName,
    List<YoutubeItemDownloadConfig> itemsConfig = const [],
    bool skipExistingFiles = true,
  }) async {
    final finalItems = itemsConfig.isNotEmpty ? itemsConfig : youtubeDownloadTasksMap[groupName]?.values.toList() ?? [];
    if (skipExistingFiles) {
      finalItems.removeWhere((element) => YoutubeController.inst.downloadedFilesMap[groupName]?[element.filename] != null);
    }
    if (finalItems.isNotEmpty) {
      await downloadYoutubeVideos(
        useCachedVersionsIfAvailable: true,
        autoExtractTitleAndArtist: settings.ytAutoExtractVideoTagsFromInfo.value,
        keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
        downloadFilesWriteUploadDate: settings.downloadFilesWriteUploadDate.value,
        itemsConfig: finalItems,
        groupName: groupName,
      );
    }
  }

  void pauseDownloadTask({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    required String groupName,
    List<String> videosIds = const [],
    bool allInGroupName = false,
  }) {
    youtubeDownloadTasksInQueueMap[groupName] ??= {};
    void onMatch(String groupName, YoutubeItemDownloadConfig config) {
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
      final groupConfigs = youtubeDownloadTasksMap[groupName];
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
    final err = Exception('Download was canceled by the user');
    _completersVAI[c]?.completeErrorIfWasnt(err);
  }

  Future<void> cancelDownloadTask({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    required String groupName,
    bool allInGroupName = false,
    bool keepInList = false,
  }) async {
    await _updateDownloadTask(
      itemsConfig: itemsConfig,
      groupName: groupName,
      remove: true,
      keepInListIfRemoved: keepInList,
      allInGroupName: allInGroupName,
    );
  }

  Future<void> _updateDownloadTask({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    required String groupName,
    bool remove = false,
    bool keepInListIfRemoved = false,
    bool allInGroupName = false,
  }) async {
    youtubeDownloadTasksMap[groupName] ??= {};
    youtubeDownloadTasksInQueueMap[groupName] ??= {};
    if (remove) {
      final directory = Directory("${AppDirs.YOUTUBE_DOWNLOADS}$groupName");
      final itemsToCancel = allInGroupName ? youtubeDownloadTasksMap[groupName]!.values.toList() : itemsConfig;
      for (final c in itemsToCancel) {
        _downloadManager.stopDownload(file: _downloadClientsMap[groupName]?[c.filename]);
        _downloadClientsMap[groupName]?.remove(c.filename);
        _breakRetrievingInfoRequest(c);
        if (!keepInListIfRemoved) {
          youtubeDownloadTasksMap[groupName]?.remove(c.filename);
          youtubeDownloadTasksInQueueMap[groupName]?.remove(c.filename);
          YTOnGoingFinishedDownloads.inst.youtubeDownloadTasksTempList.remove((groupName, c));
        }
        try {
          await File("$directory/${c.filename}").delete();
        } catch (_) {}
        downloadedFilesMap[groupName]?[c.filename] = null;
      }

      // -- remove groups if emptied.
      if (youtubeDownloadTasksMap[groupName]?.isEmpty == true) {
        youtubeDownloadTasksMap.remove(groupName);
      }
    } else {
      itemsConfig.loop((c) {
        youtubeDownloadTasksMap[groupName]![c.filename] = c;
        youtubeDownloadTasksInQueueMap[groupName]![c.filename] = true;
      });
    }

    youtubeDownloadTasksMap.refresh();
    downloadedFilesMap.refresh();

    latestEditedGroupDownloadTask[groupName] = DateTime.now().millisecondsSinceEpoch;

    await _writeTaskGroupToStorage(groupName: groupName);
  }

  Future<void> _writeTaskGroupToStorage({required String groupName}) async {
    final mapToWrite = youtubeDownloadTasksMap[groupName];
    final file = File("${AppDirs.YT_DOWNLOAD_TASKS}$groupName.json");
    if (mapToWrite?.isNotEmpty == true) {
      await file.writeAsJson(mapToWrite);
    } else {
      await file.tryDeleting();
    }
  }

  final _completersVAI = <YoutubeItemDownloadConfig, Completer<VideoStreamsResult>>{};

  Future<void> downloadYoutubeVideos({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    String groupName = '',
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
  }) async {
    _updateDownloadTask(groupName: groupName, itemsConfig: itemsConfig);
    YoutubeParallelDownloadsHandler.inst.setMaxParalellDownloads(parallelDownloads);

    Future<void> downloady(YoutubeItemDownloadConfig config) async {
      final videoID = config.id;

      final completer = _completersVAI[config] = Completer<VideoStreamsResult>();
      final streamResultSync = YoutubeInfoController.video.fetchVideoStreamsSync(videoID);
      if (streamResultSync != null && streamResultSync.hasExpired() == false) {
        completer.completeIfWasnt(streamResultSync);
      } else {
        YoutubeInfoController.video.fetchVideoStreams(videoID).then((value) => completer.completeIfWasnt(value));
      }

      isFetchingData.value[videoID] ??= <String, bool>{}.obs;
      isFetchingData.value[videoID]![config.filename] = true;

      try {
        final streams = await completer.future;

        // -- video
        if (config.fetchMissingVideo == true) {
          final videos = streams.videoStreams;
          if (config.prefferedVideoQualityID != null) {
            config.videoStream = videos.firstWhereEff((e) => e.itag.toString() == config.prefferedVideoQualityID);
          }
          if (config.videoStream == null || config.videoStream?.buildUrl()?.isNotEmpty != true) {
            final webm = config.filename.endsWith('.webm') || config.filename.endsWith('.WEBM');
            config.videoStream = getPreferredStreamQuality(videos, qualities: preferredQualities, preferIncludeWebm: webm);
          }
        }

        if (config.fetchMissingAudio == true) {
          // -- audio
          final audios = streams.audioStreams;
          if (config.prefferedAudioQualityID != null) {
            config.audioStream = audios.firstWhereEff((e) => e.itag.toString() == config.prefferedAudioQualityID);
          }
          if (config.audioStream == null || config.audioStream?.buildUrl()?.isNotEmpty != true) {
            config.audioStream = audios.firstNonWebm() ?? audios.firstOrNull;
          }
        }

        // -- meta info
        if (config.ffmpegTags.isEmpty) {
          final info = streams.info;
          final meta = YTUtils.getMetadataInitialMap(videoID, info, autoExtract: autoExtractTitleAndArtist);

          config.ffmpegTags.addAll(meta);
          config.fileDate = info?.publishDate.date ?? info?.uploadDate.date;
        }
      } catch (e) {
        // -- force break
        isFetchingData[videoID]?[config.filename] = false;
        return;
      }

      isFetchingData[videoID]?[config.filename] = false;
      _updateDownloadTask(groupName: groupName, itemsConfig: [config]); // to refresh with new data

      final downloadedFile = await _downloadYoutubeVideoRaw(
        groupName: groupName,
        id: videoID,
        config: config,
        useCachedVersionsIfAvailable: useCachedVersionsIfAvailable,
        saveDirectory: saveDirectory,
        filename: config.filename,
        fileExtension: config.videoStream?.codecInfo.container ?? config.audioStream?.codecInfo.container ?? '',
        videoStream: config.videoStream,
        audioStream: config.audioStream,
        merge: true,
        deleteOldFile: deleteOldFile,
        onOldFileDeleted: onOldFileDeleted,
        keepCachedVersionsIfDownloaded: keepCachedVersionsIfDownloaded,
        videoDownloadingStream: (downloadedBytes) {},
        audioDownloadingStream: (downloadedBytes) {},
        onInitialVideoFileSize: (initialFileSize) {},
        onInitialAudioFileSize: (initialFileSize) {},
        ffmpegTags: config.ffmpegTags,
        onAudioFileReady: (audioFile) async {
          final thumbnailFile = await ThumbnailManager.inst.getYoutubeThumbnailAndCache(
            id: videoID,
            isImportantInCache: true,
          );
          await YTUtils.writeAudioMetadata(
            videoId: videoID,
            audioFile: audioFile,
            thumbnailFile: thumbnailFile,
            tagsMap: config.ffmpegTags,
          );
        },
        onVideoFileReady: (videoFile) async {
          await NamidaFFMPEG.inst.editMetadata(
            path: videoFile.path,
            tagsMap: config.ffmpegTags,
          );
        },
      );

      if (downloadFilesWriteUploadDate) {
        final d = config.fileDate;
        if (d != null && d != DateTime(0)) {
          try {
            await downloadedFile?.setLastAccessed(d);
            await downloadedFile?.setLastModified(d);
          } catch (_) {}
        }
      }

      // -- adding to library, only if audio downloaded
      if (addAudioToLocalLibrary && config.audioStream != null && config.videoStream == null) {
        downloadedFile?.path.removeTrackThenExtract();
      }

      downloadedFilesMap[groupName]?[config.filename] = downloadedFile;
      downloadedFilesMap.refresh();
      YTOnGoingFinishedDownloads.inst.refreshList();
      await onFileDownloaded?.call(downloadedFile);
    }

    bool checkIfCanSkip(YoutubeItemDownloadConfig config) {
      final isCanceled = youtubeDownloadTasksMap[groupName]?[config.filename] == null;
      final isPaused = youtubeDownloadTasksInQueueMap[groupName]?[config.filename] == false;
      if (isCanceled || isPaused) {
        printy('Download Skipped for "${config.filename}" bcz: canceled? $isCanceled, paused? $isPaused');
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
    required String groupName,
    required String fullFilename,
    Directory? saveDir,
  }) {
    return _getTempDownloadPath(
      groupName: groupName,
      fullFilename: fullFilename,
      prefix: '.tempa_',
      saveDir: saveDir,
    );
  }

  String _getTempVideoPath({
    required String groupName,
    required String fullFilename,
    Directory? saveDir,
  }) {
    return _getTempDownloadPath(
      groupName: groupName,
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
    final saveDirPath = saveDir?.path ?? "${AppDirs.YOUTUBE_DOWNLOADS}$groupName";
    return "$saveDirPath/$prefix$fullFilename";
  }

  Future<File?> _downloadYoutubeVideoRaw({
    required String id,
    required String groupName,
    required YoutubeItemDownloadConfig config,
    required bool useCachedVersionsIfAvailable,
    required Directory? saveDirectory,
    required String filename,
    required String fileExtension,
    required VideoStream? videoStream,
    required AudioStream? audioStream,
    required Map<String, String?> ffmpegTags,
    required bool merge,
    required bool keepCachedVersionsIfDownloaded,
    required bool deleteOldFile,
    required void Function(int downloadedBytesLength) videoDownloadingStream,
    required void Function(int downloadedBytesLength) audioDownloadingStream,
    required void Function(int initialFileSize) onInitialVideoFileSize,
    required void Function(int initialFileSize) onInitialAudioFileSize,
    required Future<void> Function(File videoFile) onVideoFileReady,
    required Future<void> Function(File audioFile) onAudioFileReady,
    required Future<void> Function(File? deletedFile)? onOldFileDeleted,
  }) async {
    if (id == '') return null;

    if (filename.splitLast('.') != fileExtension) filename = "$filename.$fileExtension";

    final filenameClean = cleanupFilename(filename);
    if (filenameClean != filename) {
      renameConfigFilename(
        videoID: id,
        groupName: groupName,
        config: config,
        newFilename: filenameClean,
        renameCacheFiles: false, // no worries we still gonna do the job.
      );
    }

    isDownloading.value[id] ??= <String, bool>{}.obs;
    isDownloading.value[id]![filenameClean] = true;

    _startNotificationTimer();

    saveDirectory ??= Directory("${AppDirs.YOUTUBE_DOWNLOADS}$groupName");
    await saveDirectory.create(recursive: true);

    if (deleteOldFile) {
      final file = File("${saveDirectory.path}/$filenameClean");
      try {
        if (await file.exists()) {
          await file.delete();
          onOldFileDeleted?.call(file);
        }
      } catch (_) {}
    }

    File? df;
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

    try {
      // --------- Downloading Choosen Video.
      if (videoStream != null) {
        final filecache = videoStream.getCachedFile(id);
        if (useCachedVersionsIfAvailable && filecache != null && await fileSizeQualified(file: filecache, targetSize: videoStream.sizeInBytes)) {
          videoFile = filecache;
          isVideoFileCached = true;
        } else {
          int bytesLength = 0;

          downloadsVideoProgressMap.value[id] ??= <String, DownloadProgress>{}.obs;
          final downloadedFile = await _checkFileAndDownload(
            groupName: groupName,
            url: videoStream.buildUrl() ?? '',
            targetSize: videoStream.sizeInBytes,
            filename: filenameClean,
            destinationFilePath: _getTempVideoPath(
              groupName: groupName,
              fullFilename: filenameClean,
              saveDir: saveDirectory,
            ),
            onInitialFileSize: (initialFileSize) {
              onInitialVideoFileSize(initialFileSize);
              bytesLength = initialFileSize;
            },
            downloadingStream: (downloadedBytesLength) {
              videoDownloadingStream(downloadedBytesLength);
              bytesLength += downloadedBytesLength;
              downloadsVideoProgressMap[id]![filename] = DownloadProgress(
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
            await videoFile.copy(videoStream.cachePath(id));
          }
        } else {
          skipAudio = true;
          videoFile = null;
        }
      }
      // -----------------------------------

      // --------- Downloading Choosen Audio.
      if (skipAudio == false && audioStream != null) {
        final filecache = audioStream.getCachedFile(id);
        if (useCachedVersionsIfAvailable && filecache != null && await fileSizeQualified(file: filecache, targetSize: audioStream.sizeInBytes)) {
          audioFile = filecache;
          isAudioFileCached = true;
        } else {
          int bytesLength = 0;

          downloadsAudioProgressMap.value[id] ??= <String, DownloadProgress>{}.obs;
          final downloadedFile = await _checkFileAndDownload(
            groupName: groupName,
            url: audioStream.buildUrl() ?? '',
            targetSize: audioStream.sizeInBytes,
            filename: filenameClean,
            destinationFilePath: _getTempAudioPath(
              groupName: groupName,
              fullFilename: filenameClean,
              saveDir: saveDirectory,
            ),
            onInitialFileSize: (initialFileSize) {
              onInitialAudioFileSize(initialFileSize);
              bytesLength = initialFileSize;
            },
            downloadingStream: (downloadedBytesLength) {
              audioDownloadingStream(downloadedBytesLength);
              bytesLength += downloadedBytesLength;
              downloadsAudioProgressMap[id]![filename] = DownloadProgress(
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
            await audioFile.copy(audioStream.cachePath(id));
          }
        } else {
          audioFile = null;
        }
      }
      // -----------------------------------

      // ----- merging if both video & audio were downloaded
      final output = "${saveDirectory.path}/$filenameClean";
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
            await file.rename(path);
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
    } catch (e) {
      printy('Error Downloading YT Video: $e', isError: true);
    }

    isDownloading[id]![filenameClean] = false;

    final wasPaused = youtubeDownloadTasksInQueueMap[groupName]?[filenameClean] == false;
    _doneDownloadingNotification(
      videoId: id,
      videoTitle: filename,
      nameIdentifier: filenameClean,
      filename: filenameClean,
      downloadedFile: df,
      canceledByUser: wasPaused,
    );
    return df;
  }

  /// the file returned may not be complete if the client was closed.
  Future<File> _checkFileAndDownload({
    required String url,
    required int targetSize,
    required String groupName,
    required String filename,
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
    if (initialFileSizeOnDisk < targetSize) {
      downloadStartRange = initialFileSizeOnDisk;
      _downloadClientsMap[groupName] ??= {};

      _downloadManager.stopDownload(file: _downloadClientsMap[groupName]?[filename]);
      _downloadClientsMap[groupName]![filename] = file;
      await _downloadManager.download(
        url: url,
        file: file,
        downloadStartRange: downloadStartRange,
        downloadingStream: downloadingStream,
      );
    }
    _downloadManager.stopDownload(file: file);
    _downloadClientsMap[groupName]?.remove(filename);
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
        final dir = isTemp ? AppDirs.VIDEOS_CACHE_TEMP : null;
        return erabaretaStream.cachePath(id, directory: dir);
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
        downloaded = await _downloadManager.download(
          url: erabaretaStream.buildUrl(),
          file: file,
          downloadStartRange: downloadStartRange,
          downloadingStream: downloadingStream,
          moveTo: newFilePath,
          moveToRequiredBytes: erabaretaStreamSizeInBytes,
        );
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
          durationMS: erabaretaStream.duration.inMilliseconds,
          bitrate: erabaretaStream.bitrate,
        );
      }
    } catch (e) {
      printy('Error Downloading YT Video: $e', isError: true);
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
  final _downloadCompleters = <String, Completer<bool>?>{}; // file path
  final _progressPorts = <String, ReceivePort?>{}; // file path

  /// if [file] is temp, u can provide [moveTo] to move/rename the temp file to it.
  Future<bool> download({
    required String? url,
    required File file,
    String? moveTo,
    int? moveToRequiredBytes,
    required int downloadStartRange,
    required void Function(int downloadedBytesLength) downloadingStream,
  }) async {
    if (url == null || url.isEmpty) return false;

    final filePath = file.path;
    _downloadCompleters[filePath]?.completeIfWasnt(false);
    _downloadCompleters[filePath] = Completer<bool>();

    _progressPorts[filePath]?.close();
    _progressPorts[filePath] = ReceivePort();
    final progressPort = _progressPorts[filePath]!;
    progressPort.listen((message) {
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
    await initialize();
    await sendPort(p);
    final res = await _downloadCompleters[filePath]?.future ?? false;
    _onFileFinish(filePath, null);
    return res;
  }

  Future<void> stopDownload({required File? file}) async {
    if (file == null) return;
    final filePath = file.path;
    _onFileFinish(filePath, false);
    final p = {
      'files': [file],
      'stop': true
    };
    await sendPort(p);
  }

  Future<void> stopDownloads({required List<File> files}) async {
    if (files.isEmpty) return;
    files.loop((e) => _onFileFinish(e.path, false));
    final p = {'files': files, 'stop': true};
    await sendPort(p);
  }

  static Future<void> _prepareDownloadResources(SendPort sendPort) async {
    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    final requesters = <String, HttpClientWrapper?>{}; // filePath

    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        for (final requester in requesters.values) {
          requester?.close();
        }
        requesters.clear();
        recievePort.close();
        streamSub?.cancel();
        return;
      } else {
        p as Map;
        final stop = p['stop'] as bool?;
        if (stop == true) {
          final files = p['files'] as List<File>?;
          if (files != null) {
            for (final file in files) {
              final path = file.path;
              requesters[path]?.close();
              requesters[path] = null;
            }
          }
        } else {
          final filePath = p['filePath'] as String;
          final url = p['url'] as String;
          final downloadStartRange = p['downloadStartRange'] as int;
          final moveTo = p['moveTo'] as String?;
          final moveToRequiredBytes = p['moveToRequiredBytes'] as int?;
          final progressPort = p['progressPort'] as SendPort;

          requesters[filePath] = HttpClientWrapper();
          final file = File(filePath);
          file.createSync(recursive: true);
          final fileStream = file.openWrite(mode: FileMode.append);

          final requester = requesters[filePath];
          if (requester == null) return; // always non null tho
          try {
            final headers = {'range': 'bytes=$downloadStartRange-'};
            final response = await requester.getUrlWithHeaders(Uri.parse(url), headers);
            final downloadStream = response.asBroadcastStream();

            await for (final data in downloadStream) {
              fileStream.add(data);
              progressPort.send(data.length);
            }
            bool? movedSuccessfully;
            if (moveTo != null && moveToRequiredBytes != null) {
              try {
                final fileStats = file.statSync();
                const allowance = 1024; // 1KB allowance
                if (fileStats.size >= moveToRequiredBytes - allowance) {
                  final movedFile = file.moveSync(
                    moveTo,
                    goodBytesIfCopied: (fileLength) => fileLength >= moveToRequiredBytes - allowance,
                  );
                  if (movedFile == null) movedSuccessfully = false;
                }
              } catch (_) {}
            }
            return sendPort.send(MapEntry(filePath, movedSuccessfully ?? true));
          } catch (_) {
            // client force closed
            return sendPort.send(MapEntry(filePath, false));
          } finally {
            try {
              final req = requesters.remove(filePath);
              await req?.close();
            } catch (_) {}
            try {
              await fileStream.flush();
              await fileStream.close(); // closing file.
            } catch (_) {}
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

  void _onFileFinish(String path, bool? value) {
    if (value != null) _downloadCompleters[path]?.completeIfWasnt(value);
    _downloadCompleters[path] = null;
    _progressPorts[path]?.close();
    _progressPorts[path] = null;
  }
}
