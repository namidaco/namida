// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:intl/intl.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:rhttp/rhttp.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/stream_base.dart';
import 'package:youtipie/class/streams/stream_segments.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/class/videos/video_playability.dart';
import 'package:youtipie/class/videos/video_result.dart';
import 'package:youtipie/class/youtipie_description/youtipie_description.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/core/url_utils.dart';
import 'package:youtipie/youtipie.dart' hide ExecuteDelayedMinUtils, logger;

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/audio_cache_detail.dart';
import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/audio_cache_controller.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/notification_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
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
import 'package:namida/youtube/controller/sponsorblock_controller.dart';
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
    return YoutubeInfoController.utils
        .getVideoName(videoId.videoId)
        .then(
          (value) => _titlesLookupTemp[videoId] = value,
        );
  }

  FutureOr<File?> imageCallback(DownloadTaskVideoId videoId) {
    final valInMap = _imagesLookupTemp[videoId];
    if (valInMap != null) return valInMap;
    return ThumbnailManager.inst
        .getYoutubeThumbnailFromCache(id: videoId.videoId, type: ThumbnailType.video)
        .then(
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

  /// Mirrors [youtubeDownloadTasksMap] but keyed by video id, to allow O(1) lookups by id.
  ///
  /// a single video can have more than one task, ex. downloaded into 2 groups, or twice in the
  /// same group with different qualities/filenames. so each id keeps all of its tasks, practically always one.
  ///
  /// {videoId: [(groupName, YoutubeItemDownloadConfig)]}
  final _downloadTasksIdsMap = <DownloadTaskVideoId, List<(DownloadTaskGroupName, YoutubeItemDownloadConfig)>>{};

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

  Future<void> renameConfigFilename({
    required YoutubeItemDownloadConfig config,
    required String newFilename,
    required DownloadTaskGroupName groupName,
  }) async {
    final oldFilename = config.filename.filename;

    // ignore: invalid_use_of_protected_member
    config.rename(newFilename);
    await _saveDownloadTaskConfig(groupName, config);

    final directoryPath = _getGroupDirectoryPath(groupName);
    try {
      await File(FileParts.joinPath(directoryPath, oldFilename)).rename(FileParts.joinPath(directoryPath, newFilename));
    } catch (_) {}
  }

  /// skipped if the task was canceled/replaced meanwhile, to not bring it back.
  Future<void> _saveDownloadTaskConfig(DownloadTaskGroupName groupName, YoutubeItemDownloadConfig config) async {
    final downloadTasksGroupDB = await _downloadTasksMainDBManager.getDB(groupName.groupName);
    if (!identical(youtubeDownloadTasksMap.value[groupName]?[config.filename], config)) return;
    await downloadTasksGroupDB.put(config.filename.key, config.toJson());
  }

  static String _getGroupDirectoryPath(DownloadTaskGroupName groupName) => FileParts.joinPath(AppDirs.YOUTUBE_DOWNLOADS, groupName.groupName);

  static String _getTempDirectoryPath(DownloadTaskGroupName groupName, YoutubeItemDownloadConfig config) =>
      config.cacheOnly ? AppDirs.VIDEOS_CACHE_TEMP : _getGroupDirectoryPath(groupName);

  static String? getCacheTaskFilePath(YoutubeItemDownloadConfig config) =>
      _getCacheTaskFilePath(config, audiosCacheDir: AppDirs.AUDIOS_CACHE, videosCacheDir: AppDirs.VIDEOS_CACHE);

  static String? _getCacheTaskFilePath(YoutubeItemDownloadConfig config, {required String audiosCacheDir, required String videosCacheDir}) {
    final videoId = config.id.videoId;
    final audioStream = config.audioStream;
    if (audioStream != null) return FileParts.joinPath(audiosCacheDir, audioStream.cacheKey(videoId));
    final videoStream = config.videoStream;
    if (videoStream != null) return FileParts.joinPath(videosCacheDir, videoStream.cacheKey(videoId));
    return null;
  }

  /// webm only accepts opus/vorbis audio, while mp4 accepts everything youtube serves.
  static String? getOutputContainer(VideoStream? videoStream, AudioStream? audioStream) {
    final videoContainer = videoStream?.codecInfo.container;
    final audioContainer = audioStream?.codecInfo.container;
    if (videoContainer == null) return audioContainer;
    if (audioContainer == null || audioContainer == videoContainer) return videoContainer;
    return 'mp4';
  }

  static String _removeMediaContainerExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0) return filename;
    return switch (filename.substring(dotIndex + 1).toLowerCase()) {
      'mp4' || 'webm' || 'm4a' || '3gp' || 'mp3' => filename.substring(0, dotIndex),
      _ => filename,
    };
  }

  // by claude
  static AudioStream? matchAudioStreamOrSimilar(List<AudioStream>? streams, AudioStream? target, {String? prefferedItag}) {
    if (streams == null || streams.isEmpty) return null;

    final targetItag = prefferedItag == null ? target?.itag : int.tryParse(prefferedItag) ?? target?.itag;
    final targetTrack = target?.audioTrack;
    final targetTrackId = targetTrack?.id;
    final targetLangCode = targetTrack?.langCode;

    if (targetTrackId == null && targetLangCode == null) {
      // -- single track video, itag is enough
      return targetItag == null ? null : streams.firstWhereEff((e) => e.itag == targetItag);
    }

    final targetContainer = target?.codecInfo.container;
    final targetBitrate = target?.bitrate ?? 0;

    AudioStream? sameTrackClosestBitrate;
    int? sameTrackClosestBitrateDiff;
    AudioStream? sameTrackAny;
    AudioStream? sameLangAny;

    for (final e in streams) {
      final track = e.audioTrack;
      if (targetTrackId != null && track?.id == targetTrackId) {
        if (targetItag != null && e.itag == targetItag) return e; // -- exact match
        sameTrackAny ??= e;
        if (e.codecInfo.container == targetContainer) {
          final diff = (e.bitrate - targetBitrate).abs();
          if (sameTrackClosestBitrateDiff == null || diff < sameTrackClosestBitrateDiff) {
            sameTrackClosestBitrateDiff = diff;
            sameTrackClosestBitrate = e;
          }
        }
      } else if (targetLangCode != null && track?.langCode == targetLangCode) {
        sameLangAny ??= e;
      }
    }

    return sameTrackClosestBitrate ?? sameTrackAny ?? sameLangAny;
  }

  // by claude
  static VideoStream? matchVideoStreamOrSimilar(List<VideoStream>? streams, VideoStream? target, {String? prefferedItag}) {
    if (streams == null || streams.isEmpty) return null;

    final targetItag = prefferedItag == null ? target?.itag : int.tryParse(prefferedItag) ?? target?.itag;
    if (targetItag != null) {
      final exact = streams.firstWhereEff((e) => e.itag == targetItag);
      if (exact != null) return exact;
    }
    if (target == null) return null;

    final targetHeight = target.height;
    final targetFps = target.fps;
    final targetContainer = target.codecInfo.container;
    final targetCodec = target.codecInfo.codecCleaned();

    VideoStream? sameQualitySameCodec;
    VideoStream? sameQualitySameContainer;
    VideoStream? sameQualityAny;
    VideoStream? closestQuality;
    int? closestQualityDiff;

    for (final e in streams) {
      if (e.height == targetHeight) {
        if (e.fps == targetFps) {
          if (e.codecInfo.codecCleaned() == targetCodec) return e; // -- same quality & codec
          sameQualitySameCodec ??= e;
        }
        if (e.codecInfo.container == targetContainer) sameQualitySameContainer ??= e;
        sameQualityAny ??= e;
      } else {
        // -- lower qualities are preferred over higher ones
        final diff = e.height < targetHeight ? targetHeight - e.height : (e.height - targetHeight) * 2;
        if (closestQualityDiff == null || diff < closestQualityDiff) {
          closestQualityDiff = diff;
          closestQuality = e;
        }
      }
    }

    return sameQualitySameCodec ?? sameQualitySameContainer ?? sameQualityAny ?? closestQuality;
  }

  static bool isSameVideoStream(VideoStream? a, VideoStream? b) {
    if (a == null || b == null) return false;
    if (identical(a, b) || a.itag == b.itag) return true;
    return a.height == b.height && a.fps == b.fps && a.codecInfo.codecCleaned() == b.codecInfo.codecCleaned();
  }

  static void removeDuplicateCachedQualities(List<NamidaVideo> cachedVideos, Iterable<VideoStream>? streams, String? videoId) {
    if (cachedVideos.isEmpty || streams == null) return;
    final id = videoId != null && videoId.isNotEmpty ? videoId : null;

    bool isSameVideo(VideoStream ytq, NamidaVideo cq) {
      if (id != null && ytq.cachePath(id) == cq.path) return true;
      if (ytq.sizeInBytes > 0 && ytq.sizeInBytes == cq.sizeInBytes) return true;
      return cq.height > 0 && ytq.height == cq.height && ytq.bitrate == cq.bitrate;
    }

    cachedVideos.removeWhere((cq) => streams.any((ytq) => isSameVideo(ytq, cq)));
  }

  static AudioStream? getPreferredAudioStream(List<AudioStream>? audiostreams) {
    if (audiostreams == null) return null;
    final preferOpusFormat = settings.youtube.preferOpusFormat;

    AudioStream? firstWhereEffIterable(Iterable<AudioStream> streams, bool Function(AudioStream s) test) {
      for (final s in streams) {
        if (test(s)) return s;
      }
      return null;
    }

    Iterable<AudioStream> filtered;
    if (preferOpusFormat) {
      filtered = audiostreams.where((e) => e.isWebm);
    } else {
      filtered = audiostreams.where((e) => !e.isWebm);
    }
    return firstWhereEffIterable(filtered, (e) => e.audioTrack?.isDefault == true) ?? //
        firstWhereEffIterable(filtered, (e) => e.audioTrack?.langCode == 'en') ??
        filtered.firstOrNull ??
        audiostreams.firstOrNull;
  }

  static VideoStream? getPreferredStreamQuality(List<VideoStream> streams, {List<String> qualities = const [], bool preferIncludeWebm = false}) {
    if (streams.isEmpty) return null;
    final allowExperimentalCodecs = settings.youtube.allowExperimentalCodecs;

    final preferredQualities = (qualities.isNotEmpty ? qualities : settings.youtubeVideoQualities.value);
    VideoStream? plsLoop(bool webm, bool experimentalCodecs) {
      for (final q in streams) {
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

  void _postProgressNotification({
    required DownloadTaskVideoId videoId,
    required DownloadTaskFilename filename,
    required DownloadProgress progressInfo,
    required String? title,
    required File? image,
    required bool isAudio,
    required int? speedInBytes,
  }) {
    final isRunning = speedInBytes != null;
    NotificationManager.instance.downloadYoutubeNotification(
      filenameWrapper: filename,
      title: "${isRunning ? 'Downloading' : 'Paused'} ${isAudio ? 'Audio' : 'Video'}: ${title ?? videoId.videoId}",
      progress: progressInfo.progress,
      total: progressInfo.totalProgress,
      subtitle: isRunning ? (progressText) => "$progressText (${speedInBytes.fileSizeFormatted}/s)" : (progressText) => progressText,
      imagePath: image?.path,
      displayTime: _downloadNotificationStartTime ?? DateTime.now(),
      isRunning: isRunning,
    );
  }

  Future<void> _postDownloadingNotifications({required bool isAudio}) async {
    final progressMaps = isAudio ? downloadsAudioProgressMap.value : downloadsVideoProgressMap.value;
    final speedMap = isAudio ? _notificationData._speedMapAudio : _notificationData._speedMapVideo;

    final downloading = <(DownloadTaskVideoId, DownloadTaskFilename)>[];
    for (final entry in isDownloading.value.entries) {
      final progressMap = progressMaps[entry.key]?.value;
      if (progressMap == null) continue;
      for (final filename in entry.value.value.keys) {
        if (progressMap.containsKey(filename)) downloading.add((entry.key, filename));
      }
    }

    for (final (videoId, filename) in downloading) {
      final title = await _notificationData.titleCallback(videoId);
      final image = await _notificationData.imageCallback(videoId);

      // -- re-checking since it could have finished while awaiting
      if (isDownloading.value[videoId]?.value[filename] != true) continue;
      final progressInfo = progressMaps[videoId]?.value[filename];
      if (progressInfo == null) continue;

      final p = progressInfo.progress;
      final percentage = p / progressInfo.totalProgress;
      if (percentage >= 1 || percentage.isNaN || percentage.isInfinite) continue;

      final previousProgress = speedMap[filename];
      speedMap[filename] = p;
      final speedB = previousProgress == null ? 0 : (p - previousProgress).withMinimum(0);

      final speedsMap = currentSpeedsInByte.value[videoId];
      if (speedsMap == null) {
        currentSpeedsInByte.value[videoId] = <DownloadTaskFilename, int>{filename: speedB}.obs;
        currentSpeedsInByte.refresh();
      } else {
        speedsMap[filename] = speedB;
      }

      _postProgressNotification(
        videoId: videoId,
        filename: filename,
        progressInfo: progressInfo,
        title: title,
        image: image,
        isAudio: isAudio,
        speedInBytes: speedB,
      );
    }
  }

  void _doneDownloadingNotification({
    required DownloadTaskVideoId videoId,
    required DownloadTaskFilename filename,
    required File? downloadedFile,
    required bool isPaused,
    required bool isStopped,
  }) async {
    if (downloadedFile != null) {
      final size = downloadedFile.fileSizeFormatted();
      final image = await _notificationData.imageCallback(videoId);
      NotificationManager.instance.doneDownloadingYoutubeNotification(
        filenameWrapper: filename,
        videoTitle: filename.filename.getFilenameWOExt,
        subtitle: size == null ? '' : 'Downloaded: $size',
        imagePath: image?.path,
        failed: false,
      );
      // -- remove progress only if succeeded.
      _clearDownloadProgress(videoId, filename);
    } else if (isPaused) {
      final audioProgress = downloadsAudioProgressMap.value[videoId]?.value[filename];
      final progressInfo = audioProgress ?? downloadsVideoProgressMap.value[videoId]?.value[filename];
      if (progressInfo == null) {
        NotificationManager.instance.removeDownloadingYoutubeNotification(filenameWrapper: filename);
        return;
      }
      final title = await _notificationData.titleCallback(videoId);
      final image = await _notificationData.imageCallback(videoId);
      _postProgressNotification(
        videoId: videoId,
        filename: filename,
        progressInfo: progressInfo,
        title: title,
        image: image,
        isAudio: audioProgress != null,
        speedInBytes: null,
      );
    } else if (isStopped) {
      _clearDownloadProgress(videoId, filename);
    } else {
      final image = await _notificationData.imageCallback(videoId);
      NotificationManager.instance.doneDownloadingYoutubeNotification(
        filenameWrapper: filename,
        videoTitle: filename.filename,
        subtitle: 'Download Failed',
        imagePath: image?.path,
        failed: true,
      );
    }
  }

  void _clearDownloadProgress(DownloadTaskVideoId videoId, DownloadTaskFilename filename) {
    downloadsVideoProgressMap.value[videoId]?.remove(filename);
    downloadsAudioProgressMap.value[videoId]?.remove(filename);
  }

  Timer? _downloadNotificationTimer;
  DateTime? _downloadNotificationStartTime;
  int _activeRawDownloadsCount = 0;

  void _startNotificationTimer() {
    if (_downloadNotificationTimer != null) return;
    NotificationManager.instance.ensurePermissionGranted();
    _downloadNotificationStartTime = DateTime.now();
    _scheduleNotificationTick();
  }

  /// rescheduled after each tick instead of periodic, so a slow tick never overlaps the next one.
  void _scheduleNotificationTick() {
    _downloadNotificationTimer = Timer(const Duration(seconds: 1), _onNotificationTick);
  }

  Future<void> _onNotificationTick() async {
    try {
      await _postDownloadingNotifications(isAudio: false);
      await _postDownloadingNotifications(isAudio: true);
    } finally {
      if (_activeRawDownloadsCount > 0) {
        _scheduleNotificationTick();
      } else {
        _downloadNotificationTimer = null;
        _downloadNotificationStartTime = null;
        _notificationData.clearAll();
      }
    }
  }

  void _onRawDownloadStarted(DownloadTaskVideoId id, DownloadTaskFilename filename) {
    final map = isDownloading.value[id];
    if (map == null) {
      isDownloading.value[id] = <DownloadTaskFilename, bool>{filename: true}.obs;
      isDownloading.refresh();
    } else {
      map[filename] = true;
    }
    _activeRawDownloadsCount++;
    _startNotificationTimer();
  }

  void _onRawDownloadEnded(DownloadTaskVideoId id, DownloadTaskFilename filename) {
    _activeRawDownloadsCount--;
    final map = isDownloading.value[id];
    if (map == null) return;
    map.remove(filename);
    if (map.value.isEmpty) isDownloading.value.remove(id);
  }

  RxMap<DownloadTaskFilename, DownloadProgress> _getOrCreateProgressMap(RxMap<DownloadTaskVideoId, RxMap<DownloadTaskFilename, DownloadProgress>> map, DownloadTaskVideoId id) {
    var progressMap = map.value[id];
    if (progressMap == null) {
      progressMap = map.value[id] = <DownloadTaskFilename, DownloadProgress>{}.obs;
      map.refresh();
    }
    return progressMap;
  }

  // -- things here are not refreshed. should be called in startup only.
  Future<void> loadDownloadTasksInfoFileAsync() async {
    isLoadingDownloadTasks.value = true;
    final params = _DownloadTasksLoadParams(
      tasksDatabasesPath: AppDirs.YT_DOWNLOAD_TASKS,
      downloadLocation: AppDirs.YOUTUBE_DOWNLOADS,
      audiosCacheDir: AppDirs.AUDIOS_CACHE,
      videosCacheDir: AppDirs.VIDEOS_CACHE,
      cacheTempDir: AppDirs.VIDEOS_CACHE_TEMP,
    );
    final res = await _IsolateFunctions.loadDownloadTasksInfoFileSync.thready(params);
    // -- assign loaded data and update it with any modified data if any.
    youtubeDownloadTasksMap.value = res.youtubeDownloadTasksMap.._addAllEntries(youtubeDownloadTasksMap.value);
    downloadedFilesMap.value = res.downloadedFilesMap.._addAllEntries(downloadedFilesMap.value);
    downloadsVideoProgressMap.value = res.downloadsVideoProgressMap.._addAllEntries(downloadsVideoProgressMap.value);
    downloadsAudioProgressMap.value = res.downloadsAudioProgressMap.._addAllEntries(downloadsAudioProgressMap.value);
    latestEditedGroupDownloadTask = res.latestEditedGroupDownloadTask..addAll(latestEditedGroupDownloadTask);
    _rebuildTasksIdsIndex();
    isLoadingDownloadTasks.value = false;
  }

  void _rebuildTasksIdsIndex() {
    _downloadTasksIdsMap.clear();
    for (final entry in youtubeDownloadTasksMap.value.entries) {
      final groupName = entry.key;
      for (final config in entry.value.values) {
        (_downloadTasksIdsMap[config.id] ??= []).add((groupName, config));
      }
    }
  }

  void _indexAddTask(DownloadTaskGroupName groupName, YoutubeItemDownloadConfig config) {
    final tasks = _downloadTasksIdsMap[config.id] ??= [];
    final filenameKey = config.filename.key;
    for (int i = 0; i < tasks.length; i++) {
      if (tasks[i].$2.filename.key == filenameKey) {
        tasks[i] = (groupName, config);
        return;
      }
    }
    tasks.add((groupName, config));
  }

  void _indexRemoveTask(YoutubeItemDownloadConfig config) {
    final tasks = _downloadTasksIdsMap[config.id];
    if (tasks == null) return;
    final filenameKey = config.filename.key;
    for (int i = 0; i < tasks.length; i++) {
      if (tasks[i].$2.filename.key == filenameKey) {
        tasks.removeAt(i);
        break;
      }
    }
    if (tasks.isEmpty) _downloadTasksIdsMap.remove(config.id);
  }

  File? doesIDHasFileDownloaded(DownloadTaskVideoId id) {
    final tasks = _downloadTasksIdsMap[id];
    if (tasks == null) return null;
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (task.$2.cacheOnly) continue;
      final file = downloadedFilesMap.value[task.$1]?[task.$2.filename];
      if (file != null) return file;
    }
    return null;
  }

  File? doesIDHasFileDownloadedInGroup(DownloadTaskVideoId id, DownloadTaskGroupName groupName) {
    final tasks = _downloadTasksIdsMap[id];
    if (tasks == null) return null;
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      if (task.$1 == groupName && !task.$2.cacheOnly) {
        final file = downloadedFilesMap.value[groupName]?[task.$2.filename];
        if (file != null) return file;
      }
    }
    return null;
  }

  void _matchIDsForItemConfig({
    required List<DownloadTaskVideoId> videosIds,
    required void Function(DownloadTaskGroupName groupName, YoutubeItemDownloadConfig config) onMatch,
  }) {
    for (final id in videosIds) {
      final tasks = _downloadTasksIdsMap[id];
      if (tasks == null) continue;
      // -- copied, [onMatch] can modify the list.
      for (final task in tasks.toList()) {
        onMatch(task.$1, task.$2);
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
        itemsConfig: finalItems,
        groupName: groupName,
      );
    }
  }

  final _pendingAutoResumeTasks = <DownloadTaskGroupName, Map<DownloadTaskFilename, YoutubeItemDownloadConfig>>{};
  bool _autoResumeListenerRegistered = false;

  /// schedules a task to be resumed once the connection is back.
  /// only done when there is no connection at all, since shorter hiccups
  /// are already retried internally by [_YTDownloadManager].
  void _registerAutoResumeOnConnectionRestored(DownloadTaskGroupName groupName, YoutubeItemDownloadConfig config) {
    if (ConnectivityController.inst.hasConnection) return;

    (_pendingAutoResumeTasks[groupName] ??= {})[config.filename] = config;

    if (_autoResumeListenerRegistered) return;
    _autoResumeListenerRegistered = true;
    ConnectivityController.inst.registerOnConnectionRestored(_onConnectionRestoredResumeTasks);
  }

  void _onConnectionRestoredResumeTasks() {
    _autoResumeListenerRegistered = false; // the callback is fired only once

    if (_pendingAutoResumeTasks.isEmpty) return;
    final tasks = Map<DownloadTaskGroupName, Map<DownloadTaskFilename, YoutubeItemDownloadConfig>>.from(_pendingAutoResumeTasks);
    _pendingAutoResumeTasks.clear();

    for (final entry in tasks.entries) {
      final groupName = entry.key;
      final configs = <YoutubeItemDownloadConfig>[];
      for (final config in entry.value.values) {
        if (!_isTaskStopped(groupName, config)) configs.add(config);
      }
      if (configs.isNotEmpty) {
        resumeDownloadTasks(
          groupName: groupName,
          itemsConfig: configs,
        );
      }
    }
  }

  void _cancelAutoResume(DownloadTaskGroupName groupName, DownloadTaskFilename filename) {
    final group = _pendingAutoResumeTasks[groupName];
    if (group == null) return;
    group.remove(filename);
    if (group.isEmpty) _pendingAutoResumeTasks.remove(groupName);
  }

  /// paused, canceled or replaced by a newer config (restarted).
  bool _isTaskStopped(DownloadTaskGroupName groupName, YoutubeItemDownloadConfig config) {
    return !identical(youtubeDownloadTasksMap.value[groupName]?[config.filename], config) || youtubeDownloadTasksInQueueMap.value[groupName]?[config.filename] == false;
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
      _cancelAutoResume(groupName, config.filename);
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
      for (var c in itemsConfig) {
        onMatch(groupName, c);
      }
    }
    youtubeDownloadTasksInQueueMap.refresh();
  }

  void _breakRetrievingInfoRequest(YoutubeItemDownloadConfig c) {
    _completersVAI.remove(c)?.completeErrorIfWasnt(const _UserCanceledException());
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

  /// partial files live in the group folder, so they are only reused when [newGroupName] is the same.
  Future<void> restartDownloadTask({
    required DownloadTaskGroupName groupName,
    required YoutubeItemDownloadConfig oldConfig,
    required DownloadTaskGroupName newGroupName,
    required YoutubeItemDownloadConfig newConfig,
    Future<void> Function(File? downloadedFile)? onOldFileDeleted,
    Future<void> Function(File? deletedFile)? onFileDownloaded,
  }) async {
    await cancelDownloadTask(itemsConfig: [oldConfig], groupName: groupName, keepInList: newGroupName == groupName, delete: true);
    await downloadYoutubeVideos(
      useCachedVersionsIfAvailable: true,
      itemsConfig: [newConfig],
      groupName: newGroupName,
      onOldFileDeleted: onOldFileDeleted,
      onFileDownloaded: onFileDownloaded,
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
    final downloadTasksGroupDB = await _downloadTasksMainDBManager.getDB(
      groupName.groupName,
      config: const DBConfig(createIfNotExist: true),
    );

    youtubeDownloadTasksMap.value[groupName] ??= {};
    youtubeDownloadTasksInQueueMap[groupName] ??= {};
    if (remove) {
      final itemsToCancel = allInGroupName
          ? youtubeDownloadTasksMap.value[groupName]!.values.toFixedList()
          : List<YoutubeItemDownloadConfig>.from(itemsConfig); // copy bcz we can remove if from original list
      for (final c in itemsToCancel) {
        _downloadManager.stopDownload(file: _downloadClientsMap[groupName]?[c.filename]);
        _downloadClientsMap[groupName]?.remove(c.filename);
        _breakRetrievingInfoRequest(c);
        NotificationManager.instance.removeDownloadingYoutubeNotification(filenameWrapper: c.filename);
        _clearDownloadProgress(c.id, c.filename); // -- a canceled task would otherwise keep showing its last progress
        downloadTasksGroupDB.delete(c.filename.key);
        if (!keepInListIfRemoved) {
          youtubeDownloadTasksMap.value[groupName]?.remove(c.filename);
          youtubeDownloadTasksInQueueMap[groupName]?.remove(c.filename);
          _indexRemoveTask(c);
        }
        final isDone = downloadedFilesMap.value[groupName]?[c.filename] != null;
        if (delete) {
          if (c.cacheOnly) {
            // -- the cache may have existed before the task, only a finished task owns it
            if (isDone) _deleteCacheTaskFiles(c);
          } else {
            final outputFilePath = FileParts.joinPath(_getGroupDirectoryPath(groupName), c.filename.filename);
            File(outputFilePath).tryDeleting();
            if (c.splitByChapters == true) Directory(_getChaptersDirectoryPath(outputFilePath)).delete(recursive: true).ignoreError();
          }
        }
        if (isDone) {
          downloadedFilesMap[groupName]?[c.filename] = null;
        } else if (!keepInListIfRemoved) {
          _deleteTempFiles(_getTempDirectoryPath(groupName, c), c);
        }
      }
      if (keepInListIfRemoved) {
        YTOnGoingFinishedDownloads.inst.onTasksStatusChanged(groupName, itemsToCancel);
      } else {
        YTOnGoingFinishedDownloads.inst.onTasksRemoved(groupName, itemsToCancel);
      }
      // downloadTasksGroupDB.claimFreeSpaceAndCheckpoint();

      // -- remove groups if emptied.
      if (youtubeDownloadTasksMap.value[groupName]?.isEmpty == true) {
        youtubeDownloadTasksMap.value.remove(groupName);
        downloadTasksGroupDB.deleteEverything();
        // await downloadTasksGroupDB.fileInfo.file.delete(); // db.deleteEverything() leaves leftovers.
      }
    } else {
      await downloadTasksGroupDB.putAllIterable(
        itemsConfig,
        (c) {
          final groupTasks = youtubeDownloadTasksMap.value[groupName]!;
          final previousConfig = groupTasks[c.filename];
          if (previousConfig != null && !identical(previousConfig, c)) {
            // -- replaced (restarted with edits), partial files are kept if the same streams are still used
            final directoryPath = _getTempDirectoryPath(groupName, c);
            _deleteTempFileIfStreamChanged(directoryPath, _kTempVideoPrefix, c.filename, previousConfig.videoStream, c.videoStream);
            _deleteTempFileIfStreamChanged(directoryPath, _kTempAudioPrefix, c.filename, previousConfig.audioStream, c.audioStream);
          }
          groupTasks[c.filename] = c;
          youtubeDownloadTasksInQueueMap[groupName]![c.filename] = true; // hehe
          _indexAddTask(groupName, c);
          final key = c.filename.key;
          return MapEntry(key, c.toJson());
        },
      );
      YTOnGoingFinishedDownloads.inst.onTasksStatusChanged(groupName, itemsConfig);
    }

    youtubeDownloadTasksMap.refresh();
    downloadedFilesMap.refresh();

    latestEditedGroupDownloadTask[groupName] = DateTime.now().millisecondsSinceEpoch;
  }

  final _completersVAI = <YoutubeItemDownloadConfig, Completer<VideoStreamsResult?>>{};

  Future<void> downloadYoutubeVideos({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    DownloadTaskGroupName groupName = const DownloadTaskGroupName.defaulty(),
    required bool useCachedVersionsIfAvailable,
    List<String> preferredQualities = const [],
    Future<void> Function(File? downloadedFile)? onOldFileDeleted,
    Future<void> Function(File? deletedFile)? onFileDownloaded,
    PlaylistBasicInfo? playlistInfo,
  }) async {
    await _updateDownloadTask(groupName: groupName, itemsConfig: itemsConfig);

    Future<void> downloady(YoutubeItemDownloadConfig config) async {
      _cancelAutoResume(groupName, config.filename); // it's being started, no longer pending

      final addAudioToLocalLibrary = config.addAudioToLocalLibrary ?? settings.downloadAddAudioToLocalLibrary.value;
      final autoExtractTitleAndArtist = config.autoExtractTitleAndArtist ?? settings.youtube.autoExtractVideoTagsFromInfo.value;
      final keepCachedVersionsIfDownloaded = config.keepCachedVersionsIfDownloaded ?? settings.downloadFilesKeepCachedVersions.value;
      final downloadFilesWriteUploadDate = config.downloadFilesWriteUploadDate ?? settings.downloadFilesWriteUploadDate.value;
      final deleteOldFile = config.deleteOldFile ?? settings.downloadOverrideOldFiles.value;
      final removeSponsorSegments = config.removeSponsorSegments ?? settings.youtube.sponsorBlockSettings.value.removeSegmentsFromDownloads;
      final splitByChapters = config.splitByChapters ?? settings.youtube.splitDownloadsByChapters.value;

      final videoID = config.id;

      final completer = _completersVAI[config] = Completer<VideoStreamsResult?>();
      // pls dont try to refactor this
      YoutubeInfoController.video.fetchVideoStreams(videoID.videoId, forceRequest: true).catchError((_) => null).then((value) => _completersVAI[config]?.completeIfWasnt(value));

      if (isFetchingData.value[videoID] == null) {
        isFetchingData.value[videoID] = <DownloadTaskFilename, bool>{}.obs;
        isFetchingData.refresh();
      }
      isFetchingData.value[videoID]![config.filename] = true;

      VideoStreamsResult? streams;

      try {
        if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();

        streams = await completer.future;
        _completersVAI.remove(config);
        if (streams == null) throw Exception('null streams result');

        final previousVideoStream = config.videoStream;
        final previousAudioStream = config.audioStream;

        // -- video
        if (config.fetchMissingVideo == true) {
          final videos = streams.videoStreams;

          // -- refresh the current video stream (vip to avoid outdated links after restarts/etc)
          config.videoStream = matchVideoStreamOrSimilar(videos, config.videoStream, prefferedItag: config.prefferedVideoQualityID);

          // `config.videoStream?.buildUrl()?.host.isNotEmpty != true` means if null || empty || fkedup then assign
          if (config.videoStream == null || config.videoStream?.buildUrl()?.host.isNotEmpty != true) {
            final webm = config.filename.filename.endsWith('.webm') || config.filename.filename.endsWith('.WEBM');
            config.videoStream = getPreferredStreamQuality(videos, qualities: preferredQualities, preferIncludeWebm: webm);
          }
        }

        if (config.fetchMissingAudio == true) {
          // -- audio
          final audios = streams.audioStreams;

          // -- refresh the current audio stream (vip to avoid outdated links after restarts/etc)
          config.audioStream = matchAudioStreamOrSimilar(audios, config.audioStream, prefferedItag: config.prefferedAudioQualityID);

          if (config.audioStream == null || config.audioStream?.buildUrl()?.host.isNotEmpty != true) {
            config.audioStream = getPreferredAudioStream(audios) ?? audios.firstOrNull;
          }
        }

        final directoryPath = _getTempDirectoryPath(groupName, config);
        _deleteTempFileIfStreamChanged(directoryPath, _kTempVideoPrefix, config.filename, previousVideoStream, config.videoStream);
        _deleteTempFileIfStreamChanged(directoryPath, _kTempAudioPrefix, config.filename, previousAudioStream, config.audioStream);

        if (config.fetchMissingVideo == true && config.videoStream == null && config.audioStream != null) {
          // -- otherwise an audio-only file is silently downloaded while video was requested
          snackyy(
            title: lang.warning,
            message: 'No video streams available for "${config.filename.filename}", downloading audio only',
            top: false,
          );
        }

        // -- meta info
        if (!config.cacheOnly && (config.ffmpegTags.isEmpty || config.ffmpegTags.values.any((element) => element != null && filenameBuilder.paramRegex.hasMatch(element)))) {
          final info = streams.info;
          final meta = await YTUtils.getMetadataInitialMap(
            videoID.videoId,
            config.streamInfoItem,
            config.videoStream,
            config.audioStream,
            streams,
            playlistInfo ?? config.playlistInfo,
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
        _completersVAI.remove(config);
        isFetchingData.value[videoID]?[config.filename] = false;
        if (e is _UserCanceledException) {
          // -- resumed again while the canceled request was still awaited
          if (!_isTaskStopped(groupName, config)) return downloady(config);
          return;
        }
        printy(e, isError: true);
        snackyy(title: lang.error, message: e.toString(), isError: true);
        _registerAutoResumeOnConnectionRestored(groupName, config);
        return;
      }

      isFetchingData.value[videoID]?[config.filename] = false;

      // -- paused/canceled while building metadata, nothing was there to stop it
      if (_isTaskStopped(groupName, config)) return;

      _saveDownloadTaskConfig(groupName, config); // to save refreshed streams & tags
      youtubeDownloadTasksMap.refresh();

      if (config.cacheOnly) {
        final cachedFile = await _cacheYoutubeVideoRaw(groupName: groupName, config: config, streams: streams);
        if (cachedFile == null && !_isTaskStopped(groupName, config)) _registerAutoResumeOnConnectionRestored(groupName, config);
        return _onTaskFinished(groupName, config, cachedFile, onFileDownloaded);
      }

      final pageResult = await YoutubeInfoController.video.fetchVideoPage(videoID.videoId).catchError((_) => null);
      Completer<File?>? thumbnailCompleter;
      bool isTempThumbnail = false;
      Future<File?> getEffectiveThumbnail() async {
        if (thumbnailCompleter != null) return thumbnailCompleter!.future;
        thumbnailCompleter = Completer<File?>();

        final videoId = videoID.videoId;
        File? thumbnailFile;
        try {
          // -- try getting cropped version if required
          final channelName = await YoutubeInfoController.utils.getVideoChannelName(videoId);
          const topic = '- Topic';
          if (channelName != null && channelName.endsWith(topic)) {
            final thumbFilePath = FileParts.joinPath(Directory.systemTemp.path, '${videoId}_${config.filename.key}.png');
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

        thumbnailCompleter!.complete(thumbnailFile);

        return thumbnailFile;
      }

      FTags? cachedTags;
      List<File>? chapterFiles;

      final downloadedFile = await _downloadYoutubeVideoRaw(
        groupName: groupName,
        id: videoID,
        config: config,
        useCachedVersionsIfAvailable: useCachedVersionsIfAvailable,
        streams: streams,
        pageResult: pageResult,
        videoStream: config.videoStream,
        audioStream: config.audioStream,
        deleteOldFile: deleteOldFile,
        onOldFileDeleted: onOldFileDeleted,
        keepCachedVersionsIfDownloaded: keepCachedVersionsIfDownloaded,
        onAudioFileReady: (audioFile) async {
          final path = audioFile.path;
          final thumbnailFile = await getEffectiveThumbnail();
          final newTags = cachedTags ??= config.buildTagsValues(path: path, thumbnailFile: thumbnailFile);
          await NamidaTaggerController.inst.writeTagsRaw(
            path: path,
            newTags: newTags,
          );
        },
        onVideoFileReady: (videoFile) async {
          final path = videoFile.path;
          final thumbnailFile = await getEffectiveThumbnail();
          final newTags = cachedTags ??= config.buildTagsValues(path: path, thumbnailFile: thumbnailFile);
          await NamidaTaggerController.inst.writeTagsRaw(
            path: path,
            newTags: newTags,
          );
        },
        onOutputFileReady: removeSponsorSegments || splitByChapters
            ? (outputFile) async {
                final sponsorRanges = removeSponsorSegments
                    ? await SponsorBlockController.inst.getDownloadRemovalRangesMS(videoID.videoId, categoriesNamesOverride: config.sponsorSegmentsCategories)
                    : null;
                final cutStartPaddingMS = config.videoStream != null ? _kVideoCutPaddingMS : 0;

                final chapters = splitByChapters ? pageResult?.streamSegments : null;
                if (chapters != null && chapters.length > 1) {
                  final parts = await _splitFileByChapters(
                    outputFile: outputFile,
                    chapters: chapters,
                    sponsorRangesMS: sponsorRanges,
                    config: config,
                    thumbnailFile: await getEffectiveThumbnail(),
                    cutStartPaddingMS: cutStartPaddingMS,
                  );
                  if (parts != null && parts.isNotEmpty) {
                    chapterFiles = parts;
                    return parts.first;
                  }
                }

                if (sponsorRanges == null) return null;

                final path = outputFile.path;
                final didRemove = await NamidaFFMPEG.inst.removeSegments(
                  path: path,
                  sortedCutRangesMS: sponsorRanges,
                  cutStartPaddingMS: cutStartPaddingMS,
                );
                if (!didRemove) return null;

                // -- cutting drops the cover art & can drop tags depending on the container
                final thumbnailFile = await getEffectiveThumbnail();
                final newTags = cachedTags ??= config.buildTagsValues(path: path, thumbnailFile: thumbnailFile);
                await NamidaTaggerController.inst.writeTagsRaw(
                  path: path,
                  newTags: newTags,
                );
                return null;
              }
            : null,
      );

      if (isTempThumbnail) {
        if (thumbnailCompleter != null && thumbnailCompleter!.isCompleted) {
          final thumbnailFile = await thumbnailCompleter!.future;
          thumbnailFile?.tryDeleting();
        }
      }

      final outputFiles = downloadedFile == null ? null : (chapterFiles ?? [downloadedFile]);

      if (downloadFilesWriteUploadDate && outputFiles != null) {
        final d = config.fileDate;
        if (d != null && d != DateTime(0)) {
          for (final file in outputFiles) {
            try {
              await file.setLastAccessed(d);
              await file.setLastModified(d);
            } catch (_) {}
          }
        }
      }

      if (outputFiles != null) {
        // -- adding to library, if audio or audio+video downloaded
        final addToLocalLibrary = addAudioToLocalLibrary && config.audioStream != null;
        final tracksFutures = <Future<Track?>>[];
        for (final file in outputFiles) {
          if (addToLocalLibrary) tracksFutures.add(Indexer.inst.convertPathToTracksAndAddToListsSingle(file.path));
          Indexer.inst.scanMediaStore(file.path);
        }
        final localPlaylistName = config.localPlaylistName;
        if (localPlaylistName != null && tracksFutures.isNotEmpty) {
          _addDownloadedTracksToLocalPlaylist(localPlaylistName, groupName, config.originalIndex, tracksFutures);
        }
      } else if (!_isTaskStopped(groupName, config)) {
        _registerAutoResumeOnConnectionRestored(groupName, config);
      }

      await _onTaskFinished(groupName, config, downloadedFile, onFileDownloaded);
    }

    bool shouldSkip(YoutubeItemDownloadConfig config) {
      final skip = _isTaskStopped(groupName, config);
      if (skip && kDebugMode) printy('Download Skipped for "${config.filename.filename}" bcz: paused, canceled or restarted');
      return skip;
    }

    await Future.wait(
      itemsConfig.map(
        (config) => YoutubeParallelDownloadsHandler.inst.add(
          config: config,
          shouldSkip: shouldSkip,
          download: downloady,
        ),
      ),
    );
  }

  Future<void> _onTaskFinished(
    DownloadTaskGroupName groupName,
    YoutubeItemDownloadConfig config,
    File? downloadedFile,
    Future<void> Function(File? downloadedFile)? onFileDownloaded,
  ) async {
    final dfmg = downloadedFilesMap.value[groupName] ??= {};
    dfmg[config.filename] = downloadedFile;
    downloadedFilesMap.refresh();
    final dtqmg = youtubeDownloadTasksInQueueMap.value[groupName] ??= {};
    dtqmg[config.filename] = null;
    youtubeDownloadTasksInQueueMap.refresh();
    YTOnGoingFinishedDownloads.inst.onTasksStatusChanged(groupName, [config]);
    await onFileDownloaded?.call(downloadedFile);
  }

  /// an existing cache task in the same group is resumed instead of creating a duplicate.
  Future<void> cacheYoutubeVideos({
    required DownloadTaskGroupName groupName,
    required Iterable<String> videoIds,
    required Map<String, StreamInfoItem> infoLookup,
    required bool audioOnly,
    required List<String> preferredQualities,
  }) {
    final itemsConfig = <YoutubeItemDownloadConfig>[];
    for (final videoId in videoIds) {
      final id = DownloadTaskVideoId(videoId: videoId);
      final existingTask = _downloadTasksIdsMap[id]?.firstWhereEff((e) => e.$1 == groupName && e.$2.cacheOnly);
      if (existingTask != null) {
        itemsConfig.add(existingTask.$2);
        continue;
      }
      final info = infoLookup[videoId];
      itemsConfig.add(
        YoutubeItemDownloadConfig.cache(
          id: id,
          groupName: groupName,
          title: info?.title ?? YoutubeInfoController.utils.getVideoNameSync(videoId) ?? videoId,
          streamInfoItem: info,
          audioOnly: audioOnly,
        ),
      );
    }
    return downloadYoutubeVideos(
      groupName: groupName,
      itemsConfig: itemsConfig,
      useCachedVersionsIfAvailable: true,
      preferredQualities: preferredQualities,
    );
  }

  static const _kTempVideoPrefix = '.tempv_';
  static const _kTempAudioPrefix = '.tempa_';

  /// serializes parallel downloads adding to the same playlist.
  Future<void> _localPlaylistAddChain = Future.value();

  /// keeps the source playlist order, whichever download finishes first.
  void _addDownloadedTracksToLocalPlaylist(String playlistName, DownloadTaskGroupName groupName, int? originalIndex, List<Future<Track?>> tracksFutures) {
    _localPlaylistAddChain = _localPlaylistAddChain
        .then((_) async {
          final tracksToAdd = (await Future.wait(tracksFutures)).whereType<Track>().toSet();
          final playlist = PlaylistController.inst.getPlaylist(playlistName);
          if (playlist == null) {
            if (tracksToAdd.isNotEmpty) await PlaylistController.inst.addNewPlaylist(playlistName, tracks: tracksToAdd.toList());
            return;
          }

          Map<String, int>? originalIndexByPath;
          if (originalIndex != null) {
            final groupFiles = downloadedFilesMap.value[groupName];
            final groupConfigs = youtubeDownloadTasksMap.value[groupName];
            if (groupFiles != null && groupConfigs != null) {
              originalIndexByPath = <String, int>{};
              for (final c in groupConfigs.values) {
                final index = c.originalIndex;
                final file = groupFiles[c.filename];
                if (index != null && file != null) originalIndexByPath[file.path] = index;
              }
            }
          }

          final existing = playlist.tracks;
          int? insertIndex;
          for (int i = 0; i < existing.length; i++) {
            final track = existing[i].track;
            tracksToAdd.remove(track);
            if (insertIndex == null && originalIndexByPath != null) {
              final index = originalIndexByPath[track.path];
              if (index != null && index > originalIndex!) insertIndex = i;
            }
          }
          if (tracksToAdd.isEmpty) return;

          int dateAdded = currentTimeMS;
          await PlaylistController.inst.insertTracksInPlaylist(
            playlist,
            tracksToAdd.map((e) => TrackWithDate(dateAdded: dateAdded++, track: e)).toList(),
            insertIndex ?? existing.length,
          );
        })
        .catchError((Object e, StackTrace st) {
          logger.error('YoutubeController._addDownloadedTracksToLocalPlaylist', e: e, st: st);
        });
  }

  /// keyed by the task & stream size, so a different stream never resumes into another's partial file.
  static String _getTempDownloadPath(String directoryPath, String prefix, DownloadTaskFilename filename, StreamBase stream) {
    return FileParts.joinPath(directoryPath, '$prefix${filename.key}_${stream.sizeInBytes}.${stream.codecInfo.container}');
  }

  /// temp files used to be named after the filename.
  static String _getLegacyTempDownloadPath(String directoryPath, String prefix, String filename, StreamBase stream) {
    final container = stream.codecInfo.container;
    final name = '$prefix$filename';
    return FileParts.joinPath(directoryPath, name.endsWith(container) ? name : '$name.$container');
  }

  void _deleteCacheTaskFiles(YoutubeItemDownloadConfig config) {
    final videoId = config.id.videoId;
    final videoStream = config.videoStream;
    if (videoStream != null) File(videoStream.cachePath(videoId)).tryDeleting();
    final audioStream = config.audioStream;
    if (audioStream != null) {
      final audioPath = audioStream.cachePath(videoId);
      File(audioPath).tryDeleting();
      AudioCacheController.inst.removeFromCacheMap(videoId, audioPath);
    }
  }

  void _deleteTempFiles(String directoryPath, YoutubeItemDownloadConfig config) {
    final videoStream = config.videoStream;
    if (videoStream != null) FilesDownloadManager.deleteDownloadFiles(File(_getTempDownloadPath(directoryPath, _kTempVideoPrefix, config.filename, videoStream)));
    final audioStream = config.audioStream;
    if (audioStream != null) FilesDownloadManager.deleteDownloadFiles(File(_getTempDownloadPath(directoryPath, _kTempAudioPrefix, config.filename, audioStream)));
  }

  void _deleteTempFileIfStreamChanged(String directoryPath, String prefix, DownloadTaskFilename filename, StreamBase? oldStream, StreamBase? newStream) {
    if (oldStream == null) return;
    if (newStream != null && oldStream.sizeInBytes == newStream.sizeInBytes && oldStream.codecInfo.container == newStream.codecInfo.container) return;
    FilesDownloadManager.deleteDownloadFiles(File(_getTempDownloadPath(directoryPath, prefix, filename, oldStream)));
  }

  static const _kMinimumChapterDurationMS = 1000;

  /// video cuts land on keyframes, so the packets right before one can go unplayed & the cut feels early.
  static const _kVideoCutPaddingMS = 200;

  /// the folder holding the per chapter parts of a download, derived from the output file so it can be found again on a rescan.
  static String _getChaptersDirectoryPath(String outputFilePath) {
    final dotIndex = outputFilePath.lastIndexOf('.');
    return dotIndex > 0 ? outputFilePath.substring(0, dotIndex) : '$outputFilePath chapters';
  }

  static File? _findFirstChapterFileSync(String outputFilePath) {
    File? first;
    try {
      final entities = Directory(_getChaptersDirectoryPath(outputFilePath)).listSync();
      for (final entity in entities) {
        if (entity is File && (first == null || entity.path.compareTo(first.path) < 0)) first = entity;
      }
    } catch (_) {}
    return first;
  }

  static List<(int, int, String)> _buildChapterRanges(List<StreamSegment> chapters, int totalDurationMS) {
    final ranges = <(int, int, String)>[];
    for (final chapter in chapters) {
      final startSeconds = chapter.startSeconds;
      if (startSeconds == null) continue;
      final startMS = startSeconds * 1000;
      final previousIndex = ranges.length - 1;
      if (previousIndex >= 0) {
        final previous = ranges[previousIndex];
        if (startMS - previous.$1 < _kMinimumChapterDurationMS) continue;
        ranges[previousIndex] = (previous.$1, startMS, previous.$3);
      }
      ranges.add((startMS, totalDurationMS, chapter.title));
    }
    final lastIndex = ranges.length - 1;
    if (lastIndex >= 0 && ranges[lastIndex].$2 - ranges[lastIndex].$1 < _kMinimumChapterDurationMS) {
      ranges.removeLast();
      // -- the dropped tail belongs to the chapter before it rather than to nothing
      if (lastIndex > 0) {
        final newLast = ranges[lastIndex - 1];
        ranges[lastIndex - 1] = (newLast.$1, totalDurationMS, newLast.$3);
      }
    }
    return ranges;
  }

  /// sponsor ranges translated into a chapter's own timeline, clipped to it. empty when the chapter is untouched.
  static List<(int, int)> _cutRangesWithinChapter(List<(int, int)>? sortedCutRangesMS, int chapterStartMS, int chapterEndMS) {
    if (sortedCutRangesMS == null) return const [];
    final ranges = <(int, int)>[];
    for (final cut in sortedCutRangesMS) {
      if (cut.$2 <= chapterStartMS) continue;
      if (cut.$1 >= chapterEndMS) break;
      final startMS = cut.$1.withMinimum(chapterStartMS) - chapterStartMS;
      final endMS = cut.$2.withMaximum(chapterEndMS) - chapterStartMS;
      if (endMS > startMS) ranges.add((startMS, endMS));
    }
    return ranges;
  }

  /// Splits [outputFile] into one file per youtube chapter inside [_getChaptersDirectoryPath], removing
  /// [sponsorRangesMS] from each part afterwards so the chapter bounds stay exact.
  ///
  /// Returns the produced parts & deletes [outputFile], or `null` when nothing was split.
  Future<List<File>?> _splitFileByChapters({
    required File outputFile,
    required List<StreamSegment> chapters,
    required List<(int, int)>? sponsorRangesMS,
    required YoutubeItemDownloadConfig config,
    required File? thumbnailFile,
    required int cutStartPaddingMS,
  }) async {
    final path = outputFile.path;
    final totalDuration = await NamidaFFMPEG.inst.getMediaDuration(path);
    if (totalDuration == null) return null;

    final ranges = _buildChapterRanges(chapters, totalDuration.inMilliseconds);
    if (ranges.length < 2) return null;

    String ext = '';
    try {
      ext = path.getExtension;
    } catch (_) {}

    final partsDirPath = _getChaptersDirectoryPath(path);
    final partsDir = Directory(partsDirPath);
    final albumTitle = config.ffmpegTags[FFMPEGTagField.title.tagKey] ?? '';
    final trackTotal = ranges.length.toString();
    final numberPadding = trackTotal.length;
    final parts = <File>[];
    bool didSplitAll = true;

    try {
      // -- a previous split of the same task can hold parts under now outdated chapter names
      await partsDir.delete(recursive: true).ignoreError();
      await partsDir.create(recursive: true);

      for (int i = 0; i < ranges.length; i++) {
        final range = ranges[i];
        final number = (i + 1).toString().padLeft(numberPadding, '0');
        final partName = DownloadTaskFilename.cleanupFilename('$number. ${range.$3}.$ext', parentDirPath: partsDirPath);
        final partPath = FileParts.joinPath(partsDirPath, partName);

        final didExtract = await NamidaFFMPEG.inst.extractRange(
          path: path,
          startMS: range.$1,
          endMS: range.$2,
          outputPath: partPath,
        );
        if (!didExtract) {
          didSplitAll = false;
          break;
        }

        final cutRanges = _cutRangesWithinChapter(sponsorRangesMS, range.$1, range.$2);
        if (cutRanges.isNotEmpty) {
          await NamidaFFMPEG.inst.removeSegments(
            path: partPath,
            sortedCutRangesMS: cutRanges,
            cutStartPaddingMS: cutStartPaddingMS,
          );
        }

        await NamidaTaggerController.inst.writeTagsRaw(
          path: partPath,
          newTags: config.buildTagsValues(
            path: partPath,
            thumbnailFile: thumbnailFile,
            chapterOverrides: (title: range.$3, album: albumTitle, trackNumber: '${i + 1}', trackTotal: trackTotal),
          ),
        );
        parts.add(File(partPath));
      }
    } catch (_) {
      didSplitAll = false;
    }

    if (!didSplitAll) {
      partsDir.delete(recursive: true).ignoreError();
      return null;
    }

    await outputFile.tryDeleting();
    return parts;
  }

  /// lowercased since android & windows storages are case insensitive.
  static String _getActiveOutputKey(DownloadTaskGroupName groupName, String filename) => '${groupName.groupName}/${filename.toLowerCase()}';

  /// outputs of the currently downloading tasks, to prevent parallel tasks writing to the same file.
  final _activeOutputFilenames = <String>{};

  static final filenameBuilder = _YtFilenameRebuilder();

  Future<File?> _cacheYoutubeVideoRaw({
    required DownloadTaskGroupName groupName,
    required YoutubeItemDownloadConfig config,
    required VideoStreamsResult streams,
  }) async {
    final id = config.id;
    final videoId = id.videoId;
    final filename = config.filename;
    File? cachedFile;
    _onRawDownloadStarted(id, filename);
    try {
      final videoStream = config.videoStream;
      if (videoStream != null) {
        cachedFile = await _downloadStreamToCache(groupName, config, videoStream, _kTempVideoPrefix, videoStream.cachePath(videoId), downloadsVideoProgressMap);
        final info = streams.info;
        VideoController.inst.addYTVideoToCacheMap(
          videoId,
          NamidaVideo(
            path: cachedFile.path,
            ytID: videoId,
            height: videoStream.height,
            width: videoStream.width,
            sizeInBytes: videoStream.sizeInBytes,
            frameratePrecise: videoStream.fps.toDouble(),
            creationTimeMS: (info?.publishedAt.accurateDate ?? info?.publishDate.accurateDate)?.millisecondsSinceEpoch ?? 0,
            durationMS: videoStream.duration?.inMilliseconds ?? 0,
            bitrate: videoStream.bitrate,
          ),
        );
      }
      final audioStream = config.audioStream;
      if (audioStream != null) {
        downloadsVideoProgressMap.value[id]?.remove(filename); // remove video progress so that audio progress is shown
        cachedFile = await _downloadStreamToCache(groupName, config, audioStream, _kTempAudioPrefix, audioStream.cachePath(videoId), downloadsAudioProgressMap);
        AudioCacheController.inst.removeFromCacheMap(videoId, cachedFile.path);
        AudioCacheController.inst.addToCacheMap(
          videoId,
          AudioCacheDetails(
            youtubeId: videoId,
            bitrate: audioStream.bitrate,
            langaugeCode: audioStream.audioTrack?.langCode,
            langaugeName: audioStream.audioTrack?.displayName,
            file: cachedFile,
          ),
        );
      }
    } on _UserCanceledException catch (_) {
      cachedFile = null;
    } catch (e, st) {
      cachedFile = null;
      snackyy(title: 'Error Caching', message: e.toString(), isError: true);
      logger.error('YoutubeController._cacheYoutubeVideoRaw', e: e, st: st);
    }

    _onRawDownloadEnded(id, filename);
    _doneDownloadingNotification(
      videoId: id,
      filename: filename,
      downloadedFile: cachedFile,
      isPaused: youtubeDownloadTasksInQueueMap.value[groupName]?[filename] == false,
      isStopped: _isTaskStopped(groupName, config),
    );
    return cachedFile;
  }

  Future<File> _downloadStreamToCache(
    DownloadTaskGroupName groupName,
    YoutubeItemDownloadConfig config,
    StreamBase stream,
    String tempPrefix,
    String cachePath,
    RxMap<DownloadTaskVideoId, RxMap<DownloadTaskFilename, DownloadProgress>> progressMaps,
  ) async {
    final cacheFile = File(cachePath);
    if (await cacheFile.exists()) return cacheFile;

    final filename = config.filename;
    final progressMap = _getOrCreateProgressMap(progressMaps, config.id);
    final totalSize = stream.sizeInBytes;
    int bytesLength = 0;
    final tempFile = await _checkFileAndDownload(
      groupName: groupName,
      url: stream.buildUrl(),
      targetSize: totalSize,
      config: config,
      destinationFilePath: _getTempDownloadPath(_getTempDirectoryPath(groupName, config), tempPrefix, filename, stream),
      onInitialFileSize: (initialFileSize) => bytesLength = initialFileSize,
      downloadingStream: (downloadedBytesLength) {
        bytesLength += downloadedBytesLength;
        progressMap[filename] = DownloadProgress(progress: bytesLength, totalProgress: totalSize);
      },
    );
    final size = await tempFile.fileSize();
    if (size == null || size < totalSize) {
      throw _DownloadErrorDescriptionsWrapper.createOrAdd(null, _DownloadErrorDescription.nonQualifiedFileSize(size, totalSize));
    }
    return tempFile.rename(cachePath);
  }

  Future<File?> _downloadYoutubeVideoRaw({
    required DownloadTaskVideoId id,
    required DownloadTaskGroupName groupName,
    required YoutubeItemDownloadConfig config,
    required bool useCachedVersionsIfAvailable,
    required VideoStreamsResult? streams,
    required YoutiPieVideoPageResult? pageResult,
    required VideoStream? videoStream,
    required AudioStream? audioStream,
    required bool keepCachedVersionsIfDownloaded,
    required bool deleteOldFile,
    required Future<void> Function(File videoFile) onVideoFileReady,
    required Future<void> Function(File audioFile) onAudioFileReady,
    required Future<void> Function(File? deletedFile)? onOldFileDeleted,
    required Future<File?> Function(File outputFile)? onOutputFileReady,
  }) async {
    if (id.videoId.isEmpty) return null;

    VideoStreamInfo? streamInfo = streams?.info;
    try {
      streamInfo = await YoutubeInfoController.utils.buildOrUseVideoStreamInfo(config.id.videoId, streams);
      pageResult ??= await YoutubeInfoController.video.fetchVideoPage(config.id.videoId);
      streams ??= await YoutubeInfoController.video.fetchVideoStreams(config.id.videoId);
    } catch (_) {}

    var playlistInfo = config.playlistInfo;
    final playlistId = config.playlistId;

    if (playlistInfo == null && playlistId != null && playlistId.isNotEmpty) {
      try {
        final pl = await YoutubeInfoController.playlist.fetchPlaylist(playlistId: playlistId);
        playlistInfo = pl?.info;
      } catch (_) {}
    }

    final filenameWrapper = config.filename;
    final fileExtension = getOutputContainer(videoStream, audioStream) ?? 'm4a';
    final directoryPath = _getGroupDirectoryPath(groupName);
    String finalFilenameTemp = filenameWrapper.filename;
    bool requiresRenaming = false;
    String? reservedOutputKey;
    bool didStartDownloading = false;

    File? df;
    try {
      if (finalFilenameTemp.isEmpty || finalFilenameTemp == fileExtension || finalFilenameTemp == '.$fileExtension') {
        finalFilenameTemp = settings.youtube.defaultFilenameBuilder;
        requiresRenaming = true;
      }

      final finalFilenameTempRebuilt = filenameBuilder.rebuildFilenameWithDecodedParams(
        finalFilenameTemp,
        id.videoId,
        streamInfo,
        pageResult,
        config.streamInfoItem,
        playlistInfo,
        videoStream,
        audioStream,
        config.originalIndex,
        config.totalLength,
      );
      if (finalFilenameTempRebuilt != null && finalFilenameTempRebuilt.isNotEmpty) {
        finalFilenameTemp = finalFilenameTempRebuilt;
        requiresRenaming = true;
      }

      if (!finalFilenameTemp.endsWith('.$fileExtension')) {
        finalFilenameTemp = '${_removeMediaContainerExtension(finalFilenameTemp)}.$fileExtension';
        requiresRenaming = true;
      }

      await Directory(directoryPath).create(recursive: true);

      final filenameCleanTemp = DownloadTaskFilename.cleanupFilename(finalFilenameTemp, parentDirPath: directoryPath);
      if (filenameCleanTemp != finalFilenameTemp) {
        finalFilenameTemp = filenameCleanTemp;
        requiresRenaming = true;
      }

      final unsuffixedFilename = finalFilenameTemp;
      String outputKey = _getActiveOutputKey(groupName, finalFilenameTemp);
      for (int i = 1; !_activeOutputFilenames.add(outputKey); i++) {
        finalFilenameTemp = DownloadTaskFilename.withNumberSuffix(unsuffixedFilename, i, parentDirPath: directoryPath);
        outputKey = _getActiveOutputKey(groupName, finalFilenameTemp);
        requiresRenaming = true;
      }
      reservedOutputKey = outputKey;

      if (requiresRenaming) {
        // ignore: invalid_use_of_protected_member
        config.rename(finalFilenameTemp);
        await _saveDownloadTaskConfig(groupName, config);
      }

      File? videoFile;
      File? audioFile;

      bool isVideoFileCached = false;
      bool isAudioFileCached = false;

      _DownloadErrorDescriptionsWrapper? downloadErrorDescription;

      _onRawDownloadStarted(id, filenameWrapper);
      didStartDownloading = true;

      if (streams != null && streams.playability.status != VideoPlayabiltyStatus.ok) {
        final missingStreams = config.fetchMissingVideo != false && config.fetchMissingAudio == false
            ? streams.videoStreams.isEmpty && streams.mixedStreams.isEmpty
            : streams.audioStreams.isEmpty && streams.mixedStreams.isEmpty;
        if (missingStreams) {
          final info = {
            'info': streamInfo?.toMap(),
            'page': pageResult?.toMap(),
            'streams': streams.toMap()..remove('info'),
          };
          final infoFile = FileParts.join(directoryPath, "${filenameWrapper.filename}.json");
          await infoFile.writeAsJson(info);

          useCachedVersionsIfAvailable = true;
          final audioExisting = await AudioCacheController.inst.getCachedAudioForId(config.id.videoId);

          if (audioExisting != null) {
            audioFile = audioExisting.file;
            isAudioFileCached = true;
          }

          final allCachedVideos = await VideoController.inst.getNVFromIDSorted(config.id.videoId);
          final videoExisting = await allCachedVideos.firstWhereEffAsync((e) => File(e.path).exists());
          if (videoExisting != null) {
            videoFile = File(videoExisting.path);
            isVideoFileCached = true;
          }

          VideoController.inst.videosPriorityManager.setVideoPriority(config.id.videoId, CacheVideoPriority.VIP);

          downloadErrorDescription = _DownloadErrorDescriptionsWrapper.createOrAdd(
            downloadErrorDescription,
            _DownloadErrorDescription.videoIsNotAvailable(
              playabilty: streams.playability,
              videoId: streams.videoId,
              videoTitle: streams.info?.title ?? pageResult?.videoInfo?.title ?? '?',
              infoFile: infoFile,
              cachedAudio: audioFile,
              cachedVideo: videoFile,
            ),
          );
        }
      }

      final file = FileParts.join(directoryPath, finalFilenameTemp);
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
          final fileSize = await file.fileSize();
          return fileSize != null && fileSize >= targetSize - allowanceBytes; // it can be bigger cuz metadata and artwork may be added later
        }

        // -- a requested stream that failed must not end up as a (partial) final file
        bool streamFailed = false;

        if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();

        // --------- Downloading Choosen Video.
        if (videoStream != null) {
          final filecache = await videoStream.getCachedFile(id.videoId);
          if (useCachedVersionsIfAvailable && filecache != null && await fileSizeQualified(file: filecache, targetSize: videoStream.sizeInBytes)) {
            videoFile = filecache;
            isVideoFileCached = true;
          } else {
            final progressMap = _getOrCreateProgressMap(downloadsVideoProgressMap, id);
            final totalSize = videoStream.sizeInBytes;
            int bytesLength = 0;
            videoFile = await _checkFileAndDownload(
              groupName: groupName,
              url: videoStream.buildUrl(),
              targetSize: totalSize,
              config: config,
              destinationFilePath: _getTempDownloadPath(directoryPath, _kTempVideoPrefix, filenameWrapper, videoStream),
              onInitialFileSize: (initialFileSize) => bytesLength = initialFileSize,
              downloadingStream: (downloadedBytesLength) {
                bytesLength += downloadedBytesLength;
                progressMap[filenameWrapper] = DownloadProgress(
                  progress: bytesLength,
                  totalProgress: totalSize,
                );
              },
            );
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
            downloadErrorDescription = _DownloadErrorDescriptionsWrapper.createOrAdd(
              downloadErrorDescription,
              _DownloadErrorDescription.nonQualifiedFileSize(
                await videoFile.fileSize(),
                videoStream.sizeInBytes,
              ),
            );
            streamFailed = true;
          }
        }
        // -----------------------------------

        // --------- Downloading Choosen Audio.
        if (!streamFailed && audioStream != null) {
          downloadsVideoProgressMap.value[id]?.remove(filenameWrapper); // remove video progress so that audio progress is shown

          final filecache = await audioStream.getCachedFile(id.videoId);
          if (useCachedVersionsIfAvailable && filecache != null && await fileSizeQualified(file: filecache, targetSize: audioStream.sizeInBytes)) {
            audioFile = filecache;
            isAudioFileCached = true;
          } else {
            final progressMap = _getOrCreateProgressMap(downloadsAudioProgressMap, id);
            final totalSize = audioStream.sizeInBytes;
            int bytesLength = 0;
            audioFile = await _checkFileAndDownload(
              groupName: groupName,
              url: audioStream.buildUrl(),
              targetSize: totalSize,
              config: config,
              destinationFilePath: _getTempDownloadPath(directoryPath, _kTempAudioPrefix, filenameWrapper, audioStream),
              onInitialFileSize: (initialFileSize) => bytesLength = initialFileSize,
              downloadingStream: (downloadedBytesLength) {
                bytesLength += downloadedBytesLength;
                progressMap[filenameWrapper] = DownloadProgress(
                  progress: bytesLength,
                  totalProgress: totalSize,
                );
              },
            );
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
            downloadErrorDescription = _DownloadErrorDescriptionsWrapper.createOrAdd(
              downloadErrorDescription,
              _DownloadErrorDescription.nonQualifiedFileSize(
                await audioFile.fileSize(),
                audioStream.sizeInBytes,
              ),
            );
            streamFailed = true;
          }
        }
        // -----------------------------------

        if (!streamFailed) {
          final output = FileParts.joinPath(directoryPath, filenameWrapper.filename);
          if (videoFile != null && audioFile != null) {
            final didMerge = await NamidaFFMPEG.inst.mergeAudioAndVideo(
              videoPath: videoFile.path,
              audioPath: audioFile.path,
              outputPath: output,
            );
            if (didMerge) {
              df = File(output);
              if (!isVideoFileCached) videoFile.delete().ignoreError();
              if (!isAudioFileCached) audioFile.delete().ignoreError();
            } else {
              File(output).delete().ignoreError(); // -- a failed merge can leave an empty/partial output
              downloadErrorDescription = _DownloadErrorDescriptionsWrapper.createOrAdd(
                downloadErrorDescription,
                _DownloadErrorDescription.mergeError(
                  videoPath: videoFile.path,
                  audioPath: audioFile.path,
                  outputPath: output,
                ),
              );
            }
          } else {
            // -- renaming files, or copying if cached
            final sourceFile = videoFile ?? audioFile;
            if (sourceFile != null) {
              final isCachedVersion = videoFile != null ? isVideoFileCached : isAudioFileCached;
              try {
                df = isCachedVersion ? await sourceFile.copy(output) : await sourceFile.move(output);
              } catch (_) {}
            }
            if (df == null) {
              downloadErrorDescription = _DownloadErrorDescriptionsWrapper.createOrAdd(
                downloadErrorDescription,
                _DownloadErrorDescription.fileDoesNotExistAfterRenameOrCopy(
                  vfile: videoFile,
                  vpath: output,
                  visCachedVersion: isVideoFileCached,
                  afile: audioFile,
                  apath: output,
                  aisCachedVersion: isAudioFileCached,
                ),
              );
            }
          }
        }

        if (df != null && onOutputFileReady != null) df = await onOutputFileReady(df) ?? df;

        // -- [df] can still be valid here, ex: video is unavailable but cached files were used.
        if (downloadErrorDescription != null && downloadErrorDescription.exceptions.isNotEmpty) {
          throw downloadErrorDescription;
        }
      }
    } on _UserCanceledException catch (_) {
    } catch (e, st) {
      printy('Error Downloading YT Video: $e', isError: true);
      snackyy(title: 'Error Downloading', message: e.toString(), isError: true);
      logger.error('YoutubeController.downloadYoutubeVideoRaw: Error Downloading', e: e, st: st);
    }

    if (reservedOutputKey != null) _activeOutputFilenames.remove(reservedOutputKey);
    if (didStartDownloading) _onRawDownloadEnded(id, filenameWrapper);

    _doneDownloadingNotification(
      videoId: id,
      filename: filenameWrapper,
      downloadedFile: df,
      isPaused: youtubeDownloadTasksInQueueMap.value[groupName]?[filenameWrapper] == false,
      isStopped: _isTaskStopped(groupName, config),
    );
    return df;
  }

  /// the file returned may not be complete if the client was closed.
  Future<File> _checkFileAndDownload({
    required Uri? url,
    required int targetSize,
    required DownloadTaskGroupName groupName,
    required YoutubeItemDownloadConfig config,
    required String destinationFilePath,
    required void Function(int initialFileSize) onInitialFileSize,
    required void Function(int downloadedBytesLength) downloadingStream,
  }) async {
    // -- stopped while preparing/writing tags etc, where there was no download client to stop.
    if (_isTaskStopped(groupName, config)) throw const DownloadCanceledException();

    final filename = config.filename;

    final file = File(destinationFilePath); // -- created by the download isolate if needed
    final fileStat = await file.stat();
    final initialFileSizeOnDisk = fileStat.type == FileSystemEntityType.notFound ? 0 : fileStat.size; // used as a range bytes for download request
    onInitialFileSize(initialFileSizeOnDisk);
    // only download if the download is incomplete, useful sometimes when file 'moving' fails.
    Object? downloadException;
    if (initialFileSizeOnDisk < targetSize) {
      (_downloadClientsMap[groupName] ??= {})[filename] = file;
      downloadException = await _downloadManager.download(
        url: url,
        file: file,
        totalBytes: targetSize,
        threads: settings.youtube.downloadThreadsCount.valueF,
        downloadingStream: downloadingStream,
      );
    }
    _downloadClientsMap[groupName]?.remove(filename);
    if (downloadException != null) {
      throw downloadException;
    }
    return file;
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

        _downloadManager.stopDownload(file: _latestSingleDownloadingFile); // disposing old download process
        _latestSingleDownloadingFile = file;

        if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();

        final downloadException = await _downloadManager.download(
          url: erabaretaStream.buildUrl(),
          file: file,
          totalBytes: erabaretaStreamSizeInBytes,
          threads: settings.youtube.downloadThreadsCount.valueF,
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

  void stopLatestSingleDownload() {
    _downloadManager.stopDownload(file: _latestSingleDownloadingFile);
  }

  void dispose({bool closeCurrentDownloadClient = true, bool closeAllClients = false}) {
    if (closeCurrentDownloadClient) {
      stopLatestSingleDownload();
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

  /// retries that happen inside the isolate, for short network hiccups.
  /// longer outages are handled by [YoutubeController._registerAutoResumeOnConnectionRestored].
  static const _kDownloadMaxRetries = 5;

  /// max idle duration between 2 chunks before considering the connection stalled.
  static const _kDownloadStallTimeout = Duration(seconds: 30);

  /// progress is batched, sending each chunk floods the main isolate, especially with parallel downloads.
  static const _kProgressReportIntervalMs = 100;

  /// 1s, 2s, 4s, 8s, then 10s.
  static Duration _getRetryBackoff(int attempt) {
    const maxSeconds = 10;
    return Duration(seconds: attempt >= 4 ? maxSeconds : 1 << attempt);
  }

  static bool _isRetryableDownloadException(Object e) {
    if (e is RhttpStatusCodeException) return e.statusCode >= 500 || e.statusCode == 408 || e.statusCode == 429;
    return e is TimeoutException || //
        e is SocketException ||
        e is HandshakeException ||
        e is HttpException ||
        e is RhttpTimeoutException ||
        e is RhttpConnectionException ||
        e is RhttpUnknownException;
  }

  /// if [file] is temp, u can provide [moveTo] to move/rename the temp file to it.
  Future<Object?> download({
    required Uri? url,
    required File file,
    String? moveTo,
    int? moveToRequiredBytes,
    required int downloadStartRange,
    required void Function(int downloadedBytesLength) downloadingStream,
  }) async {
    if (url == null || url.host.isEmpty) return Exception('Host Empty. url: ${url.toString()}');

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
    _onFileFinish(filePath, res);
    return res;
  }

  Future<void> stopDownload({required File? file}) async {
    if (file == null) return;
    final filePath = file.path;
    _onFileFinish(filePath, const _UserCanceledException());
    final p = {
      'files': [file],
      'stop': true,
    };
    await sendPort(p);
  }

  Future<void> stopDownloads({required List<File> files}) async {
    if (files.isEmpty) return;
    for (var e in files) {
      _onFileFinish(e.path, const _UserCanceledException());
    }
    final p = {'files': files, 'stop': true};
    await sendPort(p);
  }

  static void _prepareDownloadResources(SendPort sendPort) async {
    await Rhttp.init();
    final requester = HttpClientWrapper.createSync();

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    final cancelTokensMap = <String, CancelToken>{}; // filePath
    final stoppedFilesPaths = <String>{}; // filePath, for stops that happen while retrying

    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        for (final canceltoken in cancelTokensMap.values) {
          canceltoken.cancel();
        }
        cancelTokensMap.clear();
        stoppedFilesPaths.clear();
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
              var path = file.path;
              stoppedFilesPaths.add(path);
              cancelTokensMap.remove(path)?.cancel();
            }
          }
        } else {
          final filePath = p['filePath'] as String;
          stoppedFilesPaths.remove(filePath); // fresh request
          try {
            final url = p['url'] as Uri;
            final moveTo = p['moveTo'] as String?;
            final moveToRequiredBytes = p['moveToRequiredBytes'] as int?;
            final progressPort = p['progressPort'] as SendPort;

            final file = File(filePath);
            file.createSync(recursive: true);

            int downloadStartRange = p['downloadStartRange'] as int;
            Object? downloadException;

            int pendingProgress = 0;
            final progressStopwatch = Stopwatch()..start();
            void flushProgress() {
              if (pendingProgress == 0) return;
              progressPort.send(pendingProgress);
              pendingProgress = 0;
            }

            for (int attempt = 0; ; attempt++) {
              if (stoppedFilesPaths.remove(filePath)) {
                downloadException = const _UserCanceledException();
                break;
              }

              final cancelToken = cancelTokensMap[filePath] = CancelToken();
              IOSink? fileStream;

              Future<void> onRequestFinish({bool cancel = false}) async {
                cancelTokensMap.remove(filePath);
                if (cancel) await cancelToken.cancel().ignoreError();

                await fileStream?.flush().ignoreError();
                await fileStream?.close().ignoreError(); // closing file.
              }

              try {
                final headers = {'range': 'bytes=$downloadStartRange-'};
                final response = await requester.getStream(url.toString(), headers: headers, cancelToken: cancelToken);

                // -- server didnt honor our range request, restarting from scratch to not corrupt the file.
                final serverIgnoredRange = downloadStartRange > 0 && response.statusCode != 206;
                if (serverIgnoredRange) {
                  flushProgress();
                  progressPort.send(-downloadStartRange); // reverting reported progress
                  downloadStartRange = 0;
                }
                fileStream = file.openWrite(mode: serverIgnoredRange ? FileMode.writeOnly : FileMode.writeOnlyAppend);

                await for (final data in response.body.timeout(_kDownloadStallTimeout)) {
                  fileStream.add(data);
                  downloadStartRange += data.length;
                  pendingProgress += data.length;
                  if (progressStopwatch.elapsedMilliseconds >= _kProgressReportIntervalMs) {
                    flushProgress();
                    progressStopwatch.reset();
                  }
                }
                await onRequestFinish(); // flush and close first to avoid issues
                downloadException = null;
                break;
              } on RhttpCancelException catch (_) {
                // client force closed
                await onRequestFinish(cancel: true);
                downloadException = const _UserCanceledException();
                break;
              } catch (e) {
                await onRequestFinish(cancel: true);
                downloadException = e;
                if (attempt >= _kDownloadMaxRetries || !_isRetryableDownloadException(e)) break;
                downloadStartRange = file.fileSizeSync() ?? downloadStartRange; // resuming from whatever was actually written
              }

              await Future.delayed(_getRetryBackoff(attempt));
            }

            flushProgress();
            stoppedFilesPaths.remove(filePath);

            if (downloadException != null) return sendPort.send(MapEntry(filePath, downloadException));

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
  static Future<_DownloadTaskInitWrapper> loadDownloadTasksInfoFileSync(_DownloadTasksLoadParams params) async {
    late final downloadTasksMainDBManager = DBWrapperMainSync(params.tasksDatabasesPath);

    final youtubeDownloadTasksMap = <DownloadTaskGroupName, Map<DownloadTaskFilename, YoutubeItemDownloadConfig>>{};
    final downloadedFilesMap = <DownloadTaskGroupName, Map<DownloadTaskFilename, File?>>{};
    final downloadsVideoProgressMap = <DownloadTaskVideoId, RxMap<DownloadTaskFilename, DownloadProgress>>{};
    final downloadsAudioProgressMap = <DownloadTaskVideoId, RxMap<DownloadTaskFilename, DownloadProgress>>{};
    final latestEditedGroupDownloadTask = <DownloadTaskGroupName, int>{};

    final allFiles = Directory(params.tasksDatabasesPath).listSyncSafe();
    final oldJsonFiles = <File>[];
    final newDBFiles = <File>[];
    for (var item in allFiles) {
      if (item is File) item.path.endsWith('.json') ? oldJsonFiles.add(item) : newDBFiles.add(item);
    }

    /// also migrates legacy temp files to the new naming.
    int? getTempFileSize(String directoryPath, String prefix, DownloadTaskFilename filename, StreamBase stream) {
      final path = YoutubeController._getTempDownloadPath(directoryPath, prefix, filename, stream);
      final stat = File(path).statSync();
      if (stat.type != FileSystemEntityType.notFound) return stat.size + FilesDownloadManager.chunksSizeSync(path);

      final legacyFile = File(YoutubeController._getLegacyTempDownloadPath(directoryPath, prefix, filename.filename, stream));
      final legacyStat = legacyFile.statSync();
      if (legacyStat.type == FileSystemEntityType.notFound) return null;
      try {
        legacyFile.renameSync(path);
        return legacyStat.size;
      } catch (_) {
        return null;
      }
    }

    DownloadTaskGroupName fileToGroupName(File file) {
      final filenameWOExt = file.path.getFilenameWOExt;
      return filenameWOExt.startsWith('.') ? DownloadTaskGroupName.defaulty() : DownloadTaskGroupName(groupName: filenameWOExt);
    }

    // -- migrating old .json files to .db
    for (final file in oldJsonFiles) {
      final group = fileToGroupName(file);

      try {
        final res = file.readAsJsonSync(ensureExists: false) as Map<String, dynamic>?;
        if (res != null) {
          final downloadTasksGroupDB = await downloadTasksMainDBManager.getDB(
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
    }

    bool hadEmptyGroups = false;
    final dbsThatHadError = <DownloadTaskGroupName, bool>{};

    for (final dbFile in newDBFiles) {
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
        final downloadTasksGroupDB = await downloadTasksMainDBManager.getDB(group.groupName, config: const DBConfig(autoDisposeTimerDuration: null));
        downloadTasksGroupDB.loadEverything((itemMap) {
          final ytitem = YoutubeItemDownloadConfig.fromJson(itemMap);
          final String saveDirPath;
          File? existingFile;
          if (ytitem.cacheOnly) {
            saveDirPath = params.cacheTempDir;
            final cachePath = YoutubeController._getCacheTaskFilePath(ytitem, audiosCacheDir: params.audiosCacheDir, videosCacheDir: params.videosCacheDir);
            final cacheFile = cachePath == null ? null : File(cachePath);
            if (cacheFile != null && cacheFile.existsSync()) existingFile = cacheFile;
          } else {
            saveDirPath = FileParts.joinPath(params.downloadLocation, group.groupName);
            final file = FileParts.join(saveDirPath, ytitem.filename.filename);
            existingFile = file.existsSync() ? file : null;
            // -- a split download leaves no merged file behind, its chapters folder is what marks it as done
            if (existingFile == null && ytitem.splitByChapters == true) existingFile = YoutubeController._findFirstChapterFileSync(file.path);
          }
          final fileExists = existingFile != null;
          final itemFileName = ytitem.filename;
          youtubeDownloadTasksMap[group]![itemFileName] = ytitem;
          downloadedFilesMap[group]![itemFileName] = existingFile;
          if (!fileExists) {
            final audioStream = ytitem.audioStream;
            final audioSize = audioStream == null ? null : getTempFileSize(saveDirPath, YoutubeController._kTempAudioPrefix, itemFileName, audioStream);
            if (audioSize != null) {
              (downloadsAudioProgressMap[ytitem.id] ??= <DownloadTaskFilename, DownloadProgress>{}.obs).value[itemFileName] = DownloadProgress(
                progress: audioSize,
                totalProgress: audioStream!.sizeInBytes,
              );
            }
            final videoStream = ytitem.videoStream;
            final videoSize = videoStream == null ? null : getTempFileSize(saveDirPath, YoutubeController._kTempVideoPrefix, itemFileName, videoStream);
            if (videoSize != null) {
              (downloadsVideoProgressMap[ytitem.id] ??= <DownloadTaskFilename, DownloadProgress>{}.obs).value[itemFileName] = DownloadProgress(
                progress: videoSize,
                totalProgress: videoStream!.sizeInBytes,
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
    }

    // we loop again to give a chance for duplicated groups, if any.
    if (hadEmptyGroups) {
      for (var dbFile in newDBFiles) {
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
      }
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
  final String audiosCacheDir;
  final String videosCacheDir;
  final String cacheTempDir;

  const _DownloadTasksLoadParams({
    required this.tasksDatabasesPath,
    required this.downloadLocation,
    required this.audiosCacheDir,
    required this.videosCacheDir,
    required this.cacheTempDir,
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

class _DownloadErrorDescriptionsWrapper implements Exception {
  _DownloadErrorDescriptionsWrapper._();

  final exceptions = <_DownloadErrorDescription>[];

  void add(_DownloadErrorDescription error) {
    exceptions.add(error);
  }

  static _DownloadErrorDescriptionsWrapper createOrAdd(_DownloadErrorDescriptionsWrapper? original, _DownloadErrorDescription error) {
    original ??= _DownloadErrorDescriptionsWrapper._();
    if (error.type == _DownloadErrorType.file_does_not_exist_after_rename_or_copy || error.type == _DownloadErrorType.non_qualified_file_size) {
      if (original.exceptions.any((element) => element.type == _DownloadErrorType.video_is_not_available)) {
        return original; // dont add these errors if video not available
      }
    }
    original.add(error);
    return original;
  }

  @override
  String toString() {
    return exceptions.map((e) => e.toString()).join('\n\n');
  }
}

class _DownloadErrorDescription implements Exception {
  final _DownloadErrorType type;
  final String message;
  const _DownloadErrorDescription._(this.type, this.message);

  factory _DownloadErrorDescription.nonQualifiedFileSize(int? size, int requiredSize) {
    final msg = 'size: $size | requiredSize $requiredSize | diff ${requiredSize - (size ?? 0)}';
    return _DownloadErrorDescription._(
      _DownloadErrorType.non_qualified_file_size,
      msg,
    );
  }

  factory _DownloadErrorDescription.mergeError({required String videoPath, required String audioPath, required String outputPath}) {
    final msg = 'videoPath: $videoPath | audioPath: $audioPath | outputPath: $outputPath';
    return _DownloadErrorDescription._(
      _DownloadErrorType.merge_error,
      msg,
    );
  }

  factory _DownloadErrorDescription.videoIsNotAvailable({
    required String videoId,
    required String videoTitle,
    required VideoPlayabilty playabilty,
    required File infoFile,
    required File? cachedAudio,
    required File? cachedVideo,
  }) {
    final extraReasons = [playabilty.reason, ...?playabilty.messages].whereType<String>();
    final extraReasonsText = extraReasons.isEmpty ? '' : ' | ${extraReasons.join(' | ')}';
    String msg = 'playability: ${playabilty.status.name}$extraReasonsText\n$videoId - $videoTitle\nvideo info is saved to ${infoFile.path}';
    if (cachedAudio != null) msg = '$msg\ncached audio was found and will be used instead';
    if (cachedVideo != null) msg = '$msg\ncached video was found and will be used instead';
    return _DownloadErrorDescription._(
      _DownloadErrorType.video_is_not_available,
      msg,
    );
  }

  factory _DownloadErrorDescription.fileDoesNotExistAfterRenameOrCopy({
    required File? vfile,
    required String vpath,
    required bool visCachedVersion,
    required File? afile,
    required String apath,
    required bool aisCachedVersion,
  }) {
    final vmsg = 'vfile: $vfile | vpath $vpath | visCachedVersion $visCachedVersion';
    final amsg = 'afile: $afile | apath $apath | aisCachedVersion $aisCachedVersion';
    final msg = '$vmsg\n$amsg';
    return _DownloadErrorDescription._(
      _DownloadErrorType.file_does_not_exist_after_rename_or_copy,
      msg,
    );
  }

  @override
  String toString() => 'type: ${type.name}\nmessage: $message';
}

enum _DownloadErrorType {
  video_is_not_available,
  non_qualified_file_size,
  merge_error,
  file_does_not_exist_after_rename_or_copy,
}
