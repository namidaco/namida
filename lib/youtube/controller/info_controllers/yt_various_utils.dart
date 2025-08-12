part of '../youtube_info_controller.dart';

class _YoutubeInfoUtils {
  _YoutubeInfoUtils._();

  final tempVideoInfosFromStreams = _StreamInfoMapsHolder();

  /// Used for easily displaying title & channel inside history directly without needing to fetch or rely on cache.
  /// This comes mainly after a youtube history import
  var tempBackupVideoInfo = <String, YoutubeVideoHistory>{}; // {id: YoutubeVideoHistory()}

  final _tempInfoTitle = <String, String?>{};
  final _tempInfoDescription = <String, String?>{};
  final _tempInfoChannelTitle = <String, String?>{};
  final _tempInfoChannelID = <String, String?>{};
  final _tempInfoVideoReleaseDate = <String, DateTime?>{};
  final _tempInfoVideoDurationSeconds = <String, int?>{};

  Future<void> fillBackupInfoMap() async {
    tempBackupVideoInfo = await _parseBackupHistoryInfoIsolate.thready(AppDirs.YT_STATS);
  }

  static Map<String, YoutubeVideoHistory> _parseBackupHistoryInfoIsolate(String dirPath) {
    final map = <String, YoutubeVideoHistory>{};
    Directory(dirPath).listSyncSafe().loop((f) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync(ensureExists: false);
          if (response is List) {
            response.loop(
              (r) {
                final yvh = YoutubeVideoHistory.fromJson(r);
                map[yvh.id] = yvh;
              },
            );
          }
        } catch (_) {}
      }
    });
    map.remove('');
    return map;
  }

  Future<VideoStreamInfo> buildOrUseVideoStreamInfo(String videoId, VideoStreamsResult? streams) async {
    VideoStreamInfo? streamInfo = streams?.info;
    final streamInfoCache = await YoutubeInfoController.utils.buildVideoStreamInfoFromCache(videoId);
    if (streamInfo == null) {
      streamInfo = streamInfoCache;
    } else {
      streamInfo = VideoStreamInfo.merge(
        videoId,
        streamInfoCache,
        streamInfo,
      );
    }
    return streamInfo;
  }

  Future<VideoStreamInfo> buildVideoStreamInfoFromCache(String videoId) async {
    final info = await (
      getVideoName(videoId),
      getVideoDurationSeconds(videoId),
      getVideoChannelName(videoId),
      getVideoChannelID(videoId),
      getVideoDescription(videoId),
    ).wait;
    return VideoStreamInfo(
      id: videoId,
      title: info.$1 ?? '',
      durSeconds: info.$2,
      keywords: [],
      channelName: info.$3,
      channelId: info.$4,
      description: info.$5,
      thumbnails: [],
      viewsCount: tempVideoInfosFromStreams[videoId]?.viewsCount,
      isPrivate: null,
      isUnlisted: null,
      isLive: null,
      category: null,
      publishDate: tempVideoInfosFromStreams[videoId]?.publishedAt ?? PublishTime.unknown(),
      uploadDate: tempVideoInfosFromStreams[videoId]?.publishedAt ?? PublishTime.unknown(),
    );
  }

  // ==== sync methods ====

  StreamInfoItem? getStreamInfoSync(String videoId) {
    if (tempVideoInfosFromStreams.containsKey(videoId)) return tempVideoInfosFromStreams[videoId];
    return tempVideoInfosFromStreams[videoId] = YoutiPie.cacheBuilder.forStreamInfoItem(videoId: videoId).readSync();
  }

  VideoStreamsResult? _getVideoStreamResultSync(String videoId) {
    return YoutubeInfoController.video.fetchVideoStreamsCacheSync(videoId);
  }

  YoutiPieVideoPageResult? _getVideoPageResultSync(String videoId) {
    return YoutubeInfoController.video.fetchVideoPageCacheSync(videoId);
  }

  MissingVideoInfo? _getMissingInfoSync(String videoId) {
    return YoutubeInfoController.missingInfo.fetchMissingInfoCacheSync(videoId);
  }

  String? getVideoNameSync(String videoId, {void Function()? onMissingInfo, bool checkFromStorage = true /* am sorry every follow me */}) {
    String? title = _tempInfoTitle[videoId]?.nullifyTitle() ??
        tempVideoInfosFromStreams[videoId]?.title.nullifyTitle(onMissingInfo) ??
        tempBackupVideoInfo[videoId]?.title.nullifyTitle(onMissingInfo);
    if (title != null || checkFromStorage == false) return title;

    title = _tempInfoTitle[videoId] ??= getStreamInfoSync(videoId)?.title.nullifyTitle(onMissingInfo) ??
        _getVideoStreamResultSync(videoId)?.info?.title.nullifyTitle(onMissingInfo) ?? //
        _getVideoPageResultSync(videoId)?.videoInfo?.title.nullifyTitle(onMissingInfo);

    if (title == null) {
      title = _getMissingInfoSync(videoId)?.title?.nullifyTitle();
      if (title != null) onMissingInfo?.call();
    }

    return title;
  }

  String? getVideoChannelNameSync(String videoId, {bool checkFromStorage = true}) {
    String? name = _tempInfoChannelTitle[videoId] ?? tempVideoInfosFromStreams[videoId]?.channelName?.nullifyEmpty() ?? tempBackupVideoInfo[videoId]?.channel.nullifyEmpty();
    if (name != null || checkFromStorage == false) return name;
    return _tempInfoChannelTitle[videoId] ??= getStreamInfoSync(videoId)?.channelName?.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.channelName?.nullifyEmpty() ?? //
        _getVideoPageResultSync(videoId)?.channelInfo?.title?.nullifyEmpty() ?? //
        _getMissingInfoSync(videoId)?.channelName?.nullifyEmpty();
  }

  String? getVideoChannelIDSync(String videoId, {bool checkFromStorage = true}) {
    String? chId =
        _tempInfoChannelID[videoId] ?? tempVideoInfosFromStreams[videoId]?.channelId?.nullifyEmpty() ?? tempBackupVideoInfo[videoId]?.channelUrl.nullifyEmpty()?.splitLast('/');
    if (chId != null || checkFromStorage == false) return chId;
    return _tempInfoChannelID[videoId] ??= getStreamInfoSync(videoId)?.channelId?.nullifyEmpty() ??
        _getVideoStreamResultSync(videoId)?.info?.channelId?.nullifyEmpty() ?? //
        _getVideoPageResultSync(videoId)?.channelInfo?.id.nullifyEmpty() ?? //
        _getMissingInfoSync(videoId)?.channelId?.nullifyEmpty();
  }

  List<YoutiPieThumbnail>? getVideoChannelThumbnailsSync(String videoId, {bool checkFromStorage = true}) {
    var thumbnails = tempVideoInfosFromStreams[videoId]?.channel?.thumbnails;
    if ((thumbnails != null && thumbnails.isNotEmpty) || checkFromStorage == false) return thumbnails;
    return getStreamInfoSync(videoId)?.channel?.thumbnails ?? _getVideoPageResultSync(videoId)?.channelInfo?.thumbnails;
  }

  /// Doesn't check from storage. u must call [getVideoReleaseDate] first to ensure that this returns data.
  DateTime? getVideoReleaseDateSyncTemp(String videoId) {
    // -- we check for streams result first cuz others are approximation.
    return _tempInfoVideoReleaseDate[videoId] ??= tempVideoInfosFromStreams[videoId]?.publishedAt.accurateDate;
  }

  /// Doesn't check from storage. u must call [getVideoDurationSeconds] first to ensure that this returns data.
  int? getVideoDurationSecondsSyncTemp(String videoId) {
    return _tempInfoVideoDurationSeconds[videoId] ??= tempVideoInfosFromStreams[videoId]?.durSeconds;
  }

  // ==== async methods ====

  Future<StreamInfoItem?> getStreamInfo(String videoId) async {
    if (tempVideoInfosFromStreams.containsKey(videoId)) return tempVideoInfosFromStreams[videoId];
    return tempVideoInfosFromStreams[videoId] = await YoutiPie.cacheBuilder.forStreamInfoItem(videoId: videoId).read();
  }

  Future<VideoStreamsResult?> _getVideoStreamResult(String videoId) {
    return YoutubeInfoController.video.fetchVideoStreamsCache(videoId);
  }

  Future<YoutiPieVideoPageResult?> _getVideoPageResult(String videoId) {
    return YoutubeInfoController.video.fetchVideoPageCache(videoId);
  }

  Future<MissingVideoInfo?> _getMissingInfo(String videoId) {
    return YoutubeInfoController.missingInfo.fetchMissingInfoCache(videoId);
  }

  Future<String?> getVideoName(String videoId, {void Function()? onMissingInfo, bool checkFromStorage = true /* am sorry every follow me */}) async {
    final valInMap = _tempInfoTitle[videoId];
    if (valInMap != null && valInMap.isNotEmpty) return valInMap;
    String? title = tempVideoInfosFromStreams[videoId]?.title.nullifyTitle(onMissingInfo) ?? tempBackupVideoInfo[videoId]?.title.nullifyTitle(onMissingInfo);
    if (title != null || checkFromStorage == false) return title;

    title = _tempInfoTitle[videoId] ??= (await getStreamInfo(videoId))?.title.nullifyTitle(onMissingInfo) ??
        (await _getVideoStreamResult(videoId))?.info?.title.nullifyTitle(onMissingInfo) ?? //
        (await _getVideoPageResult(videoId))?.videoInfo?.title.nullifyTitle(onMissingInfo);

    if (title == null) {
      title = (await _getMissingInfo(videoId))?.title?.nullifyTitle();
      _tempInfoTitle[videoId] = title;
      if (title != null) onMissingInfo?.call();
    }

    return title;
  }

  Future<String?> getVideoDescription(String videoId) async {
    return _tempInfoDescription[videoId] ??= (await _getVideoPageResult(videoId))?.videoInfo?.description?.rawText?.nullifyEmpty() ??
        (await _getVideoStreamResult(videoId))?.info?.description?.nullifyEmpty() ??
        tempVideoInfosFromStreams[videoId]?.availableDescription?.nullifyEmpty() ??
        (await getStreamInfo(videoId))?.availableDescription?.nullifyEmpty() ?? //
        (await _getMissingInfo(videoId))?.description?.nullifyEmpty();
  }

  Future<String?> getVideoChannelName(String videoId, {bool checkFromStorage = true}) async {
    String? name = tempVideoInfosFromStreams[videoId]?.channelName?.nullifyEmpty() ?? tempBackupVideoInfo[videoId]?.channel.nullifyEmpty();
    if (name != null || checkFromStorage == false) return name;
    return _tempInfoChannelTitle[videoId] ??= (await getStreamInfo(videoId))?.channelName?.nullifyEmpty() ??
        (await _getVideoStreamResult(videoId))?.info?.channelName?.nullifyEmpty() ?? //
        (await _getVideoPageResult(videoId))?.channelInfo?.title?.nullifyEmpty() ?? //
        (await _getMissingInfo(videoId))?.channelName?.nullifyEmpty();
  }

  Future<String?> getVideoChannelID(String videoId) async {
    return _tempInfoChannelID[videoId] ??= tempVideoInfosFromStreams[videoId]?.channelId?.nullifyEmpty() ??
        (await getStreamInfo(videoId))?.channelId?.nullifyEmpty() ??
        (await _getVideoStreamResult(videoId))?.info?.channelId?.nullifyEmpty() ?? //
        (await _getVideoPageResult(videoId))?.channelInfo?.id.nullifyEmpty() ?? //
        (await _getMissingInfo(videoId))?.channelId?.nullifyEmpty();
  }

  Future<DateTime?> getVideoReleaseDate(String videoId) async {
    // -- we check for streams result first cuz others are approximation.
    return _tempInfoVideoReleaseDate[videoId] ??= (await _getVideoStreamResult(videoId))?.info?.publishedAt.accurateDate ??
        tempVideoInfosFromStreams[videoId]?.publishedAt.accurateDate ??
        (await getStreamInfo(videoId))?.publishedAt.accurateDate ?? //
        (await _getVideoPageResult(videoId))?.videoInfo?.publishedAt.accurateDate ?? //
        (await _getMissingInfo(videoId))?.date.accurateDate;
  }

  Future<Duration?> getVideoDuration(String videoId) async {
    final seconds = await getVideoDurationSeconds(videoId);
    return seconds == null ? null : Duration(seconds: seconds);
  }

  Future<int?> getVideoDurationSeconds(String videoId) async {
    final cached = tempVideoInfosFromStreams[videoId]?.durSeconds;
    if (cached != null) return cached;
    return _tempInfoVideoDurationSeconds[videoId] ??= (await getStreamInfo(videoId))?.durSeconds ?? //
        (await _getVideoStreamResult(videoId))?.info?.durSeconds ?? //
        (await _getMissingInfo(videoId))?.durSeconds;
  }

  FutureOr<bool?> isShortContent(String videoId) {
    final cached = tempVideoInfosFromStreams[videoId]?.isActuallyShortContent;
    if (cached != null) return cached;
    return getStreamInfo(videoId).then((value) => value?.isActuallyShortContent);
  }
}

extension _StringChecker on String {
  String? nullifyTitle([void Function()? onMissingInfo]) {
    if (isEmpty) return null;
    if (isYTTitleFaulty()) {
      onMissingInfo?.call();
      return null;
    }

    return this;
  }
}

/// just a fancier way to fetch values from both internal library map and local map
class _StreamInfoMapsHolder {
  Map<String, StreamInfoItem> get _tempVideoInfosFromStreams => YoutubeInfoController.memoryCache.streamInfoItem.temp;
  final _local = <String, StreamInfoItem?>{};

  bool containsKey(Object? key) => _local.containsKey(key) || _tempVideoInfosFromStreams.containsKey(key);

  StreamInfoItem? operator [](String key) {
    return _local[key] ?? _tempVideoInfosFromStreams[key];
  }

  void operator []=(String key, StreamInfoItem? value) {
    if (value == null && _local[key] != null) return;
    _local[key] = value; // set even if value is null, to let them know key exist but has no value
  }
}
